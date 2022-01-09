{ stdenv
, bemenu
, dialog
, fetchFromGitHub
, lib
, lisgd
, mako
, pinephone-toolkit
, rot8
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
      src = fetchFromGitHub {
        repo  = "pinephone-sway-poc";
        owner = "Dejvino";
        rev = "eff323bf72a4d9787bddd611f27a360071af31ed";
        hash = lib.fakeHash;
      };
      patches = ./local.patch;
      pname = "launcher";
      version = "1";

      buildPhase = "true";
      installPhase =
        ''
         confdir=$out/etc/xdg/
         mkdir -p $confdir
         cp -r config/sway $confdir/
         cp -r config/waybar $confdir/
         mkdir $out/bin
         cp  bin/* $out/bin
       '';
    };
    paths = lib.concatStringsSep ":"
      (builtins.map (f: "${f}/bin")
        [lisgd swayidle swaylock bemenu squeekboard mako
         rot8
         pinephone-toolkit
         dialog lisgd
         waybar]);
in writeScriptBin "launch" ''
  PATH=${paths}:${configs}/bin:$PATH
  MOZ_ENABLE_WAYLAND=1
  WAYBAR_CONFIG=${configs}/etc/xdg/waybar
  export MOZ_ENABLE_WAYLAND WAYBAR_CONFIG
  echo `date` started > $HOME/.sway-log
  ${sway}/bin/sway -c ${configs}/etc/xdg/sway/config -d >> $HOME/.sway-log 2>&1
  echo `date` finished $? >> $HOME/.sway-log
''
