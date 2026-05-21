local options = require "mp.options"
local msg = require "mp.msg"
local utils = require "mp.utils"

local opts = {
    enabled = true,
    battery_profile = "battery",
    charging_profile = "full-performance",
    poll_interval = 10,
    show_osd = true,
}

options.read_options(opts, "power-profile")

local power_supply_dir = "/sys/class/power_supply"
local known_supplies = {
    "AC", "AC0", "AC1", "ACAD", "ADP0", "ADP1", "Mains",
    "BAT0", "BAT1",
}

local last_mode = nil
local disabled = false
local is_windows = package.config:sub(1, 1) == "\\"
local missing_profile_warnings = {}

local function has_linux_power_supply()
    local ok, entries = pcall(utils.readdir, power_supply_dir, "dirs")
    return ok and entries ~= nil
end

local function trim(value)
    if not value then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local value = file:read("*l")
    file:close()
    return trim(value)
end

local function supply_names()
    local names = {}
    local seen = {}

    local ok, entries = pcall(utils.readdir, power_supply_dir, "dirs")
    if ok and entries then
        for _, name in ipairs(entries) do
            names[#names + 1] = name
            seen[name] = true
        end
    end

    for _, name in ipairs(known_supplies) do
        if not seen[name] then
            names[#names + 1] = name
        end
    end

    return names
end

local function detect_linux_power_mode()
    local found_supply = false
    local found_battery = false
    local battery_status = nil

    for _, name in ipairs(supply_names()) do
        local base = power_supply_dir .. "/" .. name
        local supply_type = read_file(base .. "/type")
        local online = read_file(base .. "/online")
        local status = read_file(base .. "/status")

        if supply_type or online or status then
            found_supply = true
        end

        if online == "1" then
            return "charging"
        end

        if supply_type == "Battery" or name:match("^BAT%d*$") then
            found_battery = true
            battery_status = status or battery_status
        end
    end

    if battery_status == "Discharging" then
        return "battery"
    end

    if battery_status == "Charging" or battery_status == "Full" or battery_status == "Not charging" then
        return "charging"
    end

    if found_supply and not found_battery then
        return "charging"
    end

    return nil
end

local function detect_windows_power_mode()
    local result = utils.subprocess({
        args = {
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "Add-Type -AssemblyName System.Windows.Forms; " ..
            "$s=[System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus; " ..
            "if ($s -eq 'Offline') { 'battery' } elseif ($s -eq 'Online') { 'charging' } else { 'unknown' }",
        },
        playback_only = false,
        capture_stdout = true,
        capture_stderr = false,
        max_size = 64,
    })

    if not result or result.status ~= 0 then
        return nil
    end

    local mode = trim(result.stdout):lower()
    if mode == "battery" or mode == "charging" then
        return mode
    end

    return nil
end

local function detect_power_mode()
    if is_windows then
        return detect_windows_power_mode()
    end

    return detect_linux_power_mode()
end

local function profile_exists(name)
    local profiles = mp.get_property_native("profile-list", {})
    for _, profile in ipairs(profiles) do
        if profile == name then
            return true
        end

        if type(profile) == "table" and profile.name == name then
            return true
        end
    end

    return false
end

local function apply_power_profile()
    if disabled or not opts.enabled then
        return
    end

    local mode = detect_power_mode()
    if not mode then
        return
    end

    if mode == last_mode then
        return
    end

    local profile = mode == "battery" and opts.battery_profile or opts.charging_profile
    if not profile_exists(profile) then
        if not missing_profile_warnings[profile] then
            msg.warn("power-profile: profile '" .. profile .. "' is not defined; auto switch skipped")
            missing_profile_warnings[profile] = true
        end
        return
    end

    local ok, result = pcall(mp.commandv, "apply-profile", profile)
    if not ok or result == false then
        msg.error("power-profile: failed to apply profile '" .. profile .. "'")
        return
    end

    last_mode = mode
    msg.info("power-profile: " .. mode .. " detected, applied profile '" .. profile .. "'")

    if opts.show_osd then
        local label = mode == "battery" and "Battery mode" or "Full performance mode"
        mp.osd_message(label, 2)
    end
end

if not is_windows and not has_linux_power_supply() then
    disabled = true
    msg.verbose("power-profile: /sys/class/power_supply unavailable, disabling auto switch")
end

local interval = tonumber(opts.poll_interval) or 10
if interval < 2 then
    interval = 2
end

apply_power_profile()
mp.register_event("start-file", apply_power_profile)
mp.add_periodic_timer(interval, apply_power_profile)
