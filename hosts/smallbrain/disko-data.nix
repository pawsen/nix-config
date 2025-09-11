{
  disko.devices = {
    disk.data1 = {
      type = "disk";
      device = "/dev/sdb";
      content = {
        type = "gpt";
        partitions = {
          data = {
            size = "100%";
            content = {
              type = "btrfs";
              raidLevel = "raid1"; # <- mirror across disks
              devices = [ "/dev/sdb1" "/dev/sdc1" ];
              mountpoint = "/data";
              subvolumes = {
                "@backups" = { mountpoint = "/data/backups"; };
                "@data" = { mountpoint = "/data/data"; };
              };
            };
          };
        };
      };
    };
    disk.data2 = {
      type = "disk";
      device = "/dev/sdc";
      content = {
        type = "gpt";
        partitions = {
          data = {
            size = "100%";
            # content is handled in data1 (shared btrfs pool)
          };
        };
      };
    };
  };
}
