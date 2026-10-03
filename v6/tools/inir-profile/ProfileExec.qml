pragma Singleton
import Quickshell

Singleton {
    function execDetached(args): void {
        const argv = Array.from(args ?? []).map(String)
        if (argv.length === 0) return
        const root = Quickshell.env("INIR_PROFILE_ROOT")
        const command = argv[0].split("/").pop()
        // Shell scripts, state writers and hardware/IPC helpers stay private.
        // Applications and URI openers get the original HOME and XDG settings.
        const helpers = ["bash", "sh", "fish", "env", "python", "python3", "qs", "inir", "systemd-run",
            "niri", "hyprctl", "systemctl", "mkdir", "rm", "test", "touch", "cp", "mv",
            "notify-send", "wl-copy", "wl-paste", "brightnessctl", "ddcutil", "wpctl",
            "pw-play", "playerctl", "kill", "killall", "pkill", "gsettings", "xdg-settings"]
        const privateCommand = helpers.includes(command) || argv[0].startsWith(root + "/runtime/")
        Quickshell.execDetached(privateCommand ? argv : ["/usr/bin/python3", root + "/environment.py", "--", ...argv])
    }
}
