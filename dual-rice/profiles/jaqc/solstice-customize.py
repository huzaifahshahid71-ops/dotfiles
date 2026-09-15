#!/usr/bin/env python3

from pathlib import Path
import hashlib
import sys

UPSTREAM_REPOSITORY = "https://github.com/MystiaFin/JAQC-shell.git"
UPSTREAM_COMMIT = "e3158623d1c5c2e0089aeb5270cd486545546164"

DATA = {'components/core/WallpaperLayer.qml': {'source_sha256': 'c762f6c16265bb6ad051dee3ec77cf90d29b901642dd41eacdeb91814ea4f89f', 'target_sha256': '3ef02d4af2aa7e6d7f95ddec1e3a32a9db823ac6274bdce66504fd541dd48896', 'edits': [(146, 147, ['                if (status === Image.Ready || status === Image.Error)\n'])]}, 'components/state/OverlayState.qml': {'source_sha256': 'bdb96a10630adbbd0eecfb7f112f15d69dfca564f9627183cf0a53514ae45c88', 'target_sha256': 'e28dcd51cdb26ff028b3f3b66601e4f58b8f0018ce31ab85da3e4fa2edd6aace', 'edits': [(151, 151, ['        target: "settings"\n', '\n', '        function toggle(): void {\n', '            if (root.settingsVisible)\n', '                root.hideSettings();\n', '            else\n', '                root.showSettings();\n', '        }\n', '\n', '        function show(): void {\n', '            root.showSettings();\n', '        }\n', '\n', '        function hide(): void {\n', '            root.hideSettings();\n', '        }\n', '\n', '        function getVisible(): bool {\n', '            return root.settingsVisible;\n', '        }\n', '    }\n', '\n', '    IpcHandler {\n'])]}, 'integrations/BtopThemeService.qml': {'source_sha256': '67a623b52a44c2a7f895d2139fd1cc08c0f239c3162e44a1df1082e99f113502', 'target_sha256': '7d3a41557fa6b909dff001be0a6307514a1cb2cd33aad1a6e2399e37917506fb', 'edits': [(15, 16, ['    readonly property string themePath: themeDirectory + "/desktop-profile/solstice.theme"\n'])]}, 'integrations/CavaThemeService.qml': {'source_sha256': '6a1a4e1df4d7d7fa1266742d98d0635fa660485ec64bda1afc290d8703dcb45d', 'target_sha256': '88e94c9a3a865c360d11a5f04f4275d53b7fcf46bbdfeee02a61ee2c05070032', 'edits': [(15, 16, ['    readonly property string themePath: themeDirectory + "/desktop-profile/solstice"\n'])]}, 'integrations/SpotifyThemeService.qml': {'source_sha256': 'f3502e48902395935abf1c241aba9b18ec60226f5564fc91ba89f151e482ee4b', 'target_sha256': 'a0e70f6173af459415bac9800b1d5af2ddb8cf91085861a265c1048d0504b8d9', 'edits': [(14, 15, ['    readonly property string themeDirectory: cacheHome + "/desktop-profile/solstice-theme"\n'])]}, 'integrations/TerminalThemeService.qml': {'source_sha256': 'b3326a658a72ee356e42dd4592fb4c5f2370773c5c7da9f7a8efade91e52b6d6', 'target_sha256': 'e38e3595ad81a9ceda3bd0cdb1491b0a2d88137d0c2156249c01f92b759ae471', 'edits': [(13, 14, ['    readonly property string quickshellConfigDirectory: configHome + "/desktop-profile/solstice"\n'])]}, 'integrations/TmuxThemeService.qml': {'source_sha256': '67a8ad37e02cffa00d7fceae7aecdd14da680b8ed39d9ae930d116823e6cbb65', 'target_sha256': 'ccc77935f2634c3853e9629cb6e59ac6a268f5e70c375c6c0e5f45b5a7ef3692', 'edits': [(14, 15, ['    readonly property string themePath: configHome + "/desktop-profile/solstice/tmux-colors.conf"\n'])]}, 'services/AudioService.qml': {'source_sha256': 'c55eeed069fe485f987109a86a492b07eb174ee2c8131e8cdd7c936cba12338a', 'target_sha256': '73eacae7c8b70f59f38695669495824800003341d065668baedc29cfd15fe783', 'edits': [(74, 75, ['        interval: 16\n']), (88, 89, ['        interval: 16\n']), (97, 97, ['        }\n', '    }\n', '\n', '    Process {\n', '        id: audioEventWatcher\n', '        running: true\n', '        command: [\n', '            "sh",\n', '            "-c",\n', '            "command -v pactl >/dev/null 2>&1 && exec pactl subscribe"\n', '        ]\n', '\n', '        stdout: SplitParser {\n', '            onRead: data => {\n', '                const lower = data.toLowerCase();\n', '\n', '                if (lower.includes("sink")\n', '                        || lower.includes("server")) {\n', '                    if (!sinkReader.running)\n', '                        sinkReader.running = true;\n', '                }\n', '\n', '                if (lower.includes("source")\n', '                        || lower.includes("server")) {\n', '                    if (!sourceReader.running)\n', '                        sourceReader.running = true;\n', '                }\n', '            }\n'])]}, 'services/DebugInfoService.qml': {'source_sha256': 'e6681079186dabfd75d385bbf68eb6143a3b4a09b2b2a7a3b170ac2863b388db', 'target_sha256': '0d8512b262c4c97cb5b7e1bb314582f3bac4eeb308f53ac76f866b290c5e0f71', 'edits': [(9, 10, ['    readonly property string configDirectory: SettingsService.configHome + "/desktop-profile/solstice"\n'])]}, 'services/MediaService.qml': {'source_sha256': 'dc8be5070d8087e56dc458f5ae03618a6d240ad2cb51f3d9b33c077f75dc34a9', 'target_sha256': '50f966b9810dadb27e77d0433497c05ea5d7151d2a67cb603ed5ef639fac2a1f', 'edits': [(42, 42, ['    readonly property bool canSeek: currentPlayer ? currentPlayer.canSeek : false\n']), (77, 77, ['    function seekTo(seconds: real): void {\n', '        if (!currentPlayer || !currentPlayer.canSeek)\n', '            return;\n', '\n', '        const target = Math.max(\n', '            0,\n', '            Math.min(durationSeconds, seconds)\n', '        );\n', '\n', '        if (currentPlayer.positionSupported)\n', '            currentPlayer.position = target;\n', '        else\n', '            currentPlayer.seek(target - currentPlayer.position);\n', '\n', '        currentPlayer.positionChanged();\n', '    }\n', '\n']), (80, 81, ['        interval: 250\n'])]}, 'services/SettingsService.qml': {'source_sha256': '0be624585412f9a32067882f36451b64135b5734bae1ecb840642736c9bb381b', 'target_sha256': '74a1a706f5ff54f692d986dc963b67de1e6e0dc4caf5dfdf6c5b4e2ffc9b3233', 'edits': [(513, 514, ['        path: root.configHome + "/desktop-profile/solstice/settings.json"\n'])]}, 'services/WallpaperService.qml': {'source_sha256': 'f3987f08a58ddae8974f32dad500bb47e9dd5546cafd638ea0eeb9181e23bde4', 'target_sha256': 'c82038232451494bedea2999fd8a8ecb38b53c0c23e22b085270493756c6126b', 'edits': [(70, 71, ['        path: root.configHome + "/desktop-profile/solstice/wallpaper-selection"\n'])]}, 'services/WeatherService.qml': {'source_sha256': '3a70034de65551143445e09b9f720379fc9a4741ca606ae2cf47a6b9912eec13', 'target_sha256': '79fc10db64c1ccbb6bb095f66bf537275c223d6da72cfc62b1af3e8e28d72311', 'edits': [(175, 176, ['        path: root.configHome + "/desktop-profile/solstice/weather-location.json"\n'])]}, 'services/cava-raw.conf': {'source_sha256': '3db168deabc60da5c16f7d3caa892a7a91f87f07f535f5c874db85810367eed0', 'target_sha256': '8f0b72434e71f218a1ccb4b8422b651f9a956f26a7e42ce21d6b12d2e212a69b', 'edits': [(2, 3, ['framerate = 60\n'])]}, 'widgets/controlcenter/MediaCard.qml': {'source_sha256': '1aa4ddc03dbe2add079de66f09fb7a62200dd0bc7133ac5a1f7a4dcdf806f0ec', 'target_sha256': 'd74f2e3d2d9ce304e4fd41145a78c5f5a3ba339e7aa8d6b47d180f5261275618', 'edits': [(180, 181, ['                Item {\n', '                    id: seekBar\n', '\n']), (182, 185, ['                    Layout.preferredHeight: 18\n', '\n', '                    property bool dragging: false\n', '                    property real dragFraction: 0\n']), (187, 194, ['                        id: seekTrack\n']), (195, 198, ['                        anchors {\n', '                            left: parent.left\n', '                            right: parent.right\n', '                            verticalCenter: parent.verticalCenter\n', '                        }\n', '\n', '                        height: 5\n', '                        radius: height / 2\n', '                        color: Theme.surfaceBorderColor\n', '\n', '                        Rectangle {\n', '                            width: parent.width * (\n', '                                seekBar.dragging\n', '                                    ? seekBar.dragFraction\n', '                                    : MediaService.durationSeconds > 0\n', '                                        ? Math.max(0, Math.min(1,\n', '                                            MediaService.positionSeconds\n', '                                            / MediaService.durationSeconds))\n', '                                        : 0\n', '                            )\n', '\n', '                            height: parent.height\n', '                            radius: parent.radius\n', '                            color: Theme.accentColor\n', '\n', '                            Behavior on width {\n', '                                enabled: !seekBar.dragging\n', '\n', '                                SmoothedAnimation {\n', '                                    velocity: ShellMetrics.continuousMotionVelocity\n', '                                }\n']), (199, 199, ['                        }\n', '                    }\n', '\n', '                    MouseArea {\n', '                        anchors.fill: parent\n', '\n', '                        enabled: MediaService.canSeek\n', '                            && MediaService.durationSeconds > 0\n', '\n', '                        hoverEnabled: true\n', '                        cursorShape: enabled\n', '                            ? Qt.PointingHandCursor\n', '                            : Qt.ArrowCursor\n', '\n', '                        function updateFraction(pointerX: real): void {\n', '                            seekBar.dragFraction = Math.max(\n', '                                0,\n', '                                Math.min(1, pointerX / width)\n', '                            );\n', '                        }\n', '\n', '                        onPressed: mouse => {\n', '                            seekBar.dragging = true;\n', '                            updateFraction(mouse.x);\n', '                        }\n', '\n', '                        onPositionChanged: mouse => {\n', '                            if (pressed)\n', '                                updateFraction(mouse.x);\n', '                        }\n', '\n', '                        onReleased: mouse => {\n', '                            updateFraction(mouse.x);\n', '\n', '                            MediaService.seekTo(\n', '                                seekBar.dragFraction\n', '                                * MediaService.durationSeconds\n', '                            );\n', '\n', '                            seekBar.dragging = false;\n', '                        }\n', '\n', '                        onCanceled: {\n', '                            seekBar.dragging = false;\n'])]}}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def customize(root):
    root = Path(root).resolve()

    changed = 0
    already = 0

    for relative, spec in DATA.items():
        path = root / relative

        if not path.is_file():
            raise SystemExit(
                "❌ Missing expected JAQC file: {}".format(relative)
            )

        current = digest(path)

        if current == spec["target_sha256"]:
            print("✅ already customized: {}".format(relative))
            already += 1
            continue

        if current != spec["source_sha256"]:
            raise SystemExit(
                "❌ Refusing to modify unexpected version: {}\n"
                "   expected pristine: {}\n"
                "   found:             {}".format(
                    relative,
                    spec["source_sha256"],
                    current,
                )
            )

        lines = path.read_text().splitlines(keepends=True)

        for i1, i2, replacement in reversed(spec["edits"]):
            lines[i1:i2] = replacement

        path.write_text("".join(lines))

        result = digest(path)

        if result != spec["target_sha256"]:
            raise SystemExit(
                "❌ Verification failed after patching: {}\n"
                "   expected: {}\n"
                "   found:    {}".format(
                    relative,
                    spec["target_sha256"],
                    result,
                )
            )

        print("✅ customized: {}".format(relative))
        changed += 1

    print()
    print(
        "Solstice customization complete: "
        "{} changed, {} already customized".format(
            changed,
            already,
        )
    )


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    customize(root)
