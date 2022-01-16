{ lua, lgi, buildLuaPackage, fetchFromGitHub }:
let

  simpleName = "dbus_proxy";

in
# TODO: add busted and checkPhase?
buildLuaPackage rec {
  version = "0.10.2";
  pname = simpleName;
#  name = "${simpleName}-${version}";

  src = fetchFromGitHub {
    owner = "stefano-m";
    repo = "lua-${simpleName}";
    rev = "v${version}";
    sha256 = "0kl8ff1g1kpmslzzf53cbzfl1bmb5cb91w431hbz0z0vdrramh6l";
  };

  propagatedBuildInputs = [ lgi ];

  buildPhase = ":";

  installPhase = ''
    mkdir -p "$out/share/lua/${lua.luaversion}"
    cp -r src/${simpleName} "$out/share/lua/${lua.luaversion}/"
  '';

}
