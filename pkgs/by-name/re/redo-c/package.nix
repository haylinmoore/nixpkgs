{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation rec {
  pname = "redo-c";
  version = "0.3";

  src = fetchFromGitHub {
    owner = "leahneukirchen";
    repo = "redo-c";
    tag = "v${version}";
    sha256 = "sha256-oZcaBgESIaD7/SUBE7luh7axucKTEzXPVkQAQs2NCXE=";
  };

  postPatch = ''
    cp '${./Makefile}' Makefile
  '';

  meta = with lib; {
    description = "Implementation of the redo build system in portable C with zero dependencies";
    homepage = "https://github.com/leahneukirchen/redo-c";
    license = licenses.cc0;
    platforms = platforms.all;
    maintainers = with maintainers; [ ck3d ];
  };
}
