with import <nixpkgs> {  overlays = [ (import ../../overlay.nix) ];  } ;
let crier = callPackage ./. {};
in crier.overrideAttrs(o: {
  CRIER_DEVELOPMENT = "true";
})
