{ config, pkgs, ... }:

{
  users.users.paw = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "podman" ];

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpF6gB2Z8CImJc3EdMlu7xyB4hwMzUxo+inccPbuvHV paw@lion"
    ];
    # nix run nixpkgs#mkpasswd -- -m sha-512
    hashedPassword =
      "$6$eo/RTzQ5kY1Q1J1O$3BGkkqzT244t1rP13BlPFxC73h.kxvLNYaFdWfp2gPbRKkPXcv4iyGhf0QF.5o6XmaXXL68Nj1iOVh/7.Mcac0";
  };

  programs.git = {
    enable = true;
    config = {
      user.name = "Paw Møller";
      user.email = "pawsen@gmail.com";
    };
  };
}

