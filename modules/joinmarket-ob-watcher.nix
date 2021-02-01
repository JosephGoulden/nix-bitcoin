{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.joinmarket-ob-watcher;
  inherit (config) nix-bitcoin-services;
  nbPkgs = config.nix-bitcoin.pkgs;
  torAddress = builtins.head (builtins.split ":" config.services.tor.client.socksListenAddress);
  configFile = builtins.toFile "config" ''
    [BLOCKCHAIN]
    blockchain_source = no-blockchain

    [MESSAGING:server1]
    host = darksci3bfoka7tw.onion
    channel = joinmarket-pit
    port = 6697
    usessl = true
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050

    [MESSAGING:server2]
    host = ncwkrwxpq2ikcngxq3dy2xctuheniggtqeibvgofixpzvrwpa77tozqd.onion
    channel = joinmarket-pit
    port = 6667
    usessl = false
    socks5 = true
    socks5_host = ${torAddress}
    socks5_port = 9050
  '';
in {
  options.services.joinmarket-ob-watcher = {
    enable = mkEnableOption "JoinMarket orderbook watcher";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "HTTP server address.";
    };
    port = mkOption {
      type = types.port;
      default = 62601;
      description = "HTTP server port.";
    };
    dataDir = mkOption {
      readOnly = true;
      default = "/var/lib/joinmarket-ob-watcher";
      description = "The data directory for JoinMarket orderbook watcher.";
    };
    user = mkOption {
      type = types.str;
      default = "joinmarket-ob-watcher";
      description = "The user as which to run JoinMarket orderbook watcher.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run JoinMarket orderbook watcher.";
    };
    # This option is only used by netns-isolation
    enforceTor = mkOption {
      readOnly = true;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    services.tor = {
      enable = true;
      client.enable = true;
    };

    systemd.services.joinmarket-ob-watcher = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "tor.service" ];
      after = [ "tor.service" ];
      preStart = ''
        ln -snf ${configFile} ${cfg.dataDir}/joinmarket.cfg
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // rec {
        StateDirectory = "joinmarket-ob-watcher";
        StateDirectoryMode = "0770";
        WorkingDirectory = cfg.dataDir; # The service creates dir 'logs' in the working dir
        ExecStart = ''
          ${nbPkgs.joinmarket}/bin/ob-watcher --datadir=${cfg.dataDir} \
            --host=${cfg.address} --port=${toString cfg.port}
        '';
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.allowTor;
    };

    users.users.${cfg.user} = {
      group = cfg.group;
      home = cfg.dataDir; # The service writes to HOME/.config/matplotlib
    };
    users.groups.${cfg.group} = {};
  };
}
