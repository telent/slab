with import <nixpkgs> {} ;
callPackage ./. {
  megi-call-audio = pkgs.callPackage ../megi-call-audio {};
}
