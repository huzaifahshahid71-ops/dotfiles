pragma Singleton

// GitHub and local git for the dashboard's GitHub tab. Everything goes
// through `gh` (signed in once with `gh auth login`) and `git`. Nothing is
// polled: it refreshes when the tab opens (if older than a minute) and
// after every action.
//
//   remote   your repos, your open PRs, PRs waiting on your review, issues
//            assigned to you
//   local    every repo under ~ (depth 5, skipping ~/snap - the Steam
//            library - ~/.cache and ~/.local): branch, ahead/behind, changes
//   actions  pull (fast-forward only), push, fetch all, clone into ~/src,
//            publish a local repo to GitHub; each ends with a notification
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool checked: false
    property bool authed: false
    property string login: ""
    property var repos: []
    property var myPrs: []
    property var reviewPrs: []
    property var issues: []
    property var local: []
    property int remoteLoading: 0
    property bool localLoading: false
    property string busy: ""                 // what an action is running on
    property real refreshedAt: 0

    readonly property string home: Quickshell.env("HOME")
    readonly property string cloneDir: home + "/src"

    function refresh() {
        refreshedAt = Date.now()
        authCheck.running = true
        scanLocal()
    }

    function parse(text) {
        try {
            const v = JSON.parse(text)
            return Array.isArray(v) ? v : []
        } catch (e) {
            return []
        }
    }

    function ago(value) {
        const t = typeof value === "number" ? value * 1000 : Date.parse(value)
        if (!t)
            return ""
        const s = Math.max(0, (Date.now() - t) / 1000)
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m ago"
        if (s < 86400) return Math.round(s / 3600) + "h ago"
        if (s < 86400 * 30) return Math.round(s / 86400) + "d ago"
        if (s < 86400 * 365) return Math.round(s / (86400 * 30)) + "mo ago"
        return Math.round(s / (86400 * 365)) + "y ago"
    }

    // The local clone of a GitHub repo, if there is one.
    function localFor(repo) {
        const want = repo.nameWithOwner.toLowerCase()
        return local.find(l => {
            const m = l.remote.toLowerCase().match(/github\.com[:\/](.+?)(\.git)?$/)
            return m && m[1] === want
        }) || null
    }

    // ------------------------------------------------------------- remote --
    Process {
        id: authCheck
        command: ["bash", "-c", "gh api user --jq .login 2>/dev/null || echo '!'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.checked = true
                root.authed = t !== "" && t !== "!"
                root.login = root.authed ? t : ""
                if (root.authed)
                    root.loadRemote()
            }
        }
    }

    function loadRemote() {
        remoteLoading = 4
        reposProc.running = true
        myPrsProc.running = true
        reviewProc.running = true
        issuesProc.running = true
    }

    Process {
        id: reposProc
        command: ["gh", "repo", "list", "--limit", "200", "--json",
                  "name,nameWithOwner,description,visibility,primaryLanguage,stargazerCount,pushedAt,url,isFork"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.repos = root.parse(text).sort((a, b) => (b.pushedAt || "").localeCompare(a.pushedAt || ""))
                root.remoteLoading--
            }
        }
    }

    Process {
        id: myPrsProc
        command: ["gh", "search", "prs", "--author=@me", "--state=open", "--limit", "50",
                  "--json", "number,title,url,repository,updatedAt,isDraft"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.myPrs = root.parse(text)
                root.remoteLoading--
            }
        }
    }

    Process {
        id: reviewProc
        command: ["gh", "search", "prs", "--review-requested=@me", "--state=open", "--limit", "50",
                  "--json", "number,title,url,repository,updatedAt"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.reviewPrs = root.parse(text)
                root.remoteLoading--
            }
        }
    }

    Process {
        id: issuesProc
        command: ["gh", "search", "issues", "--assignee=@me", "--state=open", "--limit", "50",
                  "--json", "number,title,url,repository,updatedAt"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.issues = root.parse(text)
                root.remoteLoading--
            }
        }
    }

    // -------------------------------------------------------------- local --
    readonly property string scanScript: `
find "$HOME" -maxdepth 5 \\( -path "$HOME/snap" -o -path "$HOME/.cache" -o -path "$HOME/.local" -o -name node_modules \\) -prune \\
    -o -name .git -prune -print 2>/dev/null |
while IFS= read -r g; do
    d="\${g%/.git}"
    s="$(git -C "$d" status --porcelain=v2 --branch 2>/dev/null)" || continue
    branch="$(printf '%s\\n' "$s" | sed -n 's/^# branch.head //p')"
    ab="$(printf '%s\\n' "$s" | sed -n 's/^# branch.ab //p')"
    up="$(printf '%s\\n' "$s" | grep -c '^# branch.upstream ')"
    changes="$(printf '%s\\n' "$s" | grep -vc '^#')"
    remote="$(git -C "$d" remote get-url origin 2>/dev/null)"
    when="$(git -C "$d" log -1 --format=%ct 2>/dev/null)"
    jq -nc --arg path "$d" --arg branch "$branch" --arg ab "$ab" --arg remote "$remote" \\
        --argjson up "$up" --argjson changes "$changes" --argjson when "\${when:-0}" \\
        '($ab | if . == "" then "+0 -0" else . end | split(" ")) as $p
         | {path: $path, name: ($path | split("/") | last), branch: $branch,
            ahead: ($p[0] | ltrimstr("+") | tonumber), behind: ($p[1] | ltrimstr("-") | tonumber),
            upstream: ($up > 0), changes: $changes, remote: $remote, when: $when}'
done | jq -sc 'sort_by(-.when)'
`

    function scanLocal() {
        if (localScan.running)
            return
        localLoading = true
        localScan.running = true
    }

    Process {
        id: localScan
        command: ["bash", "-c", root.scanScript]
        stdout: StdioCollector {
            onStreamFinished: {
                root.local = root.parse(text)
                root.localLoading = false
            }
        }
    }

    // ------------------------------------------------------------ actions --
    function run(target, label, command, reloadRemote) {
        if (action.running)
            return
        busy = target
        action.label = label
        action.reloadRemote = reloadRemote
        action.command = command
        action.running = true
    }

    function pull(repo) {
        run(repo.path, "Pull " + repo.name, ["git", "-C", repo.path, "pull", "--ff-only"], false)
    }

    function push(repo) {
        run(repo.path, "Push " + repo.name, ["git", "-C", repo.path, "push"], false)
    }

    function fetchAll() {
        run("*", "Fetch all", ["bash", "-c",
            'for d in "$@"; do git -C "$d" fetch --all --prune --quiet || echo "could not fetch $d" >&2; done', "_"]
            .concat(local.map(r => r.path)), false)
    }

    function clone(repo) {
        run(repo.nameWithOwner, "Clone " + repo.name, ["bash", "-c",
            'mkdir -p "$1" && cd "$1" && gh repo clone "$2"', "_", cloneDir, repo.nameWithOwner], false)
    }

    // visibility: private | public
    function publish(repo, visibility) {
        run(repo.path, "Publish " + repo.name, ["gh", "repo", "create", repo.name, "--" + visibility,
            "--source", repo.path, "--remote", "origin", "--push"], true)
    }

    Process {
        id: action
        property string label: ""
        property bool reloadRemote: false
        stderr: StdioCollector {
            id: actionErrors
        }
        onExited: code => {
            const lines = actionErrors.text.trim().split("\n").filter(l => l)
            Quickshell.execDetached(["notify-send", "-a", "GitHub", "-i", code === 0 ? "vcs-normal" : "dialog-warning",
                code === 0 ? label + " - done" : label + " - failed",
                code === 0 ? "" : (lines[lines.length - 1] || "exit code " + code)])
            root.busy = ""
            root.scanLocal()
            if (reloadRemote || label.startsWith("Clone"))
                root.loadRemote()
        }
    }
}
