{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services;

  operatorName = config.nix-bitcoin.operator.name;

  mkHiddenService = map: {
    map = [ map ];
    version = 3;
  };
in {
  imports = [
    ../modules.nix
    ./enable-tor.nix
  ];

  config =  {
    # For backwards compatibility only
    nix-bitcoin.secretsDir = mkDefault "/secrets";

    networking.firewall.enable = true;

    nix-bitcoin.security.hideProcessInformation = true;

    # Use doas instead of sudo
    security.doas.enable = true;
    security.sudo.enable = false;

    environment.systemPackages = with pkgs; [
      jq
    ];

    # sshd
    services.tor.hiddenServices.sshd = mkHiddenService { port = 22; };
    nix-bitcoin.onionAddresses.access.${operatorName} = [ "sshd" ];

    services.bitcoind = {
      enable = true;
      listen = true;
      dataDirReadableByGroup = mkIf cfg.electrs.high-memory true;
      assumevalid = "00000000000000000000e5abc3a74fe27dc0ead9c70ea1deb456f11c15fd7bc6";
      addnodes = [ "ecoc5q34tmbq54wl.onion" ];
      discover = false;
      addresstype = "bech32";
      dbCache = 1000;
    };

    services.liquidd = {
      prune = 1000;
      validatepegin = true;
      listen = true;
    };

    nix-bitcoin.nodeinfo.enable = true;

    services.backups.frequency = "daily";

    # operator
    nix-bitcoin.operator = {
      enable = true;
      allowServiceControl = true;
    };
    users.users.${operatorName} = {
      openssh.authorizedKeys.keys = config.users.users.root.openssh.authorizedKeys.keys;
    };
    # Enable nixops ssh for operator (`nixops ssh operator@mynode`) on nixops-vbox deployments
    systemd.services.get-vbox-nixops-client-key =
      mkIf (builtins.elem ".vbox-nixops-client-key" config.services.openssh.authorizedKeysFiles) {
        postStart = ''
          cp "${config.users.users.root.home}/.vbox-nixops-client-key" "${config.users.users.${operatorName}.home}"
        '';
      };
  };
}
