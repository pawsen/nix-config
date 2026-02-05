{ config, lib, pkgs, ... }:

let
  cfg = config.services.lfhsRtl433;

  # normalize: "/lfhs" (no trailing slash)
  lfhsPrefix = lib.removeSuffix "/" cfg.path;
  lfhsPrefixSlash = "${lfhsPrefix}/";

  siteAddr = cfg.domain;
  snippetPath = cfg.authSnippetPath;
  siteRoot = if cfg.devRoot != null then cfg.devRoot else site;

  # Copy local static files into the Nix store
  site = pkgs.stdenvNoCC.mkDerivation {
    name = "lfhs-rtl433-site";
    src = ./lfhs-rtl433;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r ./* $out/
    '';
  };
in {
  options.services.lfhsRtl433 = {
    enable = lib.mkEnableOption
      "LFHS rtl_433 static temperature page under a Caddy subpath";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "smallbrain.bleak-mine.ts.net";
      description = "Domain name serving LFHS page behind Caddy.";
    };

    path = lib.mkOption {
      type = lib.types.str;
      default = "/lfhs";
      description = "Subpath for the LFHS page behind Caddy (default /lfhs).";
    };

    devRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        If set, serve LFHS static files from this directory (writable, for dev).
        If null, serve from the Nix store derivation (immutable, for prod).
      '';
    };
    # This assumes you already have Prometheus enabled (e.g. via your monitoring module).
    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Local Prometheus port (for reverse proxy).";
    };

    prometheusListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Local Prometheus listen address (for reverse proxy).";
    };

    authSnippetPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/caddy/snippets/torrent-auth";
      description =
        "Path to Caddy auth snippet (same pattern as monitoring module).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      scrapeConfigs = lib.mkAfter [{
        job_name = "rtl433_pi";
        scrape_interval = "15s";
        # metrics_path = "/metrics";
        # scheme = "http";

        static_configs = [{
          targets = [
            "pi4:9123" # MagicDNS name on Tailscale
            # "pi4.bleak-mine.ts.net:9123"
            # "100.x.y.z:9123"
          ];
        }];
      }];
    };
    services.caddy.enable = true;
    services.caddy.virtualHosts.${siteAddr}.extraConfig = lib.mkAfter ''
              # Redirect /lfhs -> /lfhs/
              @lfhsNoSlash path ${lfhsPrefix}
              redir @lfhsNoSlash ${lfhsPrefixSlash} 308

              # Serve static page
              handle_path ${lfhsPrefix}/* {
                # basic_auth @untrusted {
                #     import ${snippetPath}
                # }
                root * ${siteRoot}

                # If the request looks like a static asset, do NOT fall back to index.html
                @asset path_regexp asset \.(js|css|map|png|jpg|jpeg|gif|svg|ico|woff2?)$
                handle @asset {
                    file_server
                }

                # For everything else, SPA-ish fallback
                try_files {path} /index.html
                file_server
              }
      # /lfhs/prom/* -> upstream /prometheus/*
        handle_path ${lfhsPrefixSlash}prom/* {
                  # basic_auth @untrusted {
                  #     import ${snippetPath}
                  # }

            # Prometheus is configured with --web.route-prefix=/prometheus/
            # so we rewrite /lfhs/prom/<...> -> /prometheus/<...> upstream.
            rewrite * /prometheus{uri}
            reverse_proxy ${cfg.prometheusListenAddress}:${
              toString cfg.prometheusPort
            }
        }
              }
    '';
  };
}
