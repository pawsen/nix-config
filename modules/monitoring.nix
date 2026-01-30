{ config, lib, pkgs, ... }:

let
  cfg = config.services.monitoring;
  # normalize: "/torrent" (no trailing slash)
  promPrefix = lib.removeSuffix "/" cfg.prometheusPath;
  grafPrefix = lib.removeSuffix "/" cfg.grafanaPath;

  promPrefixSlash = "${promPrefix}/";
  grafPrefixSlash = "${grafPrefix}/";

  siteAddr = cfg.domain;
  snippetPath = "/etc/caddy/snippets/torrent-auth";
in {
  options.services.monitoring = {
    enable = lib.mkEnableOption
      "Prometheus + Grafana + node_exporter behind Caddy subpaths";

    domain = lib.mkOption {
      type = lib.types.str;
      example = "monitor.smallbrain";
      description = "Domain name for the monitor web interface.";
    };

    prometheusPath = lib.mkOption {
      type = lib.types.str;
      default = "/prometheus";
      description =
        "Subpath for Prometheus behind Caddy (default /prometheus).";
    };

    grafanaPath = lib.mkOption {
      type = lib.types.str;
      default = "/grafana";
      description = "Subpath for Grafana behind Caddy (default /grafana).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9090;

      exporters.node = {
        enable = true;
        listenAddress = "127.0.0.1";
      };

      scrapeConfigs = [{
        job_name = "node";
        static_configs = [{
          targets = [
            "127.0.0.1:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
        }];
      }];

      # Required when proxying Prometheus under a path prefix
      extraFlags = [
        "--web.external-url=https://${siteAddr}${promPrefixSlash}"
        "--web.route-prefix=${promPrefixSlash}"
      ];
    };

    services.grafana = {
      enable = true;

      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = 3000;

          # Required for reverse proxy under a subpath
          domain = siteAddr;
          root_url = "https://${siteAddr}${grafPrefixSlash}";
          serve_from_sub_path = true;
        };
        "auth.anonymous" = {
          enabled = true;
          org_role = "Admin"; # or Viewer, Editor
        };
        # Optional: hide Grafana's login form entirely
        "auth" = {
          disable_login_form = true;
        };
      };

      provision.datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://127.0.0.1:${toString config.services.prometheus.port}${promPrefixSlash}";
        isDefault = true;
      }];
    };

    # Assume you already enable Caddy elsewhere; this only extends vhost config.
    services.caddy.virtualHosts.${siteAddr}.extraConfig = lib.mkAfter ''
      @promNoSlash path ${promPrefix}
      redir @promNoSlash ${promPrefixSlash} 308

      handle ${promPrefix}/* {
          basic_auth @untrusted {
              import ${snippetPath}
          }
          reverse_proxy 127.0.0.1:${toString config.services.prometheus.port}
      }

      @grafNoSlash path ${grafPrefix}
      redir @grafNoSlash ${grafPrefixSlash} 308
      handle ${grafPrefix}/* {
          basic_auth @untrusted {
              import ${snippetPath}
          }
          reverse_proxy 127.0.0.1:${
            toString config.services.grafana.settings.server.http_port
          }
      }
    '';
  };
}
