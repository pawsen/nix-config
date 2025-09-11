{ config, pkgs, ... }:

{

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  # Docker
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # optional: provides a `docker` CLI alias
    defaultNetwork.settings.dns_enabled = true;
  };

  # System utilities
  environment.systemPackages = with pkgs; [
    htop
    tmux
    curl
    wget
    git

    # podman-compose for docker-compose compatibility
    podman-compose
  ];

  # SSH access
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
}
