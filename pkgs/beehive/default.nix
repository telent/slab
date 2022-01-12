{ fetchurl
, stdenv
, callPackage
, gobject-introspection
, gtk3
, lua53Packages
, lua5_3
, lib
}:
# https://github.com/stefano-m/lua-dbus_proxy
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
  inherit dbusProxy;
  buildInputs = [ lua gtk3 gobject-introspection.dev ];
  inherit fennel;
}
