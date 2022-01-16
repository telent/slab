{ stdenv
, bemenu
, dialog
, iio-sensor-proxy
, lib
, lisgd
, mako
, pinephone-toolkit
, saturn
, squeekboard
, sway
, swayidle
, swaylock
, waybar
} :
let
  paths = lib.makeBinPath [
    bemenu
    dialog
    lisgd
    lisgd
    mako
    pinephone-toolkit
    saturn
    squeekboard
    swayidle
    swaylock
    waybar
  ];
in stdenv.mkDerivation {
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
     sed -i "2 i export PATH=${paths}:\$PATH" $out/bin/launch
     sed -i "2 i export TOP=$out" $out/bin/launch
     substituteInPlace $out/bin/swayphone_rotate --replace monitor-sensor ${iio-sensor-proxy}/bin/monitor-sensor
   '';

}
