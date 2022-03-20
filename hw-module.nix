{ config, lib, pkgs, ... }:

# configuration.nix contains settings applicable to _my_ pinephone
# hw-module.nix contains settings applicable to slab on pinephones generally
# module.nix contains settings applicable to slab generally

{
  config = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "ondemand";
    };
    mobile.boot.stage-1.firmware = [
      config.mobile.device.firmware
    ];
    hardware.sensor.iio.enable = true;
    hardware.firmware = [ config.mobile.device.firmware ];

    services.fwupd = {
      enable = true;
    };

    environment.etc."fwupd/remotes.d/testing.conf" = {
      mode = "0644";
      text = ''
        [fwupd Remote]

        Enabled=true
        Title=Linux Vendor Firmware Service (testing)
        MetadataURI=https://cdn.fwupd.org/downloads/firmware-testing.xml.gz
        ReportURI=https://fwupd.org/lvfs/firmware/report
        OrderBefore=lvfs,fwupd
        AutomaticReports=false
        ApprovalRequired=false
      '';
    };

    nixpkgs = {
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "pine64-pinephone-firmware"
      ];

    };
  };
}
