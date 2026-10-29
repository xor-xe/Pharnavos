{
  description = "My NixOS (unstable) with Hyprland and Pharnavos";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pharnavos = {
      url = "github:xor-xe/Pharnavos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, pharnavos, ... }:
    let
      user = "me";          # ← your user name (also in configuration.nix)
    in
    {
      nixosConfigurations.pharnavos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit user; };
        modules = [
          ./configuration.nix
          pharnavos.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit user; };
              users.${user}.imports = [ pharnavos.homeModules.default ./home.nix ];
            };
          }
        ];
      };
    };
}
