-- gallery-dl_hook.lua
--
-- load online image galleries as playlists using gallery-dl
-- https://github.com/mikf/gallery-dl
--
-- to use, prepend the gallery url with: gallery-dl://
-- e.g.
--     `mpv gallery-dl://https://imgur.com/....`
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local mp = require 'mp'

local function exec(args)
    local ret = utils.subprocess({args = args})
    return ret.status, ret.stdout, ret
end

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end
function join(sep, arr, count)
    local r = ""
    if count == nil then count = #arr end
    for i = 1, count do
        if i > 1 then r = r .. sep end
        r = r .. utils.to_string(arr[i])
    end
    return r
end

mp.add_hook("on_load", 15, function()
    local url = mp.get_property("stream-open-filename", "")
    if (url:find("gallery%-dl://") ~= 1) then
        msg.debug("not a gallery-dl:// url: " .. url)
        return
    end
    local url = string.gsub(url, "gallery%-dl://", "")

    -- gallery-dl's bug was fixed in https://github.com/mikf/gallery-dl/commit/4bc161ca0fcff27e2f2f1dc4c8ba7e9459b6403c
    -- only python's subprocess worked before
    -- So I modified it to call python and call gallery-dl from python's subprocess
    -- not needed anymore
    local es, urls, result = exec({
        "gallery-dl", "-g", url
    })

    if (es < 0) or (urls == nil) or (urls == "") then
        msg.error("failed to get album list.")
    end

    mp.commandv("loadlist", "memory://" .. urls)
end)
