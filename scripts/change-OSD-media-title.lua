function set_osd_title()
	local name = mp.get_property_osd("filename")
	local percent_pos = ""
	local chapter = ""
	local frames_dropped = ""
	local pl = ""

	if mp.get_property_number("playlist-count", 0) > 1 then
		pl = "[" .. mp.get_property_number("playlist-pos", 0) + 1 .. "/" .. mp.get_property_number("playlist-count", 0) .."] "
	end

	if mp.get_property_osd("percent-pos") ~= "" then
		percent_pos = " • " .. mp.get_property_osd("percent-pos") .. "% completed"
	end

	if mp.get_property_osd("chapter") ~= "" then
		chapter = " • Chapter: " .. mp.get_property_osd("chapter")
	end

	if mp.get_property_osd("frame-drop-count") ~= "0" then
		if mp.get_property_osd("frame-drop-count") == "1" then
			frames_dropped = " • " .. mp.get_property_osd("frame-drop-count") .. " dropped frame"
		else
			frames_dropped = " • " .. mp.get_property_osd("frame-drop-count") .. " dropped frames"
		end
	end

	mp.set_property("force-media-title", pl .. name .. percent_pos .. chapter .. frames_dropped)
end

mp.observe_property("playlist-count", "number", set_osd_title)
mp.observe_property("playlist-pos", "number", set_osd_title)
mp.observe_property("percent-pos", "number", set_osd_title)
mp.observe_property("chapter", "string", set_osd_title)
mp.observe_property("frame-drop-count", "number", set_osd_title)
