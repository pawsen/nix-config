{ config, pkgs, lib, ... }:

{
  # https://nixos.wiki/wiki/NixOS_Generations_Trimmer
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = lib.mkDefault "UTC";
  environment.systemPackages = with pkgs; [ htop git ];
}
