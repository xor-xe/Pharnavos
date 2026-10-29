<div align="center">

<img src="shell/assets/cutouts/borjgali-collage.png" width="150" alt="Borjgali">

# Pharnavos

*The least patriotic Georgian rice*

**A Georgian desktop shell for Hyprland, built on Quickshell and packaged for NixOS.**

[ქართული](README.md) · **English**

<a href="https://nixos.org"><img src="https://img.shields.io/badge/NixOS-flake-FF2A3A?style=for-the-badge&logo=nixos&logoColor=EDE6DA&labelColor=0B090A" alt="NixOS flake"></a>
<a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-0.55%20·%200.56-FF2A3A?style=for-the-badge&logo=hyprland&logoColor=EDE6DA&labelColor=0B090A" alt="Hyprland"></a>
<a href="https://quickshell.org"><img src="https://img.shields.io/badge/Quickshell-0.3-FF2A3A?style=for-the-badge&logo=qt&logoColor=EDE6DA&labelColor=0B090A" alt="Quickshell"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-FF2A3A?style=for-the-badge&labelColor=0B090A" alt="GPL-3.0"></a>

[Showcase](#showcase) · [What's inside](#whats-inside) · [Install](#install) · [Shortcuts](#shortcuts) · [Make it yours](#make-it-yours) · [Credits](#credits-and-licence)

</div>

## Showcase

<div align="center">
  <a href="docs/showcase.mp4"><img src="docs/showcase.webp" alt="Pharnavos: lock screens, wallpapers, control centre and launcher" width="100%"></a>
  <br><sub>Lock screens, the three wallpapers, the control centre and the launcher (1.5× speed). Click for the full-quality video.</sub>
</div>

<br>

> **Author's note**
>
> This is my own desktop. I packaged it so anyone can install it, but it is a personal setup, made
> for how I work and what I like to look at. You are encouraged to take it apart and change it to suit
> you: it is free software (GPL-3.0), and nearly everything is a default you can override from your
> own config.

## What's inside

| Part | What it does |
|---|---|
| **Bar** | a half-sunk Borjgali with music rays, cross-stitch workspace diamonds, live Wi-Fi / Bluetooth / volume / power icons |
| **Launcher** | app search with Georgian transliteration, calculator, commands, open windows, web search, optional AI ask and translate |
| **Control centre** | Wi-Fi with password prompt, Bluetooth, sound, calendar, to-do list, power actions, wallpaper and lock-screen settings |
| **Notifications** | embroidered pop-ups and a notification centre with stacks |
| **OSD** | volume as a drinking horn (ყანწი) blowing sound waves; brightness as a sun rising over the horizon |
| **Wallpapers** | Rustaveli's verse along a Borjgali spiral, Vazha-Pshavela's portrait drawn from his poems, and an optional dancer made of flipping letters |
| **Lock screens** | St. George, the five-cross flag or a turning Borjgali, all in flipping Georgian letters |
| **Close effect** | windows fall apart into Georgian letters when they close |

Everything speaks Georgian by default and switches to English in one click; in English the
wallpaper reads Wardrop's Rustaveli and Hewitt's Vazha-Pshavela.

## Install

> [!NOTE]
> You need NixOS with flakes and home-manager. Pharnavos works on **NixOS 26.05** (Hyprland 0.55,
> hyprlang config) and **nixos-unstable** (Hyprland 0.56+, Lua config: set
> `wayland.windowManager.hyprland.configType = "lua";`).

<details>
<summary><b>On a fresh NixOS</b></summary>

<br>

1. Install NixOS 26.05 from the minimal ISO as usual, up to and including
   `nixos-generate-config --root /mnt`.
2. Create your config from the template, next to the generated hardware config:
   ```sh
   cd /mnt/etc/nixos
   nix --extra-experimental-features 'nix-command flakes' flake init -t github:xor-xe/Pharnavos
   ```
   This adds `flake.nix`, `configuration.nix` and `home.nix` and keeps your
   `hardware-configuration.nix`. On **nixos-unstable** use the unstable template instead, the same
   system with every keybind in Lua:
   ```sh
   nix --extra-experimental-features 'nix-command flakes' flake init -t github:xor-xe/Pharnavos#unstable
   ```
3. Edit the placeholders:
   - `flake.nix`: `user = "me";` → your user name
   - `configuration.nix`: host name, time zone, boot loader if you don't use UEFI
   - `home.nix`: your keybinds, monitors, packages
4. Install and reboot:
   ```sh
   nixos-install --flake /mnt/etc/nixos#pharnavos
   nixos-enter --root /mnt -c 'passwd <your-user>'
   reboot
   ```
5. Log in at the greeter; Hyprland starts with Pharnavos. `Super`+`R` opens the launcher, the cross
   on the right of the bar opens the control centre.

Rebuild later with `sudo nixos-rebuild switch --flake /etc/nixos#pharnavos`.

</details>

<details>
<summary><b>Into an existing NixOS flake</b></summary>

<br>

1. Add the input:
   ```nix
   inputs.pharnavos = {
     url = "github:xor-xe/Pharnavos";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
2. System (optional, but turns on what the shell talks to: Hyprland, PipeWire, NetworkManager,
   Bluetooth, power profiles, hyprlock; all as defaults you can override):
   ```nix
   nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
     modules = [ ./configuration.nix pharnavos.nixosModules.default ];
   };
   # configuration.nix
   programs.pharnavos.enable = true;
   ```
3. Home (home-manager as a NixOS module or standalone, same module):
   ```nix
   home-manager.users.<you>.imports = [ pharnavos.homeModules.default ];
   # home.nix
   programs.pharnavos.enable = true;
   wayland.windowManager.hyprland.enable = true;   # Pharnavos adds to your Hyprland config
   ```
4. Rebuild. Pharnavos runs as the systemd user service `pharnavos.service`, started with your
   Hyprland session (`systemctl --user status pharnavos`).

Pharnavos is the bar, the wallpaper and the notification daemon, so the build stops with a clear
message if Waybar, eww, HyprPanel, swww / awww, hyprpaper, wpaperd, mako, dunst or swaync is turned
on, and warns if one of them is started from Hyprland's autostart.

</details>

<details>
<summary><b>What gets installed</b></summary>

<br>

Nothing is installed or changed unless you turn it on:

| You enable | It adds |
|---|---|
| `programs.pharnavos.enable` (home-manager) | the shell (`pharnavos`, `pharnavos-lock`), its runtime tools (Quickshell, cava, nmcli, nm-connection-editor, blueman, powerprofilesctl, curl, pdftotext, hyprlock), Noto and FiraCode fonts, the `pharnavos` user service; Hyprland keybinds + window look + lock-crash recovery (`hyprland.enable`); hypridle idle locking (`lock.enable`) |
| `programs.pharnavos.enable` (NixOS) | Hyprland, PipeWire, NetworkManager, Bluetooth + blueman, power-profiles-daemon (unless `powerProfiles = false`, e.g. you use TLP), hyprlock (all as defaults) |
| `programs.pharnavos.ai.enable` (home-manager) | only the launcher's `?` / `#`; it talks to a model server you choose and installs nothing |
| `programs.pharnavos.ai.ollama.enable` (NixOS) | **ollama** as a system service, and downloads the listed models on first start (**several GB**; a GPU is recommended) |

The template (fresh install) also adds greetd + tuigreet, foot, Firefox, git and kew (a terminal
music player for `~/Music`).

</details>

## Shortcuts

| Keys | Action |
|---|---|
| `Super` + `R` | open / close the launcher |
| `Super` + `W` / `Shift` + `W` | next / previous wallpaper |
| `Super` + `L` | lock the screen |
| `Super` + `Enter` | terminal (foot) |
| `Super` + `Q` | close the window |
| `Super` + `1` … `9` | go to workspace 1–9 (`Shift`: move the window there) |
| `Alt` + `Shift` | switch keyboard layout (English ⇄ Georgian) |

<details>
<summary><b>All shortcuts</b></summary>

<br>

**Hyprland** (`Super` = the Windows key). The launcher, wallpaper and lock keys come from Pharnavos
(`programs.pharnavos.hyprland.launcherKey` / `wallpaperKey` / `lockKey`); the rest are the
templates' binds in `home.nix`, so on an existing config you keep your own.

| Keys | Action |
|---|---|
| `Super` + `R` | open / close the launcher |
| `Super` + `W` / `Shift` + `W` | next / previous wallpaper |
| `Super` + `L` | lock the screen |
| `Super` + `Enter` | terminal (foot) |
| `Super` + `Q` | close the window |
| `Super` + `F` | fullscreen |
| `Super` + `V` | float / tile the window |
| `Super` + `1` … `9` | go to workspace 1–9 |
| `Super` + `Shift` + `1` … `9` | move the window to workspace 1–9 |
| `Super` + left drag / right drag | move / resize a window |
| `Alt` + `Shift` | switch keyboard layout (English ⇄ Georgian) |
| volume keys | volume up / down / mute (shows the volume OSD) |

**Launcher**

| Keys | Action |
|---|---|
| type | search apps (Georgian keyboard input finds Latin names too) |
| `↑` / `↓`, mouse wheel | move the selection |
| `Enter` | launch / run / copy (depends on the mode) |
| `Alt` + `1` … `8` | launch a pinned app |
| `Esc` | clear the text, then close |
| `=` 2+2 | calculator (`Enter` copies the result) |
| `>` command | run a command in a floating terminal |
| `@` name | switch to an open window |
| `!` words | search the web |
| `?` question | ask the AI model (only with `programs.pharnavos.ai`) |
| `#` text | translate Georgian ⇄ English (only with `programs.pharnavos.ai`) |

**Bar, panels, lock screen**

| Where | Action |
|---|---|
| cross (right end of the bar) | control centre; `Esc` closes |
| bell | notification centre; `Esc` closes |
| sun in the middle of the bar | play / pause music |
| `EN` / `KA` badge | switch keyboard layout |
| Wi-Fi icon | arcs = signal (red = offline); hover = download / upload speed; click = network settings |
| Bluetooth icon | red dot = a device connected; hover = devices + battery; click = Bluetooth manager |
| volume icon | click = mute, scroll = volume |
| power gauge | needle = profile (left saver, up balanced, right performance); click = next profile |
| workspace diamonds | click = go to the workspace |
| notification pop-up | click = dismiss, right-click = open it in its app |
| notification in the bell | click = open it, right-click = dismiss (with its stack) |
| control centre: Wi-Fi / Bluetooth | click = open the list, press and hold = turn on / off |
| control centre: to-do list | type + `Enter` adds, right-click deletes |
| lock screen | type the password + `Enter`; `Esc` clears it |

</details>

## Make it yours

Pharnavos is meant to be bent to your taste. Your packages and config stay yours: it is an input to
your flake and never writes to your files.

- **Settings in the control centre.** Language, wallpaper and its text, animation, colours, the red
  background, lock-screen look and clock format are set from the control centre and saved to
  `~/.local/state/pharnavos/settings.json`.
- **The window look is a set of defaults.** Anything you set in
  `wayland.windowManager.hyprland.settings` wins, e.g. `general.border_size = 3;`. Turn the whole
  integration off with `programs.pharnavos.hyprland.enable = false;` and wire it yourself.
- **Hypridle** settings are defaults too: set `services.hypridle.settings` to replace them, or
  `programs.pharnavos.lock.enable = false;`. In your own hypridle config, lock with
  `lock_cmd = config.programs.pharnavos.lockCommand;` so the lock screen gets your language, name
  and fonts.
- **Your own fonts, name and keys** through the options below.
- **Change the shell itself.** It is plain QML in `shell/`. Fork the repository, point your flake
  input at your fork (or at a local clone, `url = "git+file:///home/you/Pharnavos";`) and edit away.

<details>
<summary><b>Options</b></summary>

<br>

```nix
programs.pharnavos = {
  enable = true;
  language = "ka";                 # "ka" (Georgian, default) or "en"; also switchable in the control centre
  name = "ხორხე";                  # greeting name; default: your login name
  terminal = "foot";               # for the launcher's `>` and terminal apps (must accept -e)
  fonts.heading = ./my-font.ttf;   # your own fonts (default FiraGO / BPG Excelsior Caps)
  fonts.label = null;
  powerProfiles = true;            # power gauge on the bar (also a NixOS option: power-profiles-daemon)
  wallpaper.dance = null;          # a folder with dance.png + dance.json: adds the Dance wallpaper
  hyprland.enable = true;          # keybinds, window look, layer rule, lock-crash recovery
  hyprland.launcherKey = "SUPER, R";
  hyprland.wallpaperKey = "SUPER, W";   # with Shift: the previous wallpaper
  hyprland.lockKey = "SUPER, L";
  lock.enable = true;              # hypridle + Pharnavos lock screen
  lock.idleMinutes = 15;
  lock.screenOffMinutes = 20;
};
```

</details>

<details>
<summary><b>AI in the launcher (optional)</b></summary>

<br>

Off by default. When on, the launcher gains `?` (ask a model) and `#` (translate Georgian ⇄
English); when off, those prefixes don't exist.

**Local, with ollama** (nothing leaves your computer). NixOS:

```nix
programs.pharnavos.ai.ollama = {
  enable = true;
  models = [ "llama3.2:3b" ];      # ~2 GB; bigger models answer better and need more memory
  package = pkgs.ollama-cuda;      # NVIDIA; pkgs.ollama-rocm for AMD; pkgs.ollama = CPU only
};
```

home-manager:

```nix
programs.pharnavos.ai = {
  enable = true;
  model = "llama3.2:3b";
  # translateModel = "translategemma:27b";   # optional, a dedicated translation model
};
```

**Any other server** with an OpenAI-compatible API (LM Studio, llama.cpp, vLLM, OpenRouter,
OpenAI, …):

```nix
programs.pharnavos.ai = {
  enable = true;
  api = "openai";
  url = "http://localhost:1234/v1";          # or https://openrouter.ai/api/v1, …
  model = "qwen2.5-7b-instruct";
  apiKeyFile = "/run/secrets/llm-key";       # for hosted APIs; read when you ask, never stored
};
```

</details>

<details>
<summary><b>Updating, versions, locking</b></summary>

<br>

- Update: `nix flake update pharnavos`, then rebuild.
- Pin a release: `url = "github:xor-xe/Pharnavos/v0.1.0";` (tags follow semver; a major bump
  means read the changelog first).
- Roll back: `nixos-rebuild switch --rollback`, or pin the previous tag.

Idle, `loginctl lock-session`, `Super`+`L` and the control centre's lock button all run
`pharnavos-lock`. The lock screen is its own process, so a crash of the shell can't unlock you; if
the lock screen itself dies while locked, Hyprland keeps the session locked
(`misc:allow_session_lock_restore`) and `pharnavos-lock` starts hyprlock instead. If you are ever
stuck on a red "lockscreen dead" screen, switch to a TTY (Ctrl+Alt+F3), log in and run
`hyprctl --instance 0 dispatch exec hyprlock`.

</details>

## Credits and licence

Pharnavos is free software under the **GNU GPL v3 or later** ([LICENSE](LICENSE)). You may use it,
study it, change it and share it, also in changed form. If you share a changed version, keep it
under the GPL and share its source too.

Fonts, texts and images keep their own licences, listed in [CREDITS.md](CREDITS.md) (font licences
in `shell/assets/fonts/licenses/`). Built on [Quickshell](https://quickshell.org) and
[Hyprland](https://hyprland.org).
