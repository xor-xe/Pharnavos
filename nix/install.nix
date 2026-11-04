self:
{ config, lib, user, nvidia, apps, ... }:

# What `nix run github:xor-xe/Pharnavos#install` adds on top of an existing NixOS (KDE, GNOME…):
# the system's own configuration.nix stays in charge, Pharnavos and home-manager come on top.
let
  layout = config.services.xserver.xkb.layout;
in
{
  imports = [ self.nixosModules.default self.inputs.home-manager.nixosModules.home-manager ];

  programs.pharnavos.enable = true;
  # apps from the launcher, kept in /etc/nixos/apps.json. Off: programs.pharnavos.apps.flake = null;
  # in configuration.nix (apps installed so far stay)
  programs.pharnavos.apps = lib.mkIf (apps != null) { flake = lib.mkDefault "/etc/nixos"; list = lib.mkDefault apps; };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # log in to Pharnavos by default; the old desktop stays one click away on the login screen.
  # (Plasma and GNOME set theirs with mkDefault: this one is just a little stronger.)
  services.displayManager.defaultSession = lib.mkOverride 900 "hyprland";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "pre-pharnavos";   # the user's own dotfiles are moved aside, never lost
    extraSpecialArgs = { inherit user; };
    users.${user} = {
      imports = [ self.homeModules.default ../templates/default/home.nix ];
      # only in Hyprland: a KDE or GNOME session keeps its own panel
      wayland.systemd.target = "hyprland-session.target";
      # the keyboard picked in the installer, with Georgian next to it
      wayland.windowManager.hyprland.settings.input.kb_layout =
        lib.mkForce (if lib.hasInfix "ge" layout then layout else "${layout},ge");
    };
  };

  # NVIDIA: Hyprland needs the proprietary driver. The open kernel module for Turing (RTX 20,
  # GTX 16) and newer, the closed one before that.
  hardware.nvidia = lib.mkIf (nvidia != null) {
    modesetting.enable = true;
    open = nvidia == "open";
  };
  services.xserver.videoDrivers = lib.mkIf (nvidia != null) [ "nvidia" ];
  programs.pharnavos.unfree = lib.mkIf (nvidia != null) [ "nvidia" ];
}
