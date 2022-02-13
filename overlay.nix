self: super: {
  crier = self.callPackage ./pkgs/crier {};

  fennel = self.fetchurl {
    name = "fennel.lua";
    url = "https://fennel-lang.org/downloads/fennel-1.0.0";
    hash = "sha256:1nha32yilzagfwrs44hc763jgwxd700kaik1is7x7lsjjvkgapw7";
  };

  firefoxMobile = self.callPackage ./pkgs/mobile-firefox {};

  # this is, with hindsight, not a great name
  launcher = self.callPackage ./pkgs/launcher {};

  luaDbusProxy = self.callPackage ./pkgs/lua-dbus-proxy {
    inherit (self.lua53Packages) lgi buildLuaPackage;
    lua = self.lua5_3;
  };

  pinephone-toolkit = self.stdenv.mkDerivation {
    name = "pinephone-toolkit";

    nativeBuildInputs = with self.pkgs; [
      meson ninja pkg-config
    ];
    version = "0deaf8473";
    src = self.fetchFromGitHub {
      owner = "Dejvino";
      repo = "pinephone-toolkit";
      rev = "0deaf8473a81670298e2bc5772c99d4bae68ffd5";
      hash = "sha256-u6C79xLeA/m9/3LroA2DF6qQ7COun0m4pBylLIFnMcI=";
    };
  };

  saturn = self.callPackage ./pkgs/saturn {};

  schlock = self.callPackage (self.fetchFromGitHub {
    owner = "telent";
    repo = "schlock";
    rev = "65b34b7160c188fa8fc2d8d756d3f022cb5700ed";
    hash = "sha256-bHBrtn2HoKW5f8dEzrKNBPdXWds8UgXTEgRXbIUwPZw=";
  }) {};

  squeekboard = self.callPackage ./pkgs/squeekboard {};

  squeekboardService = self.stdenv.mkDerivation {
    name = "squeekboard.service";
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/share/dbus-1/services
      cat <<EOF > $out/share/dbus-1/services/sm.puri.OSK0.service
      [D-BUS Service]
      Name=sm.puri.OSK0
      Exec=${self.squeekboard}/bin/squeekboard
      EOF
    '';
  };

  # CHECK do we need this? the .session file is installed elsewhere
  squeekboardXml = builtins.fetchurl {
    url = "https://source.puri.sm/Librem5/squeekboard/-/raw/4efe57cbb4f4f0427839a9142001dcc5450acaf2/data/dbus/sm.puri.OSK0.xml";
    name = "sm.puri.OSK0.xml";
    sha256 = "1jpsy5aj9wkb3pjgsdc2scamx91awa7q0bzpxz986fj7jw7dkllp";
  };
}
