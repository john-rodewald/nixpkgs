{
  lib,
  stdenv,
  fetchurl,
  zlib,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "woff-tools";
  version = "2009.10.04";

  src = fetchurl {
    # Reference implementation from the original WOFF authors, as distributed
    # by Debian (the original mozilla.org download location is gone).
    url = "http://deb.debian.org/debian/pool/main/w/woff-tools/woff-tools_${finalAttrs.version}.orig.tar.gz";
    hash = "sha256-9JMGnGE/XoH1v4n54x61E5g+TSkOP6uppt9Jo/B8J8U=";
  };

  buildInputs = [ zlib ];

  buildPhase = ''
    runHook preBuild

    $CC -O2 -o sfnt2woff sfnt2woff.c woff.c -lz
    $CC -O2 -o woff2sfnt woff2sfnt.c woff.c -lz

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 sfnt2woff woff2sfnt -t $out/bin

    runHook postInstall
  '';

  meta = {
    description = "Reference tools for converting between SFNT (TTF/OTF) and WOFF fonts";
    homepage = "https://packages.debian.org/source/sid/woff-tools";
    license = with lib.licenses; [
      mpl11 # or
      gpl2Plus # or
      lgpl21Plus
    ];
    maintainers = [ ];
    platforms = lib.platforms.unix;
  };
})
