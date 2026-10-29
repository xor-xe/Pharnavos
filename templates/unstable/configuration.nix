{ pkgs, user, ... }:

{
  imports = [ ./hardware-configuration.nix ];   # nixos-generate-config writes this

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "pharnavos";
  time.timeZone = "Asia/Tbilisi";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };

  # Hyprland, PipeWire, NetworkManager, Bluetooth, power profiles, hyprlock
  programs.pharnavos.enable = true;

  # a local LLM for the launcher's AI (see programs.pharnavos.ai in home.nix); downloads the models
  # on first start. For a GPU: package = pkgs.ollama-cuda (NVIDIA) or pkgs.ollama-rocm (AMD).
  # programs.pharnavos.ai.ollama = {
  #   enable = true;
  #   models = [ "llama3.2:3b" ];
  # };

  # log in on tty1 and Hyprland starts
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [ git ];

  system.stateVersion = "26.05";   # the release you first installed; leave it as it is afterwards
}
