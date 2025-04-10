{
  stdenv,
  lib,
  fetchFromGitHub,
  cmake,
  pkg-config,
  doxygen,
  qt6Packages,
  dtk6core,
  librsvg,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "dtk6gui";
  version = "6.0.24";

  src = fetchFromGitHub {
    owner = "linuxdeepin";
    repo = "dtk6gui";
    tag = finalAttrs.version;
    hash = "sha256-Ybi68lTSUJpAipx92JF7wj6y+GTYDodJKRCVFhfnBvQ=";
  };

  patches = [
    ./fix-pkgconfig-path.patch
    ./fix-pri-path.patch
  ];

  postPatch = ''
    substituteInPlace src/util/dsvgrenderer.cpp \
      --replace-fail 'QLibrary("rsvg-2", "2")' 'QLibrary("${lib.getLib librsvg}/lib/librsvg-2.so")'
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    doxygen
    qt6Packages.qttools
    qt6Packages.wrapQtAppsHook
  ];

  buildInputs = [
    qt6Packages.qtbase
    qt6Packages.qtwayland
    librsvg
  ];

  propagatedBuildInputs = [
    dtk6core
    qt6Packages.qtimageformats
  ];

  cmakeFlags = [
    "-DDTK_VERSION=${finalAttrs.version}"
    "-DBUILD_DOCS=ON"
    "-DMKSPECS_INSTALL_DIR=${placeholder "out"}/mkspecs/modules"
    "-DQCH_INSTALL_DESTINATION=${placeholder "doc"}/share/doc"
  ];

  preConfigure = ''
    # qt.qpa.plugin: Could not find the Qt platform plugin "minimal"
    # A workaround is to set QT_PLUGIN_PATH explicitly
    export QT_PLUGIN_PATH=${lib.getBin qt6Packages.qtbase}/${qt6Packages.qtbase.qtPluginPrefix}
  '';

  outputs = [
    "out"
    "dev"
    "doc"
  ];

  postFixup = ''
    for binary in $out/libexec/dtk6/DGui/bin/*; do
      wrapQtApp $binary
    done
  '';

  meta = {
    description = "Deepin Toolkit, gui module for DDE look and feel";
    homepage = "https://github.com/linuxdeepin/dtk6gui";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
    maintainers = lib.teams.deepin.members;
  };
})
