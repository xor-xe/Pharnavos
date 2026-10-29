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
      services.power-profiles-daemon.enable = mkIf cfg.powerProfiles (mkDefault true);
    })
  ];
}
