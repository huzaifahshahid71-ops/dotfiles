pragma Singleton

// System numbers for the dashboard. One small bash read every 2 s, and only
// while something is watching - nothing runs while the dashboard is closed.
//
//   CPU        /proc/stat, as the change since the previous read
//   memory     /proc/meminfo, used = total - available
//   GPU, VRAM  the amdgpu card's own sysfs files; else an NVIDIA card through
//              nvidia-smi, but only while it is already awake (see below)
//   temps      k10temp / zenpower / coretemp (CPU), amdgpu hwmon (edge, junction)
//   disks      df on / and /home
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool watched: false

    property real cpu: 0
    property real mem: 0
    property real memUsed: 0                 // GiB
    property real memTotal: 0
    property real gpu: 0
    property real vramUsed: 0                // GiB
    property real vramTotal: 0
    property real cpuTemp: 0
    property real gpuTemp: 0
    property real gpuJunction: 0
    property bool gpuAsleep: false           // a hybrid laptop's dGPU, powered down
    property var disks: []                   // [{mount, size, used}] bytes
    property real uptime: 0                  // seconds
    property string os: ""
    property string kernel: ""
    property string cpuName: ""
    property var lastCpu: null

    readonly property string uptimeText: {
        const m = Math.floor(uptime / 60), d = Math.floor(m / 1440), h = Math.floor(m % 1440 / 60)
        return (d ? d + "d " : "") + (d || h ? h + "h " : "") + m % 60 + "m"
    }

    readonly property string sampleScript: `
read -r _ u n s i w x y z _ < /proc/stat; echo "cpu $u $n $s $i $w $x $y $z"
awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print "mem", t, a}' /proc/meminfo
echo "uptime $(cut -d' ' -f1 /proc/uptime)"
amd=
for d in /sys/class/drm/card*/device; do
    [ -r "$d/gpu_busy_percent" ] || continue
    amd=1
    echo "gpu $(cat "$d/gpu_busy_percent") $(cat "$d/mem_info_vram_used") $(cat "$d/mem_info_vram_total")"
    for h in "$d"/hwmon/hwmon*; do
        echo "gputemp $(cat "$h/temp1_input" 2>/dev/null || echo 0) $(cat "$h/temp2_input" 2>/dev/null || echo 0)"
        break
    done
    break
done
# NVIDIA (the laptop's dGPU). Asking nvidia-smi powers a sleeping card up and
# keeps it up, which on battery is the whole cost of a hybrid laptop - so a
# card the driver has runtime-suspended is reported asleep, not asked.
if [ -z "$amd" ] && command -v nvidia-smi >/dev/null; then
    for p in /sys/bus/pci/drivers/nvidia/0000:*; do
        [ -e "$p/power/runtime_status" ] || continue
        if [ "$(cat "$p/power/runtime_status")" = suspended ]; then
            echo "nvasleep"
        else
            nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu \
                --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d ',' | sed 's/^/nvgpu /'
        fi
        break
    done
fi
for h in /sys/class/hwmon/hwmon*; do
    case "$(cat "$h/name" 2>/dev/null)" in
    k10temp|zenpower|coretemp) echo "cputemp $(cat "$h/temp1_input")"; break ;;
    esac
done
df -B1 --output=target,size,used / /home 2>/dev/null | tail -n +2 | awk '{print "disk", $1, $2, $3}'
`

    Timer {
        interval: 2000
        repeat: true
        running: root.watched
        triggeredOnStart: true
        onTriggered: if (!sampler.running) sampler.running = true
    }

    Process {
        id: sampler
        command: ["bash", "-c", root.sampleScript]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        running: true
        command: ["bash", "-c", ". /etc/os-release; echo \"os $PRETTY_NAME\"; echo \"kernel $(uname -r)\"; "
                 + "echo \"cpuname $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const key = line.split(" ")[0], value = line.slice(key.length + 1)
                    if (key === "os") root.os = value
                    else if (key === "kernel") root.kernel = value
                    else if (key === "cpuname") root.cpuName = value
                }
            }
        }
    }

    function parse(text) {
        const found = []
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/)
            switch (f[0]) {
            case "cpu": {
                const v = f.slice(1).map(Number)
                const idle = v[3] + v[4], total = v.reduce((a, b) => a + b, 0)
                if (lastCpu && total > lastCpu.total)
                    cpu = 1 - (idle - lastCpu.idle) / (total - lastCpu.total)
                lastCpu = { total: total, idle: idle }
                break
            }
            case "mem": {
                const t = Number(f[1]), a = Number(f[2])
                memTotal = t / 1048576
                memUsed = (t - a) / 1048576
                mem = t ? (t - a) / t : 0
                break
            }
            case "uptime":
                uptime = Number(f[1])
                break
            case "gpu":
                gpu = Number(f[1]) / 100
                vramUsed = Number(f[2]) / 1073741824
                vramTotal = Number(f[3]) / 1073741824
                break
            case "gputemp":
                gpuTemp = Number(f[1]) / 1000
                gpuJunction = Number(f[2]) / 1000
                break
            case "nvgpu":                    // util %, VRAM used and total in MiB, temp °C
                gpu = Number(f[1]) / 100
                vramUsed = Number(f[2]) / 1024
                vramTotal = Number(f[3]) / 1024
                gpuTemp = Number(f[4])
                gpuAsleep = false
                break
            case "nvasleep":
                gpu = 0
                vramUsed = 0
                gpuTemp = 0
                gpuAsleep = true
                break
            case "cputemp":
                cpuTemp = Number(f[1]) / 1000
                break
            case "disk":
                found.push({ mount: f[1], size: Number(f[2]), used: Number(f[3]) })
                break
            }
        }
        // Reassigning rebuilds the delegates showing it; only do so on change.
        if (JSON.stringify(found) !== JSON.stringify(disks))
            disks = found
    }

    function gib(bytes) {
        const g = bytes / 1073741824
        return g >= 1000 ? (g / 1024).toFixed(2) + " TiB" : g.toFixed(g >= 100 ? 0 : 1) + " GiB"
    }
}
