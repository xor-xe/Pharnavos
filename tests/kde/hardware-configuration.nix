# A QEMU machine, as nixos-generate-config would describe it, plus what the VM test drives it with.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_blk" "sr_mod" ];
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/ESP"; fsType = "vfat"; options = [ "fmask=0077" "dmask=0077" ]; };
  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # test only: the installer sets the password interactively; ssh lets the test drive the machine
  users.users.tester.initialPassword = "pharnavos";
  services.openssh = { enable = true; settings.PasswordAuthentication = true; };
  boot.growPartition = true;                      # the test disk image is grown to 40 GB before boot
  fileSystems."/".autoResize = true;
}
