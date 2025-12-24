let
  # Your laptop/user SSH public key (so you can edit/re-encrypt secrets)
  paw = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILzmI5vQeHv3DqpRvyI4akd/LRqYuHlhPbnvcLAYoO15 paw@lion";

  # The server's SSH host public key (so the server can decrypt during rebuild)
  # cat /etc/ssh/ssh_host_ed25519_key.pub
  smallbrain = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO7Vx+X8z9/oMVAvcumDIIk7iSfL6nspehNetgCCLYvh root@smallbrain";
in
{
  "hdd.key.age".publicKeys = [ paw smallbrain ];
  "torrent-auth.age".publicKeys = [ paw smallbrain ];
  "downloads-auth.age".publicKeys = [ paw smallbrain ];
  "media-auth.age".publicKeys = [ paw smallbrain ];
  "tailscale-auth.age".publicKeys = [ paw smallbrain ];
}
