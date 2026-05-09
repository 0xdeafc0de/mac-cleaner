# 🍎 mac_clean.sh

> An interactive, zero-dependency Mac disk scanner and cleaner for your terminal.

![macOS](https://img.shields.io/badge/macOS-10.15%2B-black?logo=apple)
![Shell](https://img.shields.io/badge/shell-bash-blue?logo=gnubash)
![License](https://img.shields.io/badge/license-MIT-green)
![Dependencies](https://img.shields.io/badge/dependencies-none-brightgreen)

---

## What it does

`mac_clean.sh` scans your home directory and gives you a full picture of where your disk space is going — then lets you interactively select and run cleanup actions, with a **safe dry-run mode by default**.

```
  ╔══════════════════════════════════════════════════════════╗
  ║          🍎  Mac Disk Scanner & Cleaner                  ║
  ║          Works on any macOS · No dependencies            ║
  ╚══════════════════════════════════════════════════════════╝
```

### Scan Sections

| Section | What it shows |
|---|---|
| **Disk Overview** | Usage bar, used / free / total |
| **Top Home Dirs** | Colour-coded by size |
| **Library Breakdown** | Caches, App Support, Containers, Logs — top 10 per category |
| **Developer Space** | `node_modules`, git repos, Go / pip / Homebrew caches |
| **Docker** | `docker system df` output (skipped if Docker not running) |
| **Large Files** | Files > 100 MB (searched up to depth 6) |
| **Downloads** | All files sorted by size |
| **Trash** | Item count and total size |

### Cleanup Menu

After the scan, an interactive menu lists every available cleanup action with:

- 📦 **Estimated size** saved
- 🟢 🟡 🔴 **Risk level** (LOW / MED / HIGH)
- The **exact command** that will run — no surprises

```
  ◆ Cleanup Menu  [DRY-RUN — preview only, nothing executed]
  ────────────────────────────────────────────────────────
  ID    Action                                  Est.Size  Risk
  ────────────────────────────────────────────────────────
  [ 1]  Clear ALL ~/Library/Caches              7.5G      LOW
  [ 2]  Homebrew cleanup (--prune=all)          828M      LOW
  [ 3]  Go build cache (go clean -cache)        651M      LOW
  [ 4]  Go module cache (go clean -modcache)    845M      MED
  [ 5]  pip cache purge                          75M      LOW
  [ 6]  Clear ~/Library/Logs                    113M      LOW
  [ 7]  Empty Trash                               0B      LOW
  [ 8]  Docker: prune containers + networks    varies     LOW
  [ 9]  Docker: remove ALL unused images       varies     MED
  [10]  Docker: remove unused volumes          varies     HIGH
  [11]  Docker: remove ALL build cache         varies     LOW
  [12]  Remove node_modules in ~/ws (≤4 deep)  varies     HIGH

  [a]  Run ALL low-risk items (risk=LOW only)
  [t]  Toggle DRY-RUN / LIVE mode
  [q]  Quit
```

---

## Install

No installation required. Just download and make it executable:

```bash
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/mac-cleaner/main/mac_clean.sh
chmod +x mac_clean.sh
```

Or clone the repo:

```bash
git clone https://github.com/YOUR_USERNAME/mac-cleaner.git
cd mac-cleaner
chmod +x mac_clean.sh
```

Optionally put it on your PATH:

```bash
sudo cp mac_clean.sh /usr/local/bin/mac_clean
```

---

## Usage

```bash
# Safe mode (default) — scan and preview commands, nothing is executed
./mac_clean.sh

# Live mode — scan and actually execute selected cleanup commands
./mac_clean.sh --live

# Help
./mac_clean.sh --help
```

### In the interactive menu

| Input | Action |
|---|---|
| `1`–`N` | Preview / run that specific action |
| `a` | Run all **LOW**-risk items at once |
| `t` | Toggle between dry-run and live mode |
| `q` | Quit |

> **HIGH-risk actions** (e.g. Docker volume prune, removing `node_modules`) require an extra `yes` confirmation even in live mode.

---

## Safety

- **Dry-run by default.** Without `--live`, the script prints exactly what would run but does nothing.
- **Risk labels.** Every action is tagged LOW / MED / HIGH so you know what you're doing.
- **No sudo required.** The script only touches your user home directory and app caches.
- **Nothing is auto-deleted.** You must explicitly select items or pass `--live` and confirm.

---

## Requirements

- macOS 10.15 (Catalina) or later
- `bash` 3.2+ (pre-installed on all Macs)
- No external tools required — uses only standard macOS utilities (`du`, `find`, `df`, `bc`)
- Optional: `docker`, `brew`, `go`, `pip` — detected automatically, skipped if absent

---

## What gets cleaned (and risk levels)

| Action | Risk | Notes |
|---|---|---|
| `~/Library/Caches` | 🟢 LOW | macOS rebuilds automatically |
| `~/Library/Logs` | 🟢 LOW | Safe to delete |
| Homebrew cache | 🟢 LOW | `brew cleanup --prune=all` |
| Go build cache | 🟢 LOW | Rebuilt on next `go build` |
| pip cache | 🟢 LOW | Rebuilt on next install |
| Trash | 🟢 LOW | Standard empty trash |
| Docker system prune | 🟢 LOW | Removes stopped containers + dangling images |
| Go module cache | 🟡 MED | Re-fetched from internet on next build |
| Docker unused images | 🟡 MED | Can re-pull from registry |
| `node_modules` dirs | 🔴 HIGH | Run `npm install` to restore |
| Docker volumes | 🔴 HIGH | May contain persistent data |
| Xcode DerivedData | 🟢 LOW | Rebuilt by Xcode automatically |
| Xcode iOS DeviceSupport | 🟡 MED | Old SDK files, re-downloaded if needed |

---

## Contributing

PRs welcome! Some ideas for contributions:

- [ ] Add Xcode Simulator cleanup
- [ ] Add `~/.npm` cache section
- [ ] Add Python `__pycache__` finder
- [ ] Add old VS Code extension version cleanup
- [ ] Add `~/.cache/huggingface` section for ML users
- [ ] HTML report export (`--report`)

---

## License

MIT — use it, fork it, share it.
