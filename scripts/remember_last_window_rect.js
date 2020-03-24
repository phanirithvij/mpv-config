// Modified by Phani Rithvij (github.com/phanirithvij)
// Extended from Pablo Bollansée's https://github.com/TheOddler/mpv-config

// Sometime the leftmost screen doesn't have id 0
// not sure yet how to detect this automatically
var leftMostScreen = 1

// Some setup used by both reading and writing
var dir = mp.utils.split_path(mp.get_script_file())[0]
var rect_path = mp.utils.join_path(dir, "last_window_rect.txt")

dump(rect_path)

// Read last window rect if present
var rect = null
try {
    rect = mp.utils.read_file(rect_path).trim().split(' ')
} catch (e) {
    dump(e)
}

if (rect != null) {
    var x = rect[0]
    var y = rect[1]
    var width = rect[2]
    var height = rect[3]
    mp.set_property("screen", leftMostScreen)
    var autofit = width + "x" + height
    dump("Set autofit: " + autofit)
    mp.set_property("autofit", autofit)
    var geometry = width + "x" + height + "+" + x + "+" + y
    mp.set_property("geometry", geometry)

    // fetch the rect on load
    mp.register_event("file-loaded", fetch_rect)
}
dump("Pid of mpv is this", mp.utils.getpid().toString())

// fetch the screen dimensions
function fetch_rect() {
    var ps1_script = mp.utils.join_path(dir, "Get-Client-Rect.ps1")
    var args = ["powershell", "-File", ps1_script, mp.utils.getpid().toString()]
    var output = mp.utils.subprocess({
        args: args,
        cancellable: false
    }).stdout
    dump("fetched ", output)
    var newRect = output.trim().split(' ')
    var fact = 1.25
    var i = 0;
    newRect.forEach(function(_) {
        newRect[i] *= fact
        newRect[i] = Math.round(newRect[i])
        i++
    })

    dump("new", newRect.join(" "))
    if (rect != null) {
        dump("old", rect.join(" "))
            // return rect.join(" ")
    }
    return newRect.join(" ")
}

// fetches and saves the dims
function fetchAndSave() {
    var output = fetch_rect()
    save_rect(output)
}

// Save the rect in a file
// Need to do this before exit to save last screen dims
function save_rect(rect) {
    mp.utils.write_file("file://" + rect_path, rect)
}

// i.e. this
mp.register_event("shutdown", fetchAndSave)