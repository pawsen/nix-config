{
  description = "My NixOS configs (multi-host)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, agenix, ... }@inputs:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        smallbrain = lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            agenix.nixosModules.default
            ./hosts/smallbrain/configuration.nix
            ./hosts/smallbrain/disko.nix
            ./modules/base.nix
            ./modules/server.nix
            ./users/paw.nix
          ];
        };
        # laptop = lib.nixosSystem {
        #   inherit system;
        #   modules = [
        #     ./hosts/laptop/configuration.nix
        #     ./modules/base.nix
        #     ./modules/desktop.nix
        #     ./users/youruser.nix
        #   ];
        # };
      };
    };
}

