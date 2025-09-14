{ config, pkgs, ... }:

{

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];


  # System utilities
  environment.systemPackages = with pkgs; [
    htop
    tmux
    curl
    wget
    git
    fd
    ripgrep
    unixtools.netstat
    dnsutils  # dig,
  ];

  programs = {
    neovim = {
      enable = true;
      vimAlias = true;
      viAlias = true;
      configure = {
        packages.myPlugins = with pkgs.vimPlugins; {
          start = [
            vim-surround # Shortcuts for setting () {} etc.
            vim-nix # nix highlight
            fzf-vim # fuzzy finder through vim
            nerdtree # file structure inside nvim
            rainbow # Color parenthesis
            vim-operator-user # map plugins to keybinds
          ];
          opt = [ ];
        };
      };
    };

  };

  # SSH access
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.PermitRootLogin = "prohibit-password";
  };
}
