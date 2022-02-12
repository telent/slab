
# notify-send.py is not needed for installation but it's
# handy for testing, as it supports more features of the
# notification protocol than the basic notify-send.
#
# https://wiki.archlinux.org/title/Desktop_notifications#Tips_and_tricks
#
# Getting it to build in nixpkgs was fun: it requires the
# deprecated dbus-notify library, which doesn't play nice with
# standard Python tooling

{ pkgs, lib, dbus, fetchpatch, fetchFromGitHub, python38Packages }:

python38Packages.buildPythonApplication rec {
  pname = "notify-send";
  version = "git";
  format = "pyproject";
  src = fetchFromGitHub {
    owner = "phuhl";
    repo = "notify-send.py";
    rev = "0575c79f10d10892c41559dd3695346d16a8b184";
    hash = "sha256:09m15h1yja5x2ihrp92ab3q220mgdcb0k4ld00dccn4krzcn3a7v";
  };

  patchPhase = ''
    sed -i pyproject.toml -e 's/"dbus-python",//'
  '';

  propagatedBuildInputs = with python38Packages; [
    dbus-python pygobject3 setuptools flit pip
  ];
}
