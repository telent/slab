with import <nixpkgs> {} ;
let crier = callPackage ./. {};
in crier.overrideAttrs(o: {
  CRIER_DEVELOPMENT = "true";
})
