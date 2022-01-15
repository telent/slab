{ stdenv }:
stdenv.mkDerivation {
  name = "call-audio";
  makeFlags = ["call-audio"];
  src = ./.;
  installPhase = ''
    mkdir -p $out/bin
    cp call-audio $out/bin
  '';
}
