self:
{ config, lib, pkgs, user, nvidia, apps, keepDesktop, ... }:

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

  # log in to Pharnavos by default; with keepDesktop the old desktop stays one click away on the login
  # screen. (Plasma and GNOME set theirs with mkDefault: this one is just a little stronger.)
  services.displayManager.defaultSession = lib.mkOverride 900 "hyprland";

  # Pharnavos only: the old desktop and its login screen go, ly takes over, with Pharnavos's red rain
  services.desktopManager.plasma6.enable = lib.mkIf (!keepDesktop) (lib.mkForce false);
  services.desktopManager.gnome.enable = lib.mkIf (!keepDesktop) (lib.mkForce false);
  services.displayManager.sddm.enable = lib.mkIf (!keepDesktop) (lib.mkForce false);
  services.displayManager.gdm.enable = lib.mkIf (!keepDesktop) (lib.mkForce false);
  services.displayManager.ly = lib.mkIf (!keepDesktop) {
    enable = true;
    settings = {
      animation = "matrix";
      cmatrix_fg = "0x00FF3B3B";        # Theme.red
      cmatrix_head_col = "0x01EDE6DA";  # Theme.cream, bold
      border_fg = "0x00FF3B3B";
    };
  };
  # one session on the login screen: Hyprland ships a uwsm one too, which ly lists first and which
  # logs straight out without uwsm set up
  services.displayManager.sessionPackages = lib.mkIf (!keepDesktop) (lib.mkForce [
    (pkgs.runCommand "hyprland-session" { passthru.providedSessions = [ "hyprland" ]; } ''
      mkdir -p $out/share/wayland-sessions
      cp ${config.programs.hyprland.package}/share/wayland-sessions/hyprland.desktop $out/share/wayland-sessions/
    '')
  ]);
  # Dolphin left with Plasma: a light file manager in its place
  environment.systemPackages = lib.mkIf (!keepDesktop) [ pkgs.thunar ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "pre-pharnavos";   # the user's own dotfiles are moved aside, never lost
    extraSpecialArgs = { inherit user; };
    users.${user} = {
      imports = [ self.homeModules.default ../templates/default/home.nix ];
      # only in Hyprland: a KDE or GNOME session keeps its own panel
      wayland.systemd.target = "hyprland-session.target";
      # Plasma's cursors leave with it: a plain one, for Hyprland and GTK apps alike
      home.pointerCursor = lib.mkIf (!keepDesktop) {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        size = 24;
        gtk.enable = true;
        hyprcursor.enable = true;
      };
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
