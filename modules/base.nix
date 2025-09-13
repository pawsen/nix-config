{ config, pkgs, lib, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = lib.mkDefault "UTC";
  networking.networkmanager.enable = true;
  environment.systemPackages = with pkgs; [ htop git ];
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
}
