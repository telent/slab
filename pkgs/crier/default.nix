{ stdenv
, callPackage
, fennel
, fetchFromGitHub
, fetchurl
, gobject-introspection
, gtk3
, gtk-layer-shell
, lib
, librsvg
, lua53Packages
, lua5_3
, luaDbusProxy
, makeWrapper
, writeText
}:
let lua = lua5_3.withPackages (ps: with ps; [
      luaDbusProxy
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

  buildInputs = [
    gobject-introspection.dev
    gtk-layer-shell
    gtk3
    lua
  ];
  nativeBuildInputs = [ lua makeWrapper ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];

}
