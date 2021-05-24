-- Ported to lua by Phani Rithvij (github.com/phanirithvij)
-- Extended from Pablo Bollansée's https://github.com/TheOddler/mpv-config
-- https://stackoverflow.com/a/57635703/8608146
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local mp = require 'mp'

-- https://stackoverflow.com/a/27028488/8608146
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

-- https://stackoverflow.com/a/26777901/8608146
function round(x) return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5) end

-- https://stackoverflow.com/a/23535333/8608146
function script_path()
    local str = debug.getinfo(2, "S").source
    -- local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

local dir = script_path()
local rect_path = utils.join_path(dir, "last_window_rect.txt")
msg.verbose(rect_path)

function utils.read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file.close()
    return content
end

function utils.write_file(path, content)
    local file = io.open(path, "w")
    msg.verbose("Writing this", content)
    file:write(content)
    file.close()
end

-- http://lua-users.org/wiki/SplitJoin
function string:split(sSeparator, nMax, bRegexp)
    if self == nil then return end
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)

    local aRecord = {}

    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst, nLast = self:find(sSeparator, nStart, bPlain)
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst - 1)
            nField = nField + 1
            nStart = nLast + 1
            nFirst, nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax - 1
        end
        aRecord[nField] = self:sub(nStart)
    end

    return aRecord
end

-- Sometime the leftmost screen doesn't have id 0
-- not sure yet how to detect this automatically
local leftMostScreen = 1

-- Read last window rect if present
local rectd = utils.read_file(rect_path)
local rect = string.split(rectd, ' ')

if (rect ~= nil and #rect == 4) then
    msg.verbose("Valid", dump(rect))
    -- lua has one based indexing
    local x = rect[1]
    local y = rect[2]
    local width = rect[3]
    local height = rect[4]
    -- -- setting screen property
    mp.set_property("screen", leftMostScreen)
    local autofit = width .. "x" .. height
    local geometry = width .. "x" .. height .. "+" .. x .. "+" .. y
    mp.set_property("geometry", geometry)
    msg.verbose("Set autofit: " .. autofit)
    mp.set_property("autofit", autofit)
    -- mp.set_property("no-keepaspect-window", "")
    msg.verbose(x, y, width, height)

    -- fetch the rect on load
    mp.register_event("file-loaded", fetch_rect)
else
    msg.error("Invalid size found in the size config file")
end

-- TODO
-- mp.get_property_bool("fullscreen", false)

function fetch_rect()
    msg.verbose("Fetching rect...")
    local ps1_script = utils.join_path(dir, "Get-Client-Rect.ps1")
    local args = {"powershell", "-File", ps1_script, "" .. utils.getpid()}
    local output = utils.subprocess({args = args, cancellable = false})
    if output.status == 0 then
        local newRect = string.split(output.stdout, ' ')
        msg.verbose("New Rect")
        msg.verbose(dump(newRect))
        -- TODO determine the issue here why it is 1.25 times smaller
        -- Use osd-width and osd-height
        local fact = 1.25
        -- local fact = 1
        local i = 0;
        for key, value in pairs(newRect) do
            newRect[key] = newRect[key] * fact
            newRect[key] = round(newRect[key])
        end
        msg.verbose("new")
        msg.verbose(dump(table.concat(newRect, " ")))
        if (rect) then
            msg.verbose("old")
            msg.verbose(dump(table.concat(rect, " ")))
        end
        return table.concat(newRect, " ")
    end
end

function trim(s) return (s:gsub("^%s*(.-)%s*$", "%1")) end

-- fetches and saves the dims
function fect_and_save()
    local output = fetch_rect()
    if output == nil then
        msg.warn("nil output for fetch_rect")
        return
    end
    save_rect(trim(output))
end

-- Save the rect in a file
-- Need to do this before exit to save last screen dims
function save_rect(rect) utils.write_file(rect_path, rect) end

-- i.e. this
mp.register_event("shutdown", fect_and_save)

data = mp.command_native_async({
    name = "subprocess",
    args = {"bash", "-c", "echo hi"},
    capture_stdout = true
}, function(res, val, err)
    msg.verbose("done subprocess: " .. dump({res, val, err}))
end)

msg.verbose(data)

local properties = {
    "keepaspect", "video-out-params", "video-unscaled", "panscan", "video-zoom",
    "video-align-x", "video-pan-x", "video-align-y", "video-pan-y", "osd-width",
    "osd-height", "geometry", "border"
}

function observe(k, v)
    -- msg.verbose(k, v)
    if (k == "fullscreen") then
        msg.verbose("HELPPP")
    else
        if k == "border" then border_visible = v end
        msg.verbose(k)
    end
end

border_visible = false

for _, p in ipairs(properties) do mp.observe_property(p, "native", observe) end

-- mp.observe_property("fullscreen", "bool", observe)
-- mp.observe_property("border", "bool", observe)
-- mp.observe_property("geometry", "string", observe)

-- Set-Window -ProcessName mpv -X 0 -Y 0 -Width 1920 -Height 1080

function move_up_incr(...)
    local args = {...}
    print("move UP", dump(args))

    local incr_move = 3

    if #args >= 1 then incr_move = args[1] end

    local output_r = fetch_rect()

    local rect_fetched = string.split(output_r, ' ')
    local x = rect_fetched[1]
    local y = rect_fetched[2]
    local width = rect_fetched[3]
    local height = rect_fetched[4]

    print(x, y, width, height)
    width = tonumber(mp.get_property("osd-width"))
    height = tonumber(mp.get_property("osd-height"))

    print(x, y, width, height)
    local autofit = width .. "x" .. height
    y = y + incr_move
    local geometry = width .. "x" .. height .. "+" .. x .. "+" .. y

    -- mp.set_property("geometry", geometry)
    -- print("Set autofit: " .. autofit)
    -- mp.set_property("autofit", autofit)
    -- mp.set_property("no-keepaspect-window", "")
    x = round(x / 1.25)
    y = round(y / 1.25)
    width = round(width / 1.25)
    height = round(height / 1.25)
    print(x, y, width, height)
    print(border_visible)

    local ps1_script = utils.join_path(dir, "Set-Window.ps1")
    local args = {
        "powershell", "-File", ps1_script, "-ProcessName", "mpv", "-X", "" .. x,
        "-Y", "" .. y, "-Width", "" .. width, "-Height", "" .. height
    }
    local output = utils.subprocess({args = args, cancellable = false})
    msg.verbose(dump(output))
    if output.status == 0 then msg.verbose(output.stdout) end
end

function move_left_incr(...)
    local args = {...}
    print(dump(args))

    local incr_move = 3

    if #args >= 1 then incr_move = args[1] end

    local output_r = fetch_rect()

    local rect_fetched = string.split(output_r, ' ')
    local x = rect_fetched[1]
    local y = rect_fetched[2]
    local width = rect_fetched[3]
    local height = rect_fetched[4]

    -- debug.getinfo(1).currentline

    print(x, y, width, height)
    width = tonumber(mp.get_property("osd-width"))
    height = tonumber(mp.get_property("osd-height"))

    print(x, y, width, height)
    local autofit = width .. "x" .. height
    x = x + incr_move
    local geometry = width .. "x" .. height .. "+" .. x .. "+" .. y
    print(border_visible)

    mp.set_property("geometry", geometry)
    -- print("Set autofit: " .. autofit)
    mp.set_property("autofit", autofit)
    -- mp.set_property("no-keepaspect-window", "")
    x = round(x / 1.25)
    y = round(y / 1.25)
    width = round(width / 1.25)
    height = round(height / 1.25)
    print(x, y, width, height)

    local ps1_script = utils.join_path(dir, "Set-Window.ps1")
    local args = {
        "powershell", "-File", ps1_script, "-ProcessName", "mpv", "-X", "" .. x,
        "-Y", "" .. y, "-Width", "" .. width, "-Height", "" .. height
    }
    local output = utils.subprocess({args = args, cancellable = false})
    msg.verbose(dump(output))
    if output.status == 0 then msg.verbose(output.stdout) end
end


mp.add_key_binding(nil, "move-y", move_up_incr)
mp.add_key_binding(nil, "move-x", move_left_incr)
