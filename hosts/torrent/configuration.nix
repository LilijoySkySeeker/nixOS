{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/PC.nix
    ./storage.nix
    ../../modules/nixos/wooting.nix
  ];

  # System installed pkgs
  environment.systemPackages =
    with pkgs;
    [
    ];

  # zfs snapshots
  services.sanoid = {
    enable = true;
    extraArgs = [ "--verbose" ];
    interval = "minutely";
    settings = {
      "zroot/local/state".use_template = "working";
      template_working = {
        frequent_period = 1;
        frequently = 59;
        hourly = 24;
        daily = 1;
        weekly = 0;
        monthly = 0;
        yearly = 0;
        autosnap = "yes";
        autoprune = "yes";
      };
    };
  };
  systemd.services.sanoid.serviceConfig = {
    User = lib.mkForce "root";
  };

  # cpu power management
  powerManagement.cpuFreqGovernor = "performance";

  # home manager
  home-manager.users.lilijoy = { 
    imports = [ ../../../modules/home-manager/kde.nix ];
  };

  # KDE Plasma
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # update microcode
  hardware.amd.intel.updateMicrocode = true;

  # Define your hostname.
  networking.hostName = "torrent";

  # Set extra groups
  users.users.lilijoy.extraGroups = [ "docker" ];
}
