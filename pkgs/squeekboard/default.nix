{ lib
, stdenv
, fetchzip
, meson
, ninja
, pkg-config
, gnome
, glib
, gtk3
, wayland
, wayland-protocols
, libxml2
, libxkbcommon
, rustPlatform
, feedbackd
, wrapGAppsHook
, fetchpatch
}:

stdenv.mkDerivation rec {
  pname = "squeekboard";
  version = "1.15.0-git";

  src = fetchzip {
    url = "https://gitlab.gnome.org/World/Phosh/squeekboard/-/archive/0c17924c50c99845ed6ffcfa5b9bc3bf943ee948/squeekboard-0c17924c50c99845ed6ffcfa5b9bc3bf943ee948.zip";
    sha256 = "sha256-7hJl9UUH3/8cZqlUYFMDmmlRQBl32Sa/ufKI5wExbQ0=";
  };

  cargoDeps = rustPlatform.fetchCargoTarball {
    inherit src;
    cargoUpdateHook = ''
      cat Cargo.toml.in Cargo.deps > Cargo.toml
    '';
    name = "${pname}-${version}";
    sha256 = "0iab0gr8gmlvvqp0l1b5yw3kdx209fgxilss56r6a8pdyzb8lfgc";
  };

  patches = [
    # doesn't work
    # ./unstick_modifiers.patch
  ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    glib
    wayland
    wrapGAppsHook
  ] ++ (with rustPlatform; [
    cargoSetupHook
    rust.cargo
    rust.rustc
  ]);

  buildInputs = [
    gtk3
    gnome.gnome-desktop
    wayland
    wayland-protocols
    libxml2
    libxkbcommon
    feedbackd
  ];

  meta = with lib; {
    description = "A virtual keyboard supporting Wayland";
    homepage = "https://source.puri.sm/Librem5/squeekboard";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ artturin ];
    platforms = platforms.linux;
  };
}
