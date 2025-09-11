{ config, pkgs, ... }:

{

  # Add this line when disks are plugged in
  # imports = [ ./disko-data.nix ];
  networking.hostName = "smallbrain";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "you@example.com";
  };

  system.stateVersion = "25.05"; # set at install time
}
