{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  wayland,
  wayland-protocols,
  wayland-scanner,
  wlr-protocols,
  libGL,
  bash,
  installExampleScripts ? true,
  makeWrapper,
  pipectl,
  slurp,
  rofi,
  scdoc,
}:

let
  wl-present-binpath = lib.makeBinPath [
    pipectl
    rofi
    slurp
    (placeholder "out")
  ];
in

stdenv.mkDerivation rec {
  pname = "wl-mirror";
  version = "0.17.0";

  src = fetchFromGitHub {
    owner = "Ferdi265";
    repo = "wl-mirror";
    tag = "v${version}";
    hash = "sha256-E8mbCMfmN3key1W3m8YbH1wKa56yESiXujACfKFS/+s=";
  };

  strictDeps = true;
  depsBuildBuild = [ pkg-config ];
  nativeBuildInputs = [
    cmake
    pkg-config
    wayland-scanner
    scdoc
    makeWrapper
  ];
  buildInputs = [
    libGL
    wayland
    wayland-protocols
    wlr-protocols
    bash
  ];

  postPatch = ''
    echo 'v${version}' > version.txt
    substituteInPlace CMakeLists.txt \
      --replace 'WL_PROTOCOL_DIR "/usr' 'WL_PROTOCOL_DIR "${wayland-protocols}' \
      --replace 'WLR_PROTOCOL_DIR "/usr' 'WLR_PROTOCOL_DIR "${wlr-protocols}'
  '';

  cmakeFlags = [
    "-DINSTALL_EXAMPLE_SCRIPTS=${if installExampleScripts then "ON" else "OFF"}"
    "-DINSTALL_DOCUMENTATION=ON"
  ];

  postInstall = lib.optionalString installExampleScripts ''
    wrapProgram $out/bin/wl-present --prefix PATH ":" ${wl-present-binpath}
  '';

  meta = with lib; {
    homepage = "https://github.com/Ferdi265/wl-mirror";
    description = "Simple Wayland output mirror client";
    license = licenses.gpl3;
    maintainers = with maintainers; [ synthetica ];
    platforms = platforms.linux;
  };
}
