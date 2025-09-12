{ config, pkgs, lib, ... }:

{
  time.timeZone = lib.mkDefault "UTC";
  networking.networkmanager.enable = true;
  environment.systemPackages = with pkgs; [ htop git ];
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
}
