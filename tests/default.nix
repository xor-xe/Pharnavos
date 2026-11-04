# Every choice NixOS's graphical installer offers for KDE, each wrapped the way the installer
# script wraps it; a check fails if one of them no longer builds.
{ self, lib }:

let
  variants = {
    uefi = { };
    bios = { boot.loader.systemd-boot.enable = lib.mkForce false; boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
             boot.loader.grub = { enable = true; device = "/dev/vda"; useOSProber = true; }; };
    luks = { boot.initrd.luks.devices.root.device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000"; };
    unfree = { nixpkgs.config.allowUnfree = true; };
    autologin = { services.displayManager.autoLogin = { enable = true; user = "tester"; }; };
    german = { services.xserver.xkb.layout = lib.mkForce "de"; console.keyMap = "de"; };
    older = { system.stateVersion = lib.mkForce "24.11"; };
    gnome = { services.displayManager.sddm.enable = lib.mkForce false; services.desktopManager.plasma6.enable = lib.mkForce false;
              services.displayManager.gdm.enable = true; services.desktopManager.gnome.enable = true; };
  };
  gpus = { nvidia-open = "open"; nvidia-closed = "closed"; };
  wrap = { nvidia ? null, apps ? null }: extra:
    (self.lib.system { user = "tester"; inherit nvidia apps; modules = [ ./kde/configuration.nix extra ]; }).config.system.build.toplevel;
in
lib.mapAttrs (_: wrap { }) variants // lib.mapAttrs (_: n: wrap { nvidia = n; } { }) gpus
# apps installed from the launcher: a free one and an unfree one
// { apps = wrap { apps = ./kde/apps.json; } { }; }
