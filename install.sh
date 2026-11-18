#!/bin/bash
# Install the "Log On to Hyprland" (Windows 2000 style) greeter next to the stock ReGreet.
#
#   build first (as yourself):  ./build.sh
#   then install (as root):     sudo ./install.sh
#   undo:                       sudo ./install.sh --uninstall
#
# What it touches:
#   /usr/local/bin/regreet-win2k   the patched ReGreet 0.5.0 (the packaged /usr/bin/regreet stays)
#   /etc/greetd/win2k/             its config, stylesheet and images
#   /etc/greetd/hyprland.lua       only the line that launches the greeter; the original file is
#                                  kept as hyprland.lua.pre-win2k
#
# The launch line falls back to the stock greeter if the patched one fails to run (for example
# after a GTK update, until it's rebuilt), so a broken build can't lock you out.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bin=/usr/local/bin/regreet-win2k
theme=/etc/greetd/win2k
lua=/etc/greetd/hyprland.lua
backup=$lua.pre-win2k

# The line in $lua that runs the given greeter command and leaves Hyprland once it exits.
launch_line() {
    echo "hl.exec_cmd(\"$1; /usr/bin/hyprctl dispatch 'hl.dsp.exit()'\")"
}
stock_line=$(launch_line /usr/bin/regreet)
win2k_line=$(launch_line "$bin -c $theme/regreet.toml -s $theme/regreet.css || /usr/bin/regreet")

# Replace the text $1 with $2 in $lua.
swap_line() {
    local text
    text=$(<"$lua")
    printf '%s\n' "${text//"$1"/"$2"}" > "$lua"
}

if [[ $EUID -ne 0 ]]; then
    echo "Run this as root: sudo $0 $*" >&2
    exit 1
fi

if [[ ${1:-} == --uninstall ]]; then
    if grep -qF "$win2k_line" "$lua"; then
        swap_line "$win2k_line" "$stock_line"
    fi
    rm -f "$bin" "$backup"
    rm -rf "$theme"
    echo "Removed; greetd launches the stock ReGreet again."
    exit 0
fi

built=$here/src-regreet/target/release/regreet
if [[ ! -x $built ]]; then
    echo "Build it first (as yourself, not root): $here/build.sh" >&2
    exit 1
fi

if ! grep -qF "$win2k_line" "$lua" && ! grep -qF "$stock_line" "$lua"; then
    echo "$lua doesn't contain the expected greeter launch line; not touching anything." >&2
    exit 1
fi

install -Dm755 "$built" "$bin"
install -d -m755 "$theme"
install -m644 "$here"/theme/* "$theme"/

if grep -qF "$stock_line" "$lua"; then
    cp -p "$lua" "$backup"
    swap_line "$stock_line" "$win2k_line"
fi

echo "Installed. The new greeter shows up the next time greetd starts one (log out or reboot)."
