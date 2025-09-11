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

  # # Swapfile
  # swapDevices = [
  #   { device = "/swap/swapfile"; size = 2048; }
  # ];

  boot = {
    # FIX, only for HP T620
    # no login screen on tty.
    # radeon KMS (kernel modesetting) issue — common on thin clients like the t620.
    # The kernel switch into a graphics framebuffer, but it looks like screen goes black / never paints the tty.
    # t620’s G-Series chip can be driven by amdgpu, which tends to handle fbcon better than radeon.
    # blacklists radeon, forces amdgpu
    kernelParams = [ "radeon.cik_support=0" "amdgpu.cik_support=1" ];
    initrd.kernelModules = [ "amdgpu" ];

    # pure uefi. Don't use grub.
    loader.systemd-boot.enable = true;
    loader.timeout = 5;
    loader.efi.canTouchEfiVariables = true; # allows writing EFI entries
    supportedFilesystems = [ "btrfs" ];
  };
}
