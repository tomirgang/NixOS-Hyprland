# borgmatic: repos ./system-nixos and ./data on the Storage Box, manual
# external run to tomext (NixOS.md 2.10). Passphrases and the Storage Box key
# live under /root (mode 600) and are created by hand in Phase 4.
{
  config,
  pkgs,
  lib,
  ...
}: let
  storagebox = "ssh://u698029-sub1@u698029-sub1.your-storagebox.de:23";
  sshCommand = "ssh -i /root/.ssh/storagebox_borg -o IdentitiesOnly=yes -o ServerAliveInterval=30";

  sysinfoDump = pkgs.writeShellApplication {
    name = "frame-sysinfo-dump";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      util-linux
      lvm2
      cryptsetup
      nix
      flatpak
      systemd
    ];
    text = builtins.readFile ./frame-sysinfo-dump.sh;
  };

  # Outside borgmatic.d: not run by the timer, only by hand
  externalCfg = (pkgs.formats.yaml {}).generate "external.yaml" {
    repositories = [
      {
        path = "/run/media/tom/tomext/borg/frame";
        label = "external";
      }
    ];
    patterns_from = ["/etc/borgmatic/patterns-system-nixos" "/etc/borgmatic/patterns-data"];
    exclude_if_present = [".nobackup"];
    exclude_caches = true;
    one_file_system = true;
    compression = "auto,zstd,3";
    archive_name_format = "frame-nixos-{now:%Y-%m-%dT%H:%M:%S}";
    match_archives = "sh:frame-nixos-*"; # the last Debian archive frame-… stays untouched
    encryption_passcommand = "cat /root/.config/borg/passphrase-external";
    keep_secondly = 2; # equals borg --keep-last 2
    checks = [
      {name = "repository";}
      {
        name = "data";
        frequency = "1 month";
      }
    ];
    check_last = 1;
    commands = [
      {
        before = "action";
        when = ["create" "prune" "compact" "check"];
        run = [
          "mountpoint -q /run/media/tom/tomext || { echo 'external disk tomext not mounted' >&2; exit 1; }"
          "mountpoint -q /run/media/tom/FrameData || { echo 'FrameData not mounted' >&2; exit 1; }"
        ];
      }
      {
        before = "action";
        when = ["create"];
        run = ["${sysinfoDump}/bin/frame-sysinfo-dump /var/backups/frame"];
      }
    ];
  };
in {
  options.local.backup.externalConfigCheck = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Validates /etc/borgmatic/external.yaml; used as flake check.";
  };

  config = {
    local.backup.externalConfigCheck = pkgs.runCommand "borgmatic-external-check" {} ''
      export HOME=$TMPDIR
      ${pkgs.borgmatic}/bin/borgmatic config validate --config ${externalCfg}
      touch $out
    '';

    environment.systemPackages = [pkgs.borgbackup pkgs.borgmatic sysinfoDump];

    environment.etc."borgmatic/patterns-system-nixos".source = ./patterns-system-nixos;
    environment.etc."borgmatic/patterns-data".source = ./patterns-data;
    environment.etc."borgmatic/external.yaml".source = externalCfg;

    services.borgmatic = {
      enable = true;
      enableConfigCheck = true;
      configurations = {
        system-nixos = {
          repositories = [
            {
              path = "${storagebox}/./system-nixos";
              label = "storagebox-system-nixos";
            }
          ];
          patterns_from = ["/etc/borgmatic/patterns-system-nixos"];
          exclude_if_present = [".nobackup"];
          exclude_caches = true;
          one_file_system = true;
          compression = "auto,zstd,6";
          archive_name_format = "frame-nixos-system-{now:%Y-%m-%dT%H:%M:%S}";
          encryption_passcommand = "cat /root/.config/borg/passphrase-system-nixos";
          ssh_command = sshCommand;
          remote_path = "borg-1.4";
          upload_rate_limit = 800;
          keep_daily = 7;
          keep_weekly = 4;
          checks = [
            {
              name = "repository";
              frequency = "1 week";
            }
            {
              name = "archives";
              frequency = "1 month";
            }
            {
              name = "data";
              frequency = "3 months";
            }
          ];
          check_last = 3;
        };
        data = {
          repositories = [
            {
              path = "${storagebox}/./data";
              label = "storagebox-data";
            }
          ];
          patterns_from = ["/etc/borgmatic/patterns-data"];
          exclude_if_present = [".nobackup"];
          exclude_caches = true;
          one_file_system = true;
          compression = "auto,zstd,3";
          archive_name_format = "frame-data-{now:%Y-%m-%dT%H:%M:%S}";
          encryption_passcommand = "cat /root/.config/borg/passphrase-data";
          ssh_command = sshCommand;
          remote_path = "borg-1.4";
          upload_rate_limit = 800;
          keep_daily = 7;
          keep_weekly = 4;
          checks = [
            {
              name = "repository";
              frequency = "1 week";
              max_duration = 3600;
            }
            {
              name = "archives";
              frequency = "1 month";
            }
          ];
          check_last = 3;
          commands = [
            {
              before = "action";
              when = ["create" "prune" "compact" "check"];
              run = ["mountpoint -q /run/media/tom/FrameData || exit 75"];
            }
          ];
        };
      };
    };

    # Service and timer come from the borgmatic package (systemd-inhibit,
    # ConditionACPower); only extended or overridden here
    systemd.services.borgmatic = {
      path = [pkgs.util-linux pkgs.openssh];
      serviceConfig.ExecStartPre = ["+${sysinfoDump}/bin/frame-sysinfo-dump /var/backups/frame"];
    };
    systemd.timers.borgmatic.timerConfig = {
      OnCalendar = ["" "*-*-* 12:30:00"]; # empty entry resets the package default
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
