#!/usr/bin/env python3
"""Small, unprivileged Wayland power and process menu."""
import os
import pathlib
import signal
import subprocess
import sys


def menu(prompt, items):
    args = ["fuzzel"]
    if config := os.environ.get("FUZZEL_CONFIG"):
        args.extend(["--config", config])
    args.extend(["--dmenu", "--anchor", "center", "--width", "24",
                 "--minimal-lines", "--no-exit-on-keyboard-focus-loss",
                 "--font", "IBM Plex Sans:size=40", "--prompt", prompt])
    p = subprocess.run(args, input="\n".join(items) + "\n", text=True, capture_output=True)
    return p.stdout.strip() if p.returncode == 0 else None


def message(text):
    print(text, file=sys.stderr)
    menu("Press Escape >", [text])


def processes():
    found = {}
    for path in pathlib.Path("/proc").iterdir():
        if not path.name.isdecimal():
            continue
        try:
            if path.stat().st_uid != os.getuid():
                continue
            pid = int(path.name)
            # /proc/PID/stat's second field is in parentheses and may contain spaces.
            stat = (path / "stat").read_text().rsplit(") ", 1)[1].split()
            start = stat[19]  # field 22, after stripping pid and comm
            name = (path / "comm").read_text().strip()
            if name in {"sway", "waybar", "systemd", "fuzzel", "swayidle", "dbus-daemon"}:
                continue
            label = f"{name}  (PID {pid})"
            found[label] = (pid, start)
        except (OSError, IndexError, ValueError):
            continue
    return found


def kill_process():
    found = processes()
    if not found:
        message("No user processes found")
        return
    selected = menu("Terminate process >", sorted(found))
    if selected not in found:
        return
    pid, start = found[selected]
    try:
        path = pathlib.Path(f"/proc/{pid}")
        current = (path / "stat").read_text().rsplit(") ", 1)[1].split()[19]
        if path.stat().st_uid != os.getuid() or current != start:
            raise RuntimeError("Process exited or PID was reused")
        # pidfd pins the process identity so a PID cannot be reused between
        # verification and delivery. Never pass the menu selection to a shell.
        fd = os.pidfd_open(pid)
        try:
            signal.pidfd_send_signal(fd, signal.SIGTERM)
        finally:
            os.close(fd)
    except (OSError, IndexError, RuntimeError) as error:
        message(f"Could not terminate process: {error}")


def main():
    selected = menu("> ", ["Logout", "Reboot", "Shutdown", "Kill process"])
    if selected == "Kill process":
        kill_process()
    elif selected in {"Logout", "Reboot", "Shutdown"}:
        if menu(f"Confirm {selected.lower()} >", [f"Yes, {selected.lower()}", "Cancel"]) != f"Yes, {selected.lower()}":
            return
        command = {"Logout": ["swaymsg", "exit"], "Reboot": ["systemctl", "reboot"],
                   "Shutdown": ["systemctl", "poweroff"]}[selected]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode:
            message(f"{selected} failed: {result.stderr.strip()[:160]}")


if __name__ == "__main__":
    main()
