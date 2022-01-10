{ config, lib, pkgs, ... }:

{
  config = {
    nixpkgs.overlays = [ (import ./overlay.nix) ] ;

    # think this is unneeded

    # services.xserver.desktopManager.session = [ {
    #   name = "sway";
    #   start = ''
    #       date >> /tmp/sesslog
    #       ${pkgs.sway}/bin/sway 2>&1 >> /tmp/sesslog
    #       echo Finished /tmp/sesslog
    #       '';
    # } ];

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
      wants = [ "systemd-machined.service" ];
      after =  [
        "rc-local.service"
        "systemd-machined.service"
        "systemd-user-sessions.service"
        "plymouth-quit.service"
        "plymouth-start.service"
        "systemd-logind.service"
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
          TTYPath = "/dev/tty2";
          TTYReset = "yes";
          TTYVHangup = "yes";
          TTYVTDisallocate = "yes";
          PAMName = "login";
          User = "dan";
          WorkingDirectory = "/home/dan";
          StandardInput = "tty";
          StandardError = "journal";
          StandardOutput = "journal";
          Restart = "no";
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
