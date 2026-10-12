-- Keep the main ASS dialogue at sub-font-size while every other style (notes,
-- signs, ...) keeps its original size relative to the dialogue.
--
-- Works with sub-ass-override=scale + sub-scale-signs=yes: the size of the
-- dialogue style relative to the script's PlayResY is compared with
-- sub-font-size / 720, and sub-scale is set to the ratio between the two.
-- The dialogue style starts as "Default" and switches to another style once it
-- clearly outnumbers it among the (non-positioned) lines shown so far.
-- Non-ASS subtitles (SRT, ...) are left at the configured sub-scale.
local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"

local opts = {
    enabled = true,
    -- Guard against scripts whose dialogue style is not detected correctly.
    min_ratio = 0.6,
    max_ratio = 1.8,
}

options.read_options(opts, "sub-size-normalize")

-- sub-font-size is expressed in pixels at a 720px high window.
local REF_HEIGHT = 720
-- Another style must have this many more lines than the current one to win.
local SWITCH_MARGIN = 2

local base_scale = mp.get_property_number("sub-scale", 1)
local ratio = 1
local last_set = base_scale

local main_style = "default"
local counts = {}
local seen = {}
local cached_header, cached_info

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_name(name)
    return (trim(name):gsub("^%*", ""):lower())
end

local function split(value)
    local fields = {}
    for field in (value .. ","):gmatch("([^,]*),") do
        fields[#fields + 1] = trim(field)
    end
    return fields
end

-- Returns { res_y = PlayResY, styles = { [lowercase name] = font size } }.
local function parse_header(header)
    local res_x, res_y, name_idx, size_idx
    local styles = {}

    for line in header:gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*(%a+):%s*(.-)%s*$")
        key = key and key:lower()

        if key == "playresx" then
            res_x = tonumber(value)
        elseif key == "playresy" then
            res_y = tonumber(value)
        elseif key == "format" then
            -- The styles Format line is the only one with both Name and Fontsize.
            local n, s
            for idx, field in ipairs(split(value)) do
                field = field:lower()
                if field == "name" then
                    n = idx
                elseif field == "fontsize" then
                    s = idx
                end
            end
            if n and s then
                name_idx, size_idx = n, s
            end
        elseif key == "style" and name_idx then
            local fields = split(value)
            local size = tonumber(fields[size_idx])
            if fields[name_idx] and size and size > 0 then
                styles[normalize_name(fields[name_idx])] = size
            end
        end
    end

    -- Same fallbacks as libass when PlayResY is missing.
    if not res_y or res_y <= 0 then
        if res_x and res_x > 0 then
            res_y = res_x == 1280 and 1024 or res_x * 3 / 4
        else
            res_y = 288
        end
    end

    return { res_y = res_y, styles = styles }
end

local function header_info()
    local header = mp.get_property("sub-ass-extradata")
    if not header or header == "" then
        return nil
    end

    if header ~= cached_header then
        cached_header = header
        cached_info = parse_header(header)
    end

    return cached_info
end

local function is_ass()
    local codec = mp.get_property("current-tracks/sub/codec")
    return codec == "ass" or codec == "ssa"
end

local function update()
    if not opts.enabled then
        return
    end

    local new_ratio = 1

    if is_ass() then
        local info = header_info()
        local size = info and info.styles[main_style]
        local target = mp.get_property_number("sub-font-size", 0) / REF_HEIGHT

        if size and target > 0 then
            new_ratio = math.max(opts.min_ratio, math.min(opts.max_ratio, target / (size / info.res_y)))
        end
    end

    ratio = new_ratio
    last_set = base_scale * ratio
    msg.verbose(string.format("main_style=%s ratio=%.3f sub-scale=%.3f", main_style, ratio, last_set))
    mp.set_property_number("sub-scale", last_set)
end

local function reset()
    main_style = "default"
    counts = {}
    seen = {}
    update()
end

-- Count the style of every new, non-positioned line (signs are positioned).
mp.observe_property("sub-text/ass-full", "string", function(_, value)
    if not opts.enabled or not value or value == "" or not is_ass() then
        return
    end

    local info = header_info()
    if not info then
        return
    end

    for line in value:gmatch("[^\r\n]+") do
        if not seen[line] then
            seen[line] = true
            local style, text = line:match(
                "^Dialogue:%s*[^,]*,[^,]*,[^,]*,([^,]*),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(.*)$")
            if style and not text:find("\\pos%(") and not text:find("\\move%(") then
                style = normalize_name(style)
                counts[style] = (counts[style] or 0) + 1
            end
        end
    end

    local best, best_n = main_style, counts[main_style] or 0
    for style, n in pairs(counts) do
        if info.styles[style] and n > best_n + SWITCH_MARGIN then
            best, best_n = style, n
        end
    end

    if best ~= main_style then
        main_style = best
        update()
    end
end)

-- A manual sub-scale change (keybinding, console) becomes the new base, so it
-- keeps working proportionally on top of the normalization.
mp.observe_property("sub-scale", "number", function(_, value)
    if value == nil or math.abs(value - last_set) < 1e-6 then
        return
    end

    base_scale = value / ratio
    last_set = value
end)

mp.observe_property("current-tracks/sub/codec", "string", update)
mp.observe_property("sub-ass-extradata", "string", update)
mp.observe_property("sid", "native", reset)
mp.register_event("start-file", reset)
