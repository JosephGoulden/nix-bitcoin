{ config, lib, pkgs, ... }:

with lib;
let cfg = config.services.clightning.plugins.clboss; in
{
  options.services.clightning.plugins.clboss = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Whether to enable CLBOSS (clightning plugin).
        See also: https://github.com/ZmnSCPxj/clboss#operating
      '';
    };
    acknowledgeDeprecation = mkOption {
      type = types.bool;
      default = false;
      internal = true;
    };
    min-onchain = mkOption {
      type = types.ints.positive;
      default = 30000;
      description = mdDoc ''
        Target amount (in satoshi) that CLBOSS will leave on-chain.
        clboss will only open new channels if the funds in your clightning wallet are
        larger than this amount.
      '';
    };
    min-channel = mkOption {
      type = types.ints.positive;
      default = 500000;
      description = mdDoc "The minimum size (in satoshi) of channels created by CLBOSS.";
    };
    max-channel = mkOption {
      type = types.ints.positive;
      default = 16777215;
      description = mdDoc "The maximum size (in satoshi) of channels created by CLBOSS.";
    };
    zerobasefee = mkOption {
      type = types.enum [ "require" "allow" "disallow" ];
      default = "allow";
      description = mdDoc ''
        `require`: set `base_fee` to 0.
        `allow`: set `base_fee` according to the CLBOSS heuristics, which may include value 0.
        `disallow`: set `base_fee` to according to the CLBOSS heuristics, with a minimum value of 1.
      '';
    };
    package = mkOption {
      type = types.package;
      default = config.nix-bitcoin.pkgs.clboss;
      defaultText = "config.nix-bitcoin.pkgs.clboss";
      description = mdDoc "The package providing clboss binaries.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.acknowledgeDeprecation;
        message = ''
          `clboss` is no longer maintained and has been deprecated.

          Warning: For compatibility with clighting 23.05, the nix-bitcoin `clboss` package
          includes a third-party fix that has not been thoroughly tested:
          https://github.com/ZmnSCPxj/clboss/pull/162

          To ignore this warning and continue using `clboss`, add the following to your config:
          services.clightning.plugins.clboss.acknowledgeDeprecation = true;
        '';
      }
    ];

    services.clightning.extraConfig = ''
      plugin=${cfg.package}/bin/clboss
      clboss-min-onchain=${toString cfg.min-onchain}
      clboss-min-channel=${toString cfg.min-channel}
      clboss-max-channel=${toString cfg.max-channel}
      clboss-zerobasefee=${cfg.zerobasefee}
    '';

    systemd.services.clightning.path = [
      pkgs.dnsutils
    ] ++ optional config.services.clightning.tor.proxy (hiPrio config.nix-bitcoin.torify);
  };
}
