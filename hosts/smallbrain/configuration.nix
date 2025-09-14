{ config, pkgs, ... }:

{

  # Add this line when disks are plugged in
  imports = [
    ./disko.nix
    ./../../modules/docker-apps.nix
    ./../../modules/torrent.nix
    ./../../modules/downloads.nix
    ./../../modules/media.nix
  ];
  networking.hostName = "smallbrain";
  time.timeZone = "Europe/Copenhagen";

  services.dockerApps.enable = true;
  services.dockerApps.apps = {
    ### DBKK LIBRARY ####
    # git clone --depth 1 https://github.com/pawsen/library-org.git /data/apps/library-org
    # docker build -t library-org .
    # docker run -p 5000:5000 \
    #   -v $(pwd)/uploads:/app/uploads \
    #   -v $(pwd)/database:/app/database \
    #   -v "$(pwd)/library.cfg:/app/library.cfg" \
    #   library-org:latest
    library = {
      image = "library-org:latest";
      containerPort = 5000;
      hostPort = 5001; # external port on the server
      domain = "dbkk.smallbrain";
      enableACME = false; # set true if public + ACME
      addSSL = false; # set true if public + SSL
      volumes = [
        "/data/apps/library-org/database:/app/database"
        "/data/apps/library-org/uploads:/app/uploads"
        "/data/apps/library-org/library.cfg:/app/library.cfg"
      ];
      # optional environment variables
      environment = { };
    };
  };
  services.torrent = {
    enable = true;
    domain = "torrent.smallbrain";
  };
  services.downloads = {
    enable = true;
    domain = "downloads.smallbrain";
  };
  services.media = {
    enable = true;
    domain = "media.smallbrain";
  };

  environment.systemPackages = with pkgs; [ cryptsetup ];

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

  # Don't set a too low timeout for spinning disks/usb interfaces.
  environment.etc."crypttab".text = ''
    cryptdata1 UUID=8b467c74-5538-431b-a507-2b8dfb858ac9 /root/hdd.key nofail
  '';
  fileSystems."/data" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [
      "subvol=@data"
      "compress=zstd"
      "noatime"
      "nofail"
    ]; # "x-systemd.device-timeout=30s" ];
    # neededForBoot = false;
  };
  fileSystems."/backups" = {
    device = "/dev/mapper/cryptdata1";
    fsType = "btrfs";
    options = [
      "subvol=@backups"
      "compress=zstd"
      "noatime"
      "nofail"
    ]; # "x-systemd.device-timeout=30s" ];
    # neededForBoot = false;
  };

  # For simple DHCP wired network, systemd.network is not needed
  # systemd.network.enable = true;
  # use networkd as the network configuration backend or the legacy script based system. Note that
  # this option is experimental, enable at your own risk.
  # networking.useNetworkd = true;
  networking.useDHCP = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      userServices = true; # allow publishing custom services
      addresses = true; # publish this host’s addresses
      workstation = true; # publish as a workstation
    };
  };

  system.stateVersion = "25.05"; # set at install time
}
