# System Menu

A BIOS-style terminal launcher for Linux. Define groups of shell commands in a config file and run them from a keyboard-driven TUI — no mouse required.

## Features

- Award BIOS color scheme (blue background, cyan highlights)
- Groups and actions loaded from a plain-text config file
- Command output streams in a full-screen blue terminal frame with exit code reporting
- Optional sudo pre-authentication at startup (keeps sudo alive for the session)
- GNOME desktop launcher included

## Screenshots

**Main menu** — select a group:

```text
SYSTEM MENU v1.0  ──  config.conf  ──  ↑↓:Move  ENTER:Select  ESC:Exit

 ┌────────────────────── SYSTEM MENU  v1.0 ───────────────────────┐
 │                                                                  │
 │  Select a group:                                                 │
 │                                                                  │
 │     MongoDB                              [6 actions]            │
 │     Nginx                                [5 actions]            │
 │     System                               [5 actions]            │
 │                                                                  │
 │                  <Select>          <Cancel>                      │
 └──────────────────────────────────────────────────────────────────┘
```

**Group menu** — select an action:

```text
SYSTEM MENU v1.0  ──  config.conf  ──  ↑↓:Move  ENTER:Select  ESC:Back

 ┌───────────────────────── MongoDB ──────────────────────────────┐
 │                                                                 │
 │  Select an action:                                              │
 │                                                                 │
 │   1  Start MongoDB    [sudo systemctl start mongod]            │
 │   2  Check Status     [sudo systemctl status mongod]           │
 │   3  Stop MongoDB     [sudo systemctl stop mongod]             │
 │   4  Restart MongoDB  [sudo systemctl restart mongod]          │
 │   5  Enable on Boot   [sudo systemctl enable mongod]           │
 │   6  Disable on Boot  [sudo systemctl disable mongod]          │
 │                                                                 │
 │                  <Select>          <Cancel>                     │
 └─────────────────────────────────────────────────────────────────┘
```

**Command output** — full-screen BIOS-style frame:

```text
╔══════════════════════════════════════════════════════════════════╗
║  SYSTEM MENU  v1.0                                               ║
╠──────────────────────────────────────────────────────────────────╣
║  MongoDB  >>  Check Status                                       ║
║  $ sudo systemctl status mongod                                  ║
╠══════════════════════════════════════════════════════════════════╣

  │ ● mongod.service - MongoDB Database Server
  │      Loaded: loaded (/lib/systemd/system/mongod.service)
  │      Active: active (running) since Wed 2026-03-05 08:00:01
  │    Main PID: 1234 (mongod)
  │      CGroup: /system.slice/mongod.service
  │              └─1234 /usr/bin/mongod --config /etc/mongod.conf

╠──────────────────────────────────────────────────────────────────╣
║  [OK]  Exit code: 0                                              ║
╠══════════════════════════════════════════════════════════════════╣
║  Press any key to return to menu...                              ║
╚══════════════════════════════════════════════════════════════════╝
```

## Requirements

- `bash`
- `whiptail` (`sudo apt install whiptail`)
- Linux / GNOME desktop (for the `.desktop` launcher)

## Usage

```bash
bash systemmenu.sh
```

Or set a custom config path:

```bash
CONFIG_FILE=/path/to/myconfig.conf bash systemmenu.sh
```

Navigate with arrow keys, select with Enter, go back with Esc.

## Config Format

```
# config.conf

GROUP=<Group Name>
ACTION=<Button Label>|<shell command>
```

Blank lines and `#` comments are ignored. Example:

```
GROUP=MongoDB
ACTION=Start MongoDB|sudo systemctl start mongod
ACTION=Check Status|sudo systemctl status mongod
ACTION=Stop MongoDB|sudo systemctl stop mongod

GROUP=System
ACTION=Disk Usage|df -h
ACTION=Memory Usage|free -h
ACTION=System Uptime|uptime
```

## Desktop Launcher

To add System Menu to your GNOME applications:

```bash
cp systemmenu.desktop ~/.local/share/applications/
cp systemmenu.desktop ~/Desktop/
```

You may need to right-click the desktop icon and choose **Allow Launching** the first time.

## Files

| File | Description |
|------|-------------|
| `systemmenu.sh` | Main script |
| `config.conf` | Groups and actions config |
| `systemmenu.desktop` | GNOME desktop launcher |
