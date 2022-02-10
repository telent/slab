{ stdenv
, callPackage
, fetchFromGitHub
, fetchurl
, gobject-introspection
, gtk3
, lib
, librsvg
, lua53Packages
, lua5_3
, makeWrapper
, writeText
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
      dbusProxy
      inspect
      lgi
      luafilesystem
      luaposix
      readline
    ]);
in stdenv.mkDerivation {
  pname = "crier";
  version = "0.1";
  src =./.;
  inherit fennel;

  buildInputs = [ lua gtk3 gobject-introspection.dev ];
  nativeBuildInputs = [ lua makeWrapper ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

}
