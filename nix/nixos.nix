{ config, lib, pkgs, ... }:

# System services Pharnavos talks to. Everything is a default, so your own settings win.
let
  cfg = config.programs.pharnavos;
  inherit (lib) mkDefault mkEnableOption mkIf mkMerge mkOption types;
in
{
  options.programs.pharnavos = {
    enable = mkEnableOption "the system services Pharnavos needs (Hyprland, PipeWire, NetworkManager, Bluetooth, power profiles, hyprlock)";

    powerProfiles = mkOption {
      type = types.bool;
      default = true;
      description = "Turn on power-profiles-daemon for the bar's power gauge. Off: leave power management to your own setup (TLP, auto-cpufreq…); set the home-manager option of the same name to false too.";
    };

    # off unless set: the one-command installer sets it for /etc/nixos
    apps = {
      flake = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/home/you/dotfiles";
        description = ''
          Your system flake's directory. Set it, with `list`, to install, remove and update apps from the
          launcher ("install vlc", "update"). The launcher writes `apps.json` there and rebuilds with
          `nixos-rebuild switch --flake <flake>#<host>`; commit the file yourself.
        '';
      };
      list = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = lib.literalExpression "./apps.json";
        description = "`apps.json` at the root of that flake (start it as `[]` and git add it): the apps the launcher installed.";
      };
      host = mkOption {
        type = types.str;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = "The flake's `nixosConfigurations` entry for this machine.";
      };
      update = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "nixpkgs" "nixpkgs-unstable" ];
        description = "Flake inputs \"update\" in the launcher refreshes. Empty: all of them.";
      };
    };

    # name prefixes of unfree packages to allow (apps from the launcher, NVIDIA from the installer)
    unfree = mkOption { type = types.listOf types.str; default = [ ]; internal = true; };

    ai.ollama = {
      enable = mkEnableOption ''
        a local ollama server for the launcher's AI (`programs.pharnavos.ai` in home-manager).
        Installs ollama as a system service and downloads the models below on first start
        (a few GB). Runs on the CPU unless you pick a GPU package'';
      models = mkOption {
        type = types.listOf types.str;
        default = [ "llama3.2:3b" ];
        description = "Models to download (see ollama.com/library).";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.ollama;
        defaultText = lib.literalExpression "pkgs.ollama";
        example = lib.literalExpression "pkgs.ollama-cuda";
        description = "`pkgs.ollama-cuda` for NVIDIA, `pkgs.ollama-rocm` for AMD, `pkgs.ollama` (CPU) otherwise.";
      };
    };
  };

  config = mkMerge [
    (mkIf (cfg.apps.list != null) (let
      wanted = builtins.fromJSON (builtins.readFile cfg.apps.list);
    in {
      environment.systemPackages = map (a: lib.getAttrFromPath (lib.splitString "." a.name) pkgs) wanted;
      # ponytail: unfree apps are allowed by name prefix (steam → steam-unwrapped too), since pkgs can't
      # be read inside nixpkgs.config; an app whose dependencies are named otherwise needs allowUnfree
      programs.pharnavos.unfree = map (a: lib.last (lib.splitString "." a.name)) (lib.filter (a: a.unfree or false) wanted);
    }))
    # where pharnavos-apps (as root) finds the flake: from the system, never from the caller
    (mkIf (cfg.apps.flake != null) {
      environment.etc."pharnavos/apps".text = ''
        flake=${cfg.apps.flake}
        host=${cfg.apps.host}
        update=${lib.concatStringsSep " " cfg.apps.update}
      '';
    })
    (mkIf (cfg.unfree != [ ]) {
      nixpkgs.config.allowUnfreePredicate = p: lib.any (n: lib.hasPrefix n (lib.getName p)) cfg.unfree;
    })
    (mkIf cfg.ai.ollama.enable {
      services.ollama = {
        enable = true;
        inherit (cfg.ai.ollama) package;
        loadModels = cfg.ai.ollama.models;
      };
    })
    (mkIf cfg.enable {
      programs.hyprland.enable = mkDefault true;
      programs.hyprlock.enable = mkDefault true;          # fallback lock screen (and its PAM entry)
      services.pipewire = {
        enable = mkDefault true;
        pulse.enable = mkDefault true;
      };
      networking.networkmanager.enable = mkDefault true;  # Wi-Fi seal
      hardware.bluetooth.enable = mkDefault true;         # Bluetooth seal
      services.blueman.enable = mkDefault true;           # blueman-manager, opened from the bar
      services.upower.enable = mkDefault true;            # battery qvevri on laptops
      services.power-profiles-daemon.enable = mkIf cfg.powerProfiles (mkDefault true);
    })
  ];
}
