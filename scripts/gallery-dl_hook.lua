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
-- local inspect = require 'inspect'

local function exec(args)
    -- local retx = mp.commandv(args)
    -- print(args)
    local ret = utils.subprocess({args = args})
    for k, v in pairs(ret) do
        print(k .. ",")
        print(v)
    end
    print(dump(ret))
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
    -- msg.error(url)
    local res, val, err = mp.command_native(
                              {
            name = "subprocess",
            args = {"py", "D:\\Projects\\fun\\lua\\py.py", url},
            capture_stdout = true
        })
    local urls = res.stdout
    local es = res.status

    -- local file = assert(io.popen("bash -c gallery-dl -g " .. url, 'r'))
    -- local output = file:read('*all')
    -- file:close()
    -- print(output)
    -- print("done subprocess: " .. join(" ", {res, val, err}))
    local data = mp.commandv("subprocess", "gallery-dl", "-g", url, ">data.tmp")
    print("Nigga")

    -- local es, urls, result = exec({
    --     -- "gallery-dl", "-g", url
    -- })
    if (es < 0) or (urls == nil) or (urls == "") then
        msg.error("failed to get album list.")
    end

    mp.commandv("loadlist", "memory://" .. urls)
end)
