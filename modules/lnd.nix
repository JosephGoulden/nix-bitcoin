{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.lnd;
  inherit (config) nix-bitcoin-services;
  onion-chef-service = (if cfg.announce-tor then [ "onion-chef.service" ] else []);
  secretsDir = config.nix-bitcoin.secretsDir;
  mainnetDir = "${cfg.dataDir}/chain/bitcoin/mainnet";
  configFile = pkgs.writeText "lnd.conf" ''
    datadir=${cfg.dataDir}
    logdir=${cfg.dataDir}/logs
    bitcoin.mainnet=1
    tlscertpath=${secretsDir}/lnd-cert
    tlskeypath=${secretsDir}/lnd-key

    listen=${toString cfg.listen}:${toString cfg.listenPort}
    ${lib.concatMapStrings (rpclisten: "rpclisten=${rpclisten}:${toString cfg.rpcPort}\n") cfg.rpclisten}
    ${lib.concatMapStrings (restlisten: "restlisten=${restlisten}:${toString cfg.restPort}\n") cfg.restlisten}

    bitcoin.active=1
    bitcoin.node=bitcoind

    tor.active=true
    ${optionalString (cfg.tor-socks != null) "tor.socks=${cfg.tor-socks}"}

    bitcoind.rpchost=${cfg.bitcoind-host}
    bitcoind.rpcuser=${config.services.bitcoind.rpc.users.public.name}
    bitcoind.zmqpubrawblock=${config.services.bitcoind.zmqpubrawblock}
    bitcoind.zmqpubrawtx=${config.services.bitcoind.zmqpubrawtx}

    ${cfg.extraConfig}
  '';
in {

  options.services.lnd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the LND service will be installed.
      '';
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/lnd";
      description = "The data directory for LND.";
    };
    listen = mkOption {
      type = pkgs.nix-bitcoin.lib.ipv4Address;
      default = "localhost";
      description = "Bind to given address to listen to peer connections";
    };
    listenPort = mkOption {
      type = types.port;
      default = 9735;
      description = "Bind to given port to listen to peer connections";
    };
    rpclisten = mkOption {
      type = types.listOf types.str;
      default = [ "localhost" ];
      description = ''
        Bind to given address to listen to RPC connections.
      '';
    };
    restlisten = mkOption {
      type = types.listOf types.str;
      default = [ "localhost" ];
      description = ''
        Bind to given address to listen to REST connections.
      '';
    };
    rpcPort = mkOption {
      type = types.port;
      default = 10009;
      description = "Port on which to listen for gRPC connections.";
    };
    restPort = mkOption {
      type = types.port;
      default = 8080;
      description = "Port on which to listen for REST connections.";
    };
    bitcoind-host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        The host that your local bitcoind daemon is listening on.
      '';
    };
    tor-socks = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Set a socks proxy to use to connect to Tor nodes";
    };
    announce-tor = mkOption {
      type = types.bool;
      default = false;
      description = "Announce LND Tor Hidden Service";
    };
    macaroons = mkOption {
      default = {};
      type = with types; attrsOf (submodule {
        options = {
          user = mkOption {
            type = types.str;
            description = "User who owns the macaroon.";
          };
          permissions = mkOption {
            type = types.str;
            example = ''
              {"entity":"info","action":"read"},{"entity":"onchain","action":"read"}
            '';
            description = "List of granted macaroon permissions.";
          };
        };
      });
      description = ''
        Extra macaroon definitions.
      '';
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = ''
        autopilot.active=1
      '';
      description = "Additional configurations to be appended to <filename>lnd.conf</filename>.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.nix-bitcoin.lnd;
      defaultText = "pkgs.nix-bitcoin.lnd";
      description = "The package providing lnd binaries.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "lncli"
      # Switch user because lnd makes datadir contents readable by user only
      ''
        ${cfg.cliExec} sudo -u lnd ${cfg.package}/bin/lncli --tlscertpath ${secretsDir}/lnd-cert \
          --macaroonpath '${cfg.dataDir}/chain/bitcoin/mainnet/admin.macaroon' "$@"
      '';
      description = "Binary to connect with the lnd instance.";
    };
    inherit (nix-bitcoin-services) cliExec;
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = config.services.bitcoind.prune == 0;
        message = "lnd does not support bitcoind pruning.";
      }
    ];

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 lnd lnd - -"
    ];

    services.bitcoind = {
      zmqpubrawblock = "tcp://${cfg.bitcoind-host}:28332";
      zmqpubrawtx = "tcp://${cfg.bitcoind-host}:28333";
    };

    services.onion-chef.access.lnd = if cfg.announce-tor then [ "lnd" ] else [];
    systemd.services.lnd = {
      description = "Run LND";
      path  = [ pkgs.nix-bitcoin.bitcoind ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ] ++ onion-chef-service;
      after = [ "bitcoind.service" ] ++ onion-chef-service;
      preStart = ''
        install -m600 ${configFile} '${cfg.dataDir}/lnd.conf'
        echo "bitcoind.rpcpass=$(cat ${secretsDir}/bitcoin-rpcpassword-public)" >> '${cfg.dataDir}/lnd.conf'
        ${optionalString cfg.announce-tor "echo externalip=$(cat /var/lib/onion-chef/lnd/lnd) >> '${cfg.dataDir}/lnd.conf'"}
      '';
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        RuntimeDirectory = "lnd"; # Only used to store custom macaroons
        RuntimeDirectoryMode = "711";
        ExecStart = "${cfg.package}/bin/lnd --configfile=${cfg.dataDir}/lnd.conf";
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir}";
        ExecStartPost = let
          restPort = toString cfg.restPort;
        in [
          # Run fully privileged for secrets dir write access
          "+${nix-bitcoin-services.script ''
            attempts=250
            while ! { exec 3>/dev/tcp/127.0.0.1/${restPort} && exec 3>&-; } &>/dev/null; do
                  ((attempts-- == 0)) && { echo "lnd REST service unreachable"; exit 1; }
                  sleep 0.1
            done

            mnemonic=${secretsDir}/lnd-seed-mnemonic
            if [[ ! -f $mnemonic ]]; then
              echo Create lnd seed
              umask u=r,go=
              ${pkgs.curl}/bin/curl -s \
                --cacert ${secretsDir}/lnd-cert \
                -X GET https://127.0.0.1:${restPort}/v1/genseed | ${pkgs.jq}/bin/jq -c '.cipher_seed_mnemonic' > "$mnemonic"
            fi
            chown lnd: "$mnemonic"
          ''}"
          "${nix-bitcoin-services.script ''
            if [[ ! -f ${mainnetDir}/wallet.db ]]; then
              echo Create lnd wallet

              ${pkgs.curl}/bin/curl -s --output /dev/null --show-error \
                --cacert ${secretsDir}/lnd-cert \
                -X POST -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\", \
                \"cipher_seed_mnemonic\": $(cat ${secretsDir}/lnd-seed-mnemonic | tr -d '\n')}" \
                https://127.0.0.1:${restPort}/v1/initwallet

              # Guarantees that RPC calls with cfg.cli succeed after the service is started
              echo Wait until wallet is created
              while [[ ! -f ${mainnetDir}/admin.macaroon ]]; do
                sleep 0.1
              done
            else
              echo Unlock lnd wallet

              ${pkgs.curl}/bin/curl -s \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${mainnetDir}/admin.macaroon')" \
                --cacert ${secretsDir}/lnd-cert \
                -X POST \
                -d "{\"wallet_password\": \"$(cat ${secretsDir}/lnd-wallet-password | tr -d '\n' | base64 -w0)\"}" \
                https://127.0.0.1:${restPort}/v1/unlockwallet
            fi

            # Wait until the RPC port is open
            while ! { exec 3>/dev/tcp/127.0.0.1/${toString cfg.rpcPort}; } &>/dev/null; do
              sleep 0.1
            done

          ''}"
          # Run fully privileged for chown
          "+${nix-bitcoin-services.script ''
            umask ug=r,o=
            ${lib.concatMapStrings (macaroon: ''
              echo "Create custom macaroon ${macaroon}"
              macaroonPath="$RUNTIME_DIRECTORY/${macaroon}.macaroon"
              ${pkgs.curl}/bin/curl -s \
                -H "Grpc-Metadata-macaroon: $(${pkgs.xxd}/bin/xxd -ps -u -c 99999 '${mainnetDir}/admin.macaroon')" \
                --cacert ${secretsDir}/lnd-cert \
                -X POST \
                -d '{"permissions":[${cfg.macaroons.${macaroon}.permissions}]}' \
                https://127.0.0.1:${restPort}/v1/macaroon |\
                ${pkgs.jq}/bin/jq -c '.macaroon' | ${pkgs.xxd}/bin/xxd -p -r > "$macaroonPath"
              chown ${cfg.macaroons.${macaroon}.user}: "$macaroonPath"
            '') (attrNames cfg.macaroons)}
          ''}"
        ];
      } // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP
        ) // nix-bitcoin-services.allowAnyProtocol;  # For ZMQ
    };
    users.users.lnd = {
      description = "LND User";
      group = "lnd";
      extraGroups = [ "bitcoinrpc" ];
      home = cfg.dataDir; # lnd creates .lnd dir in HOME
    };
    users.groups.lnd = {};
    nix-bitcoin.secrets = {
      lnd-wallet-password.user = "lnd";
      lnd-key.user = "lnd";
      lnd-cert.user = "lnd";
      lnd-cert.permissions = "0444"; # world readable
    };
  };
}
