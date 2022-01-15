with import <nixpkgs> {} ;
(callPackage ./. {
  megi-call-audio = pkgs.callPackage ../megi-call-audio {};
}).overrideAttrs(o: {
  nativeBuildInputs = o.nativeBuildInputs ++ [ pkgs.sqlite ] ;
})
