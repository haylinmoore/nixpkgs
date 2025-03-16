{
  lib,
  stdenv,
  fetchurl,
  unzip
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zorkword";
  version = "10/970824";

  src = fetchurl {
    url = "http://mirror.ifarchive.org/if-archive/infocom/tools/zorkword.zip";
    hash = "sha256-zFd8uzfAF79bNWaxdpYSHHv6/RUXsWutq1kiZSfhpoU=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    unzip
  ];

  patchPhase = ''
    substituteInPlace zorkword.c \
      --replace-fail 'column += printf(buf);' 'column += printf("%s", buf);'
  '';

  NIX_CFLAGS_COMPILE = "-Wno-implicit-int";

  buildPhase = ''
    gcc zorkword.c -o zorkword
  '';

  installPhase = ''
    mkdir -p $out/bin/
    cp zorkword $out/bin/
  '';

  meta = {
    description = "Display vocabulary lists from Infocom adventure game data files";
    homepage = "http://inform-fiction.org/zmachine/ztools.html";
    license = with lib.licenses; [ publicDomain ];
    platforms = with lib.platforms; linux;
    maintainers = with lib.maintainers; [ haylin ];
    mainProgram = "zorkword";
  };
})
