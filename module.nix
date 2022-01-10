{ config, lib, pkgs, ... }:

let
  cfg = config.services.slab;
in {
  options.services.slab = {
    ttyNumber = lib.mkOption {
      type = lib.types.str;
      default = "2";
    };
    userName =  lib.mkOption {
      type = lib.types.str;
      default = "dan";
    };
  };
  config = {
    nixpkgs.overlays = [ (import ./overlay.nix) ] ;

    environment.systemPackages = with pkgs; [
      chatty
      squeekboardService
      firefoxMobile
      launcher
    ];

    services.dbus.packages = [ pkgs.squeekboardService ];

    programs.sway = {
      enable = true;
      extraPackages = with pkgs; [
        swaylock swayidle xwayland termite
        mako grim slurp wl-clipboard wf-recorder
      ];
    };
    systemd.defaultUnit = "graphical.target";

    systemd.services.sway = {
      enable = true;

      # these dependencies are copied from  display-manager.service
      # on a GNOME machine, may or may not be entirely correct
      wants = [
        "systemd-machined.service"
        "accounts-daemon.service"
        "systemd-udev-settle.service"
      ];
      after =  [
        "rc-local.service"
        "systemd-machined.service"
        "systemd-user-sessions.service"
        "getty@tty${cfg.ttyNumber}.service"
        "plymouth-quit.service"
        "plymouth-start.service"
        "systemd-logind.service"
        "systemd-udev-settle.service"
      ];
      conflicts = [
        "getty@tty${cfg.ttyNumber}.service"
        "plymouth-quit.service"
      ];

      serviceConfig =
        let run-sway = pkgs.writeScript "run-sway" ''
          #!${pkgs.bash}/bin/bash
          source ${config.system.build.setEnvironment}
          ${pkgs.dbus}/bin/dbus-run-session ${pkgs.launcher}/bin/launch
          systemd-cat echo "dbus-run-session $?"
        '';
        in {
#          ExecStartPre = "${config.system.path}/bin/chvt 6";
          ExecStart = run-sway;
          TTYPath = "/dev/tty${cfg.ttyNumber}";
          TTYReset = "yes";
          TTYVHangup = "yes";
          TTYVTDisallocate = "yes";
          PAMName = "login";
          User = cfg.userName;
          WorkingDirectory = "/home/${cfg.userName}";
          StandardInput = "tty";
          StandardError = "journal";
          StandardOutput = "journal";
          Restart = "no";
          SyslogIdentifier = "sway";
        };
    };

    # waybar needs one or more of these for icons
    fonts.fonts = with pkgs; [ font-awesome font-awesome-ttf ] ;

    # XXX need to tighten these down, all we really need is to
    # be able to write some sysfs files
    security.wrappers = {
      pptk-backlight = {
        setuid = true; owner = "root"; group = "root";
        source = "${pkgs.pinephone-toolkit}/bin/pptk-backlight";
      };
      pptk-cpu-sleep =  {
        setuid = true; owner = "root"; group = "root";
        source = "${pkgs.pinephone-toolkit}/bin/pptk-cpu-sleep";
      };
      pptk-led =  {
        setuid = true; owner = "root"; group = "root";
        source = "${pkgs.pinephone-toolkit}/bin/pptk-led";
      };
      pptk-vibrate =  {
        setuid = true; owner = "root"; group = "root";
        source = "${pkgs.pinephone-toolkit}/bin/pptk-vibrate";
      };
    };
  };
}
