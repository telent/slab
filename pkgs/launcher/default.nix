{ stdenv
, bemenu
, dialog
, fetchFromGitHub
, iio-sensor-proxy
, lib
, lisgd
, mako
, pinephone-toolkit
, rustPlatform
, squeekboard
, sway
, swayidle
, swaylock
, waybar
, writeScript
, writeScriptBin
} :
let configs = stdenv.mkDerivation {
      src = ./.;
      pname = "launcher";
      version = "1";

      buildPhase = "true";
      installPhase =
        ''
         confdir=$out/etc/xdg/
         mkdir -p $confdir
         cp -r sway $confdir/
         cp -r waybar $confdir/
         mkdir $out/bin
         cp  bin/* $out/bin
         substituteInPlace $out/bin/swayphone_rotate --replace monitor-sensor ${iio-sensor-proxy}/bin/monitor-sensor
       '';

    };
    paths = lib.concatStringsSep ":"
      (builtins.map (f: "${f}/bin")
        [lisgd swayidle swaylock bemenu squeekboard mako
         pinephone-toolkit
         dialog lisgd
         waybar]);
in writeScriptBin "launch" ''
  PATH=/run/wrappers/bin:${paths}:${configs}/bin:$PATH
  MOZ_ENABLE_WAYLAND=1
  WAYBAR_CONFIG=${configs}/etc/xdg/waybar
  export MOZ_ENABLE_WAYLAND WAYBAR_CONFIG
  echo `date` started > $HOME/.sway-log
  ${sway}/bin/sway -c ${configs}/etc/xdg/sway/config -d >> $HOME/.sway-log 2>&1
  echo `date` finished $? >> $HOME/.sway-log
''
