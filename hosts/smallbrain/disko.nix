{
  disko.devices = {
    disk.ssd = {
      type = "disk";
      device = "/dev/sda"; # adjust if needed
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "512M";
            type = "EF00"; # EFI System Partition
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              mountpoint = "/";
              subvolumes =
                let
                  # if mountOptions are changed, rerun disko in mount mode,
                  # then nixos-rebuild
                  # nix-shell -p disko --run "disko --mode mount --flake .#smallbrain"
                  # nixos-rebuild switch --flake .#smallbrain
                  mountOptions = [ "compress=zstd" "noatime" "autodefrag" ];
                in
                {
                  "@root" = { mountpoint = "/"; inherit mountOptions; };
                  "@nix" = { mountpoint = "/nix"; inherit mountOptions; };
                  "@var" = { mountpoint = "/var"; inherit mountOptions; };
                  "@home" = { mountpoint = "/home"; inherit mountOptions; };
                };
            };
          };
        };
      };
    };
  };

#  # Swapfile
#  swapDevices = [
#    # size in MB
#    { device = "/swap/swapfile"; size = 2048; }
#  ];

  boot = {
    # FIX, only for HP T620
    # no login screen on tty.
    # radeon KMS (kernel modesetting) issue — common on thin clients like the t620.
    # The kernel switch into a graphics framebuffer, but it looks like screen goes black / never paints the tty.
    # t620’s G-Series chip can be driven by amdgpu, which tends to handle fbcon better than radeon.
    # blacklists radeon, forces amdgpu
    # hardware.enableRedistributableFirmware = true;
    # kernelParams = [ "radeon.cik_support=0" "amdgpu.cik_support=1" ];
    # initrd.kernelModules = [ "amdgpu" ];
    kernelParams = [
      # https://askubuntu.com/questions/716957/what-do-the-nomodeset-quiet-and-splash-kernel-parameters-mean#716966
      # nomodeset parameter instructs the kernel to not load video drivers and use BIOS modes
      # instead until X is loaded.
      "nomodeset"
      "console=tty1"
    ];

    # XXX this does not work. Modprobe' r8169 and the device cannot be used. Maybe there's another
    # kernelModule, but I do not care. r8169 works, just throws an error at boot
    # for realtek NIC, uses r8169 as fallback, which works but throws an error on boot
    # r8168 is a separate module, but if r8169 loads first, it takes the NIC.
    # blacklistedKernelModules = [ "r8169" ];
    # kernelModules = [ "r8168" ];

    # pure uefi. Don't use grub.
    loader.systemd-boot.enable = true;
    loader.timeout = 5;
    loader.efi.canTouchEfiVariables = true; # allows writing EFI entries
    supportedFilesystems = [ "btrfs" ];
  };
}
