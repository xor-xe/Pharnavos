{
  description = "Pharnavos — a Georgian desktop shell for Hyprland, built on Quickshell";

  # NixOS 26.05: Hyprland 0.55 (hyprlang config) and Quickshell 0.3
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (s: f nixpkgs.legacyPackages.${s});
    in
    {
      packages = forAll (pkgs: { default = pkgs.callPackage ./nix/package.nix { }; });

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

      checks = forAll (pkgs: { package = self.packages.${pkgs.stdenv.hostPlatform.system}.default; });
    };
}
