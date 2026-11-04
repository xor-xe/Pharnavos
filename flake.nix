{
  description = "Pharnavos — a Georgian desktop shell for Hyprland, built on Quickshell";

  # NixOS 26.05: Hyprland 0.55 (hyprlang config) and Quickshell 0.3
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # only for the installer (lib.system); flakes that import Pharnavos's modules bring their own
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }:
    let
      forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (s: f nixpkgs.legacyPackages.${s});
    in
    {
      packages = forAll (pkgs: { default = pkgs.callPackage ./nix/package.nix { }; });

      # sudo nix --extra-experimental-features "nix-command flakes" run github:xor-xe/Pharnavos#install
      apps = forAll (pkgs: {
        install = {
          type = "app";
          program = nixpkgs.lib.getExe (pkgs.writeShellApplication { name = "pharnavos-install"; text = builtins.readFile ./nix/install.sh; });
        };
      });

      # an existing NixOS (its configuration.nix in `modules`) with Pharnavos on top; what the installer writes.
      # apps: a JSON list of the apps installed from the launcher ([{"name": "vlc"}, …])
      lib.system = { user, nvidia ? null, apps ? null, modules }: nixpkgs.lib.nixosSystem {
        specialArgs = { inherit user nvidia apps; };
        modules = modules ++ [ (import ./nix/install.nix self) ];
      };

      homeModules.default = import ./nix/hm.nix self;
      homeManagerModules.default = self.homeModules.default;
      nixosModules.default = ./nix/nixos.nix;

      templates = {
        default = {
          path = ./templates/default;
          description = "A fresh NixOS 26.05 with Hyprland (hyprlang config) and Pharnavos";
        };
        unstable = {
          path = ./templates/unstable;
          description = "A fresh NixOS unstable with Hyprland 0.56+ (Lua config) and Pharnavos";
        };
      };

      checks = forAll (pkgs: { package = self.packages.${pkgs.stdenv.hostPlatform.system}.default; }
        # the installer on each fresh-KDE variant: evaluated only (building them all takes GBs)
        // nixpkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (nixpkgs.lib.mapAttrs' (n: sys:
          nixpkgs.lib.nameValuePair "install-${n}" (pkgs.writeText "install-${n}" (builtins.unsafeDiscardStringContext sys.drvPath)))
          (import ./tests { inherit self; inherit (nixpkgs) lib; })));
    };
}
