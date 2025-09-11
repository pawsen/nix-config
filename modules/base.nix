{ config, pkgs, ... }:

{
  time.timeZone = "UTC";
  networking.networkmanager.enable = true;
  environment.systemPackages = with pkgs; [ vim htop git ];
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
}
