with import <nixpkgs> {} ;
(callPackage ./. {
}).overrideAttrs(o: {
  GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
  nativeBuildInputs = o.nativeBuildInputs ++
                      [  ] ;
})
