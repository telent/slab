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
  postInstall = ''
    mkdir -p $out/share/dbus-1/services

    cat <<SERVICE > $out/share/dbus-1/services/org.freedesktop.Notifications.service
    [D-BUS Service]
    Name=org.freedesktop.Notifications
    Exec=$out/bin/crier
    SERVICE

    wrapProgram $out/bin/crier --set CRIER_PATH $out --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH"
  '';

}
