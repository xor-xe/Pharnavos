self:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.pharnavos;
  inherit (lib) mkOption mkEnableOption mkIf mkDefault types;
  bin = "${cfg.package}/bin";
  env = lib.filterAttrs (_: v: v != null) {
    PHARNAVOS_NAME = cfg.name;
    PHARNAVOS_TERMINAL = cfg.terminal;
    PHARNAVOS_LANG = cfg.language;
    PHARNAVOS_POWER = if cfg.powerProfiles then null else "0";
    PHARNAVOS_DANCE = if cfg.wallpaper.dance == null then null else "${cfg.wallpaper.dance}";
    PHARNAVOS_FONT_HEADING = if cfg.fonts.heading == null then null else "${cfg.fonts.heading}";
    PHARNAVOS_FONT_LABEL = if cfg.fonts.label == null then null else "${cfg.fonts.label}";
  } // lib.optionalAttrs cfg.ai.enable (lib.filterAttrs (_: v: v != null) {
    PHARNAVOS_AI_API = cfg.ai.api;
    PHARNAVOS_AI_URL = cfg.ai.url;
    PHARNAVOS_AI_MODEL = cfg.ai.model;
    PHARNAVOS_AI_TRANSLATE_MODEL = cfg.ai.translateModel;
    PHARNAVOS_AI_KEY_FILE = cfg.ai.apiKeyFile;
  });

  # hypridle starts the lock outside the shell's service, so it needs the same environment
  # (language, name, fonts) or the lock screen would ignore those options
  lockCommand = toString (pkgs.writeShellScript "pharnavos-lock" ''
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}\n") env)}exec ${bin}/pharnavos-lock "$@"
  '');

  isLua = (config.wayland.windowManager.hyprland.configType or "hyprlang") == "lua";
  dpms = state: if isLua then "hyprctl dispatch 'hl.dsp.dpms({ action = \"${state}\" })'" else "hyprctl dispatch dpms ${state}";
  launcherCmd = "${bin}/pharnavos ipc call launcher toggle";
  wallCmd = dir: "${bin}/pharnavos ipc call wall ${dir}";
  # Super+W -> Super+Shift+W: the previous wallpaper
  shifted = combo: let p = lib.splitString "," combo; in "${builtins.head p} SHIFT,${lib.last p}";

  hyprlangSettings = {
    bind = [
      "${cfg.hyprland.launcherKey}, exec, ${launcherCmd}"
      "${cfg.hyprland.wallpaperKey}, exec, ${wallCmd "next"}"
      "${shifted cfg.hyprland.wallpaperKey}, exec, ${wallCmd "prev"}"
      "${cfg.hyprland.lockKey}, exec, ${lockCommand}"
    ];
    general = {
      border_size = mkDefault 2;
      gaps_in = mkDefault 6;
      gaps_out = mkDefault 12;
      "col.active_border" = mkDefault "rgba(ff3b3bff) rgba(ede6daff) rgba(ff3b3bff) 45deg";
      "col.inactive_border" = mkDefault "rgba(2a2226cc)";
    };
    decoration = {
      rounding = mkDefault 12;
      dim_inactive = mkDefault true;
      dim_strength = mkDefault 0.12;
      shadow = {
        enabled = mkDefault true;
        range = mkDefault 18;
        render_power = mkDefault 3;
        color = mkDefault "rgba(ff3b3b55)";
        color_inactive = mkDefault "rgba(00000000)";
      };
    };
    bezier = [ "pharnavosQuick, 0.15, 0, 0.1, 1" "pharnavosLinear, 0, 0, 1, 1" ];
    animation = [
      "windows, 1, 3, pharnavosQuick, popin 80%"
      "workspaces, 1, 4, pharnavosQuick, slide"
      "borderangle, 1, 400, pharnavosLinear, loop"
    ];
    # the close effect (falling letters) must appear at once
    layerrule = [ "no_anim on, match:namespace ^(pharnavos-close)$" ];
    # if the lock screen crashes, stay locked and let pharnavos-lock fall back to hyprlock
    misc.allow_session_lock_restore = true;
  };

  # the same in home-manager's Lua form: each attribute becomes hl.<name>(…)
  luaKey = combo:   # "SUPER SHIFT, R" -> "SUPER + SHIFT + R"
    let
      parts = lib.splitString "," combo;
      mods = builtins.filter (m: m != "") (lib.splitString " " (lib.trim (builtins.head parts)));
    in
    lib.concatStringsSep " + " (mods ++ [ (lib.trim (lib.last parts)) ]);
  luaSettings = {
    bind = map (b: { _args = [ (luaKey (builtins.head b)) (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${builtins.toJSON (lib.last b)})") ]; }) [
      [ cfg.hyprland.launcherKey launcherCmd ]
      [ cfg.hyprland.wallpaperKey (wallCmd "next") ]
      [ (shifted cfg.hyprland.wallpaperKey) (wallCmd "prev") ]
      [ cfg.hyprland.lockKey lockCommand ]
    ];
    config = {
      general = {
        border_size = mkDefault 2;
        gaps_in = mkDefault 6;
        gaps_out = mkDefault 12;
        col = {
          active_border = mkDefault { colors = [ "rgba(ff3b3bff)" "rgba(ede6daff)" "rgba(ff3b3bff)" ]; angle = 45; };
          inactive_border = mkDefault "rgba(2a2226cc)";
        };
      };
      decoration = {
        rounding = mkDefault 12;
        dim_inactive = mkDefault true;
        dim_strength = mkDefault 0.12;
        shadow = {
          enabled = mkDefault true;
          range = mkDefault 18;
          render_power = mkDefault 3;
          color = mkDefault "rgba(ff3b3b55)";
          color_inactive = mkDefault "rgba(00000000)";
        };
      };
      misc.allow_session_lock_restore = true;
    };
    curve = [
      { _args = [ "pharnavosQuick" { type = "bezier"; points = [ [ 0.15 0 ] [ 0.1 1 ] ]; } ]; }
      { _args = [ "pharnavosLinear" { type = "bezier"; points = [ [ 0 0 ] [ 1 1 ] ]; } ]; }
    ];
    animation = [
      { leaf = "windows"; enabled = true; speed = 3; bezier = "pharnavosQuick"; style = "popin 80%"; }
      { leaf = "workspaces"; enabled = true; speed = 4; bezier = "pharnavosQuick"; style = "slide"; }
      # Lua caps speed at 100 (hyprlang accepted 400: a slower turn)
      { leaf = "borderangle"; enabled = true; speed = 100; bezier = "pharnavosLinear"; style = "loop"; }
    ];
    layer_rule = [{ name = "pharnavos-close"; match.namespace = "^(pharnavos-close)$"; no_anim = true; }];
  };
in
{
  options.programs.pharnavos = {
    enable = mkEnableOption "Pharnavos, a Georgian desktop shell for Hyprland";

    package = mkOption {
      type = types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The Pharnavos package.";
    };

    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "ხორხე";
      description = "Name in the greetings (control centre, lock screen). Default: your login name.";
    };

    language = mkOption {
      type = types.enum [ "ka" "en" ];
      default = "ka";
      description = "Language of the shell: `ka` (Georgian) or `en` (English). Also switchable in the control centre.";
    };

    lockCommand = mkOption {
      type = types.str;
      readOnly = true;
      description = "Command that locks the screen with Pharnavos, carrying its settings; use it in your own hypridle config (`lock_cmd`).";
    };

    powerProfiles = mkOption {
      type = types.bool;
      default = true;
      description = "Show the power-profile gauge on the bar (needs power-profiles-daemon: the NixOS option of the same name). Hidden on its own when no daemon answers.";
    };

    wallpaper.dance = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = lib.literalExpression "./dance";
      description = ''
        Adds a Dance wallpaper: Georgian letters flipping on the lines of a dancer, frame by frame.
        A directory with `dance.png` (one tile per frame, white = line, on a grid of letter cells) and
        `dance.json` (`frames`, `cols`, `rows`, `perRow`, `fps`). Make your own from a video; keep
        footage you don't own the rights to out of public repositories.
      '';
    };

    terminal = mkOption {
      type = types.str;
      default = "foot";
      description = "Terminal for the launcher's `>` (run a command). Must accept `-e`.";
    };

    fonts = {
      heading = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Your own .ttf/.otf for headings (default: FiraGO Heavy Italic).";
      };
      label = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Your own .ttf/.otf for labels (default: BPG Excelsior Caps).";
      };
    };

    ai = {
      enable = mkEnableOption ''
        AI in the launcher: `?` asks a model, `#` translates Georgian ⇄ English. Off by default.
        Needs a model server: a local ollama (the NixOS option `programs.pharnavos.ai.ollama.enable`
        installs one) or any OpenAI-compatible server'';
      api = mkOption {
        type = types.enum [ "ollama" "openai" ];
        default = "ollama";
        description = "`ollama`, or `openai` for any OpenAI-compatible server (LM Studio, llama.cpp, vLLM, OpenRouter, OpenAI…).";
      };
      url = mkOption {
        type = types.str;
        default = "http://localhost:11434";
        example = "http://localhost:1234/v1";
        description = "Server address. For `openai`, the base URL including `/v1`.";
      };
      model = mkOption {
        type = types.str;
        default = "llama3.2:3b";
        description = "Model for `?` (and for `#` unless translateModel is set).";
      };
      translateModel = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "translategemma:27b";
        description = "Model for `#`. Default: the same as `model`.";
      };
      apiKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/secrets/openrouter";
        description = "File holding an API key (for hosted servers). Read only when you ask; keep it out of the Nix store, so give a path as a string.";
      };
    };

    hyprland = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Set up Hyprland for Pharnavos: launcher keybind, the window look (borders, glow, gaps,
          animations; all overridable, they are defaults), the close-effect layer rule and lock
          screen crash recovery. Needs `wayland.windowManager.hyprland.enable`.
        '';
      };
      launcherKey = mkOption {
        type = types.str;
        default = "SUPER, R";
        description = "Hyprland key combo that opens the launcher.";
      };
      wallpaperKey = mkOption {
        type = types.str;
        default = "SUPER, W";
        description = "Hyprland key combo that switches to the next wallpaper (with Shift: the previous one).";
      };
      lockKey = mkOption {
        type = types.str;
        default = "SUPER, L";
        description = "Hyprland key combo that locks the screen.";
      };
    };

    lock = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Lock with Pharnavos's lock screen via hypridle (idle, `loginctl lock-session`, before sleep).";
      };
      idleMinutes = mkOption { type = types.ints.positive; default = 15; description = "Lock after this long idle."; };
      screenOffMinutes = mkOption { type = types.ints.positive; default = 20; description = "Turn screens off after this long idle."; };
    };
  };

  config = mkIf cfg.enable {
    programs.pharnavos.lockCommand = lockCommand;

    # Pharnavos is the notification daemon, the bar and the wallpaper: a second one would run beside it
    # (two bars, or two wallpapers fighting over the background). `or false`: not every option exists
    # in every home-manager release.
    assertions = [
      {
        assertion = !(config.services.mako.enable || config.services.dunst.enable || config.services.swaync.enable);
        message = "programs.pharnavos is your notification daemon: disable services.mako / services.dunst / services.swaync.";
      }
      {
        assertion = !builtins.any (o: o) [ (config.programs.waybar.enable or false) (config.programs.eww.enable or false) (config.programs.hyprpanel.enable or false) ];
        message = "programs.pharnavos is your bar: disable programs.waybar / programs.eww / programs.hyprpanel.";
      }
      {
        assertion = !builtins.any (o: o) [ (config.services.swww.enable or false) (config.services.awww.enable or false) (config.services.hyprpaper.enable or false) (config.services.wpaperd.enable or false) ];
        message = "programs.pharnavos draws the wallpaper: disable services.swww / services.awww / services.hyprpaper / services.wpaperd.";
      }
    ];
    # the same programs started from Hyprland's autostart can't be asserted on, only spotted by name
    warnings = let
      hypr = config.wayland.windowManager.hyprland;
      text = builtins.toJSON hypr.settings + (hypr.extraConfig or "");
      found = builtins.filter (n: lib.hasInfix n text) [ "swww" "awww" "hyprpaper" "swaybg" "wpaperd" "mpvpaper" "waybar" "eww " "hyprpanel" "mako" "dunst" "swaync" ];
    in lib.optional (found != [ ]) "programs.pharnavos: Hyprland's autostart mentions ${lib.concatStringsSep ", " found}; Pharnavos already is the bar, wallpaper and notification daemon, so remove it to avoid running two.";

    home.packages = [ cfg.package pkgs.noto-fonts pkgs.nerd-fonts.fira-code ];
    fonts.fontconfig.enable = true;

    systemd.user.services.pharnavos = {
      Unit = {
        Description = "Pharnavos desktop shell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
      };
      Service = {
        ExecStart = "${bin}/pharnavos";
        Restart = "on-failure";
        Environment = lib.mapAttrsToList (k: v: "${k}=${v}") env;
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    # Hyprland 0.55 reads hyprlang, 0.56+ only Lua: same look, written in whichever format is in use
    wayland.windowManager.hyprland.settings = mkIf cfg.hyprland.enable (if isLua then luaSettings else hyprlangSettings);

    services.hypridle = mkIf cfg.lock.enable {
      enable = true;
      settings = mkDefault {
        general = {
          lock_cmd = lockCommand;
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = dpms "on";
        };
        listener = [
          { timeout = cfg.lock.idleMinutes * 60; on-timeout = "loginctl lock-session"; }
          { timeout = cfg.lock.screenOffMinutes * 60; on-timeout = dpms "off"; on-resume = dpms "on"; }
        ];
      };
    };
  };
}
