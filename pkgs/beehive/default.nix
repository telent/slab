{ fetchurl
, stdenv
, callPackage
, gobject-introspection
, gtk3
, lua53Packages
, lua5_3
, lib
, makeWrapper
, megi-call-audio
}:
let fennel = fetchurl {
      name = "fennel.lua";
      url = "https://fennel-lang.org/downloads/fennel-1.0.0";
      hash = "sha256:1nha32yilzagfwrs44hc763jgwxd700kaik1is7x7lsjjvkgapw7";
    };
    dbusProxy = callPackage ./dbus-proxy.nix {
      inherit (lua53Packages) lgi buildLuaPackage;
      lua = lua5_3;
    };
    lua = lua5_3.withPackages (ps: with ps; [
      lgi
      (dbusProxy.overrideAttrs(o: {pname = "dbus-prixy";}))
      readline ]);
in stdenv.mkDerivation {
  pname = "beehive";
  version = "0.0.1";
  src =./.;
  inherit dbusProxy fennel;
  buildInputs = [ lua gtk3 gobject-introspection.dev ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    makeWrapper ${./route-audio.sh} $out/bin/route-audio --prefix PATH : ${lib.makeBinPath [ megi-call-audio ]}
  '';
}
