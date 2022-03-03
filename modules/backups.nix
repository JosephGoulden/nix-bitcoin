{ config, lib, pkgs, ... }:

with lib;
let
  options.services.backups = {
    enable = mkEnableOption "Backups service";
    with-bulk-data = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to also backup Bitcoin blockchain and other bulk data.
      '';
    };
    destination = mkOption {
      type = types.str;
      default = "file:///var/lib/localBackups";
      description = ''
        Where to back up to.
      '';
    };
    frequency = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Run backup with the given frequency. If null, do not run automatically.
      '';
    };
    maxFull = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 2;
      description = ''
        If non-null, delete all backups sets that are older than the count:th
        last full backup (in other words, keep the last count full backups and
        associated incremental sets).
      '';
    };
    postgresqlDatabases = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of database names to backup.";
    };
    extraFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "/var/lib/nginx" ];
      description = "Additional files to be appended to filelist.";
    };
  };

  cfg = config.services.backups;

  # Potential backup file paths are are matched against filelist
  # entries from top to bottom.
  # The first match determines inclusion or exclusion.
  filelist = builtins.toFile "filelist.txt" ''
    ${builtins.concatStringsSep "\n" cfg.extraFiles}

    ${optionalString (!cfg.with-bulk-data) ''
      - ${config.services.bitcoind.dataDir}/blocks
      - ${config.services.bitcoind.dataDir}/chainstate
      - ${config.services.bitcoind.dataDir}/indexes
    ''}
    ${config.services.bitcoind.dataDir}
    ${config.services.clightning.dataDir}
    ${config.services.lnd.dataDir}
    ${optionalString (!cfg.with-bulk-data) ''
      - ${config.services.liquidd.dataDir}/*/blocks
      - ${config.services.liquidd.dataDir}/*/chainstate
      - ${config.services.liquidd.dataDir}/*/indexes
    ''}
    ${config.services.liquidd.dataDir}
    ${optionalString cfg.with-bulk-data "${config.services.electrs.dataDir}"}
    ${config.services.nbxplorer.dataDir}
    ${config.services.btcpayserver.dataDir}
    ${config.services.joinmarket.dataDir}
    ${optionalString config.nix-bitcoin.generateSecrets "${config.nix-bitcoin.secretsDir}"}
    /var/lib/tor
    /var/lib/nixos

    ${builtins.concatStringsSep "\n" postgresqlBackupPaths}

    # Exclude all unspecified files and directories
    - /
  '';

  postgresqlBackupDir = config.services.postgresqlBackup.location;
  postgresqlBackupPaths = map (db: "${postgresqlBackupDir}/${db}.sql.gz") cfg.postgresqlDatabases;
  postgresqlBackupServices = map (db: "postgresqlBackup-${db}.service") cfg.postgresqlDatabases;
in {
  inherit options;

  config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.duplicity ];

      services.duplicity = {
        enable = true;
        extraFlags = [
          "--include-filelist" "${filelist}"
        ];
        fullIfOlderThan = "1M";
        targetUrl = cfg.destination;
        frequency = cfg.frequency;
        secretFile = "${config.nix-bitcoin.secretsDir}/backup-encryption-env";
        cleanup.maxFull = cfg.maxFull;
      };

      systemd.services.duplicity = {
        wants = postgresqlBackupServices;
        after = postgresqlBackupServices;
      };

      services.postgresqlBackup = {
        enable = mkIf (cfg.postgresqlDatabases != []) true;
        databases = cfg.postgresqlDatabases;
      };

      nix-bitcoin.secrets.backup-encryption-env.user = "root";
      nix-bitcoin.generateSecretsCmds.backups = ''
        makePasswordSecret backup-encryption-password
        if [[ backup-encryption-password -nt backup-encryption-env ]]; then
           echo "PASSPHRASE=$(cat backup-encryption-password)" > backup-encryption-env
        fi
      '';

      services.backups.postgresqlDatabases = mkIf config.services.btcpayserver.enable [ "btcpaydb" ];
    };
}
