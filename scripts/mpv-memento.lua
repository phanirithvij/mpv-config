is_on = false
step = 5*60 -- seconds
overlap = 10 -- seconds

function recalc()
    local pos = mp.get_property_number("time-pos")
    local duration = mp.get_property_number("duration")
    next_seek = math.ceil((pos+1)/step)*step+overlap
    if next_seek > duration then
        next_seek = duration-1
    end
    seek_to = (math.floor((pos+1)/step)-1)*step
end

function start()
    local duration = mp.get_property_number("duration")
    mp.commandv("seek", math.floor(duration/step)*step, "absolute+exact")
    recalc()
end

function toggle()
    is_on = not is_on

    if is_on then
        mp.osd_message("Memento mode: on")
        start()
        timer = mp.add_periodic_timer(1, function()
            local pos = mp.get_property_number("time-pos")
            if pos >= next_seek then
                if seek_to < 0 then
                    mp.command("stop")
                end
                mp.commandv("seek", seek_to, "absolute+exact")
                recalc()
            end
        end)
        mp.register_event("seek", function()
            local pos = mp.get_property_number("time-pos")
            recalc()
        end)
    else
        mp.osd_message("Memento mode: off")
        timer:kill()
    end
end

mp.add_key_binding("M", "toggle-memento", toggle)