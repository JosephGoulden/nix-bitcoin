{ config, lib, pkgs, ... }:

with lib;

let
  nix-bitcoin-services = pkgs.callPackage ./nix-bitcoin-services.nix { };
  cfg = config.services.nanopos;
  defaultItemsFile = pkgs.writeText "items.yaml" ''
    tea:
      price: 0.02 # denominated in the currency specified by --currency
      title: Green Tea # title is optional, defaults to the key

    coffee:
      price: 1

    bamba:
      price: 3

    beer:
      price: 7

    hat:
      price: 15

    tshirt:
      price: 25
  '';

in {
  options.services.nanopos = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the nanopos service will be installed.
      '';
    };
    port = mkOption {
      type = types.ints.u16;
      default = 9116;
      description = ''
        "The port on which to listen for connections.";
      '';
    };
    itemsFile = mkOption {
      type = types.path;
      default = defaultItemsFile;
      description = ''
        "The items file (see nanopos README).";
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users.nanopos = {
        description = "nanopos User";
        group = "nanopos";
    };
    users.groups.nanopos = {};

    systemd.services.nanopos = {
      description = "Run nanopos";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lightning-charge.service" ];
      after = [ "lightning-charge.service" ];
      serviceConfig = {
        EnvironmentFile = "/secrets/lightning-charge-api-token-for-nanopos";
        ExecStart = "${pkgs.nanopos}/bin/nanopos -y ${cfg.itemsFile} -p ${toString cfg.port} --show-bolt11";

        User = "nanopos";
        Restart = "on-failure";
        RestartSec = "10s";
      } // nix-bitcoin-services.defaultHardening
        // nix-bitcoin-services.nodejs
        // nix-bitcoin-services.allowTor;
    };
  };
}
