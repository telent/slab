{ stdenv
, callPackage
, fennel
, fetchFromGitHub
, fetchurl
, gobject-introspection
, gtk3
, lib
, librsvg
, lua53Packages
, luaDbusProxy
, lua5_3
, makeWrapper
, writeText
}:
let inifile = let lua = lua5_3; in lua53Packages.buildLuaPackage rec {
      pname  = "inifile";
      name = "${pname}-${version}";
      version  = "1.0.2";
      src = fetchFromGitHub {
        owner = "bartbes";
        repo = "inifile";
        rev = "f0b41a8a927f3413310510121c5767021957a4e0";
        sha256 = "1ry0q238vbp8wxwy4qp1aychh687lvbckcf647pmc03rwkakxm4r";
      };
      buildPhase = ":";
      installPhase = ''
        mkdir -p "$out/share/lua/${lua.luaversion}"
        cp inifile.lua "$out/share/lua/${lua.luaversion}/"
      '';
    };

    lua = lua5_3.withPackages (ps: with ps; [
      luaDbusProxy
      inifile
      inspect
      lgi
      luafilesystem
      luaposix
      penlight
      readline
    ]);
in stdenv.mkDerivation {
  pname = "saturn";
  version = "0.4.9";            # nearly Saturn 0.5
  src =./.;
  inherit fennel;

  buildInputs = [ lua gtk3 gobject-introspection.dev ];
  nativeBuildInputs = [ lua makeWrapper ];

  makeFlags = [ "PREFIX=${placeholder "out"}" ];
  # GDK_PIXBUF_MODULE_FILE setting is to support SVG icons without
  # their having been transformed to bitmaps.
  # This makes a big difference to how many icons are displayed on
  # my machine
  postInstall = ''
    mkdir -p $out/share/dbus-1/services

    cat <<SERVICE > $out/share/dbus-1/services/net.telent.saturn.service
    [D-BUS Service]
    Name=net.telent.saturn
    Exec=$out/bin/saturn
    SERVICE

    wrapProgram $out/bin/saturn --set GDK_PIXBUF_MODULE_FILE ${librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache --set GI_TYPELIB_PATH "$GI_TYPELIB_PATH"
  '';
}
