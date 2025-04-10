{
  lib,
  stdenv,
  fetchFromGitHub,
  ncurses,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "netproc";
  version = "0.6.6";

  src = fetchFromGitHub {
    owner = "berghetti";
    repo = "netproc";
    tag = finalAttrs.version;
    hash = "sha256-OQWlFwCga33rTseLeO8rAd+pkLHbSNf3YI5OSwrdIyk=";
  };

  buildInputs = [ ncurses ];

  installFlags = [ "prefix=$(out)" ];

  meta = with lib; {
    description = "Tool to monitor network traffic based on processes";
    homepage = "https://github.com/berghetti/netproc";
    license = licenses.gpl3;
    mainProgram = "netproc";
    maintainers = [ maintainers.azuwis ];
    platforms = platforms.linux;
  };
})
