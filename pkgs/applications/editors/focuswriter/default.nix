{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  cmake,
  hunspell,
  qtbase,
  qtmultimedia,
  qttools,
  qt5compat,
  qtwayland,
  wrapQtAppsHook,
}:

stdenv.mkDerivation rec {
  pname = "focuswriter";
  version = "1.8.11";

  src = fetchFromGitHub {
    owner = "gottcode";
    repo = "focuswriter";
    tag = "v${version}";
    hash = "sha256-oivhrDF3HikbEtS1cOlHwmQYNYf3IkX+gQGW0V55IWU=";
  };

  nativeBuildInputs = [
    pkg-config
    cmake
    qttools
    wrapQtAppsHook
  ];
  buildInputs = [
    hunspell
    qtbase
    qtmultimedia
    qt5compat
    qtwayland
  ];

  installFlags = [ "INSTALL_ROOT=$(out)" ];

  meta = with lib; {
    description = "Simple, distraction-free writing environment";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [
      madjar
      kashw2
    ];
    platforms = platforms.linux;
    homepage = "https://gottcode.org/focuswriter/";
    mainProgram = "focuswriter";
  };
}
