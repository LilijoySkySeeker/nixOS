{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  lib,
  vars,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/nixos/shared.nix
    ../../modules/nixos/profiles/server.nix
  ];

  # System installed pkgs
  environment.systemPackages =
    (with pkgs; [
      # STABLE installed packages
      sanoid # also installs syncoid and findoid
      zfs
    ])
    ++ (with pkgs-unstable; [
      # UNSTABLE installed packages
    ]);

  # backups
  services.sanoid = {
    enable = true;
    extraArgs = ["--verbose"];
    interval = "minutely";
    settings = {
      "zroot/local/state".use_template = "working";
      "zdata/storage/storage".use_template = "working";
      "zdata/storaeg/storage-bulk".use_template = "working";
      template_working = {
        frequent_period = 1;
        frequently = 59;
        hourly = 24;
        daily = 0;
        weekly = 0;
        monthly = 0;
        yearly = 0;
        autosnap = "yes";
        autoprune = "yes";
      };
    "zbackup/backup".use_template = "backup";
      template_backup = {
        frequently = 0;
        hourly = 168;
        daily = 32;
        weekly = 0;
        monthly = 12;
        yearly = 0;
        autosnap = "no";
        autoprune = "yes";
      };
    };
  };
  systemd.services.sanoid.serviceConfig = {
    User = lib.mkForce "root";
  };
  services.syncoid = {
    enable = true;
    interval = "hourly";
    commonArgs = [ "--no-sync-snap" ]; # --create-bookmark for the mobile machines
    commands = {
      "storage" = {
        source = "zdata/storage";
        target = "zbackup/backup";
        recursive = true;
        extraArgs = [ "--identifier=storage" ];
      };
      "state" = {
        source = "zroot/local/state";
        target = "zbackup/backup";
        extraArgs = [ "--identifier=state" ];
      };
    };
  };

  # cpu power management
  powerManagement.cpuFreqGovernor = "performance";

  # disable emergencymode
  systemd.enableEmergencyMode = false;

  # lock down users
  users.mutableUsers = false;
  #users.users.root.hashedPassword = "!";

  # Define your hostname.
  networking.hostName = "homelab";

  #security
  # lock down nix
  nix.settings.allowed-users = ["root"];
  # disable sudo
  security.sudo.enable = false;

  # ssh server
  users.users.root.openssh.authorizedKeys.keys = vars.publicSshKeys;
  services.openssh = {
    enable = true;
    allowSFTP = true;
    settings.KbdInteractiveAuthentication = false;
    extraConfig = ''
      passwordAuthentication = no
      PermitRootLogin = prohibit-password
      AllowTcpForwarding yes
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
      PermitTunnel no
    '';
  };

  # zfs support
  boot.supportedFilesystems = ["zfs"];
  ##   environment.systemPackages = with pkgs; [zfs];
  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };
  networking.hostId = "e0019fd8";

  # impermanance
  fileSystems."/nix/state".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;
  boot.initrd = {
    systemd = {
      enable = true;
      services.rollback = {
        description = "Rollback root filesystem to a pristine state on boot";
        wantedBy = ["initrd.target"];
        after = ["zfs-import-zroot.service"];
        before = ["sysroot.mount"];
        path = with pkgs; [zfs];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          zfs rollback -r zroot/local/root@blank && echo "  >> >> ROLLBACK COMPLETE << <<"
        '';
      };
    };
  };

  # persistence
  environment.persistence."/nix/state" = {
    # https://github.com/nix-community/impermanence?tab=readme-ov-file#module-usage
    enable = true;
    hideMounts = true;
    directories = [
      "/var/log"
      "/etc/nixos"
      "/var/lib/systemd/timers" # for systemd persistant timers during off time
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
}
