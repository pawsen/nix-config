{ config, pkgs, ... }:

{

  # Add this line when disks are plugged in
  imports = [ ./disko.nix ];
  networking.hostName = "smallbrain";
  time.timeZone = "Europe/Copenhagen";

  environment.systemPackages = with pkgs; [
    cryptsetup
  ];

  # This fails because /root (where the key is stored) is not mounted at stage 1 of the boot
  # process. Could maybe work if the key is at /hdd.key.
  # But as it is a non-root device, use crypttab to mount the drive at stage 2 (/root mounted)
  #  boot.initrd.luks.devices = {
  #    cryptdata1 = {
  #      # luksUUID from `cryptsetup luksUUID /dev/sd*
  #      device = "UUID=8b467c74-5538-431b-a507-2b8dfb858ac9";
  #      keyFile = "/root/hdd.key";
  #    };
  #  };
  environment.etc."crypttab".text = ''
    cryptdata1 UUID=8b467c74-5538-431b-a507-2b8dfb858ac9 /root/hdd.key luks,nofail
  '';

  fileSystems."/data" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [ "subvol=@data" "compress=zstd" "noatime" ];
    neededForBoot = false;
  };
  fileSystems."/backups" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [ "subvol=@backups" "compress=zstd" "noatime" ];
    neededForBoot = false;
  };

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
