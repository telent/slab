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

    nixpkgs = {
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "pine64-pinephone-firmware"
      ];

    };
  };
}
