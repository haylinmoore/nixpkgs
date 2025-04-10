{
  lib,
  stdenv,
  fetchFromGitHub,
  blueprint-compiler,
  desktop-file-utils,
  meson,
  ninja,
  pkg-config,
  vala,
  wrapGAppsHook4,
  glib-networking,
  gst_all_1,
  gtk4,
  json-glib,
  libadwaita,
  libgee,
  libsoup_3,
  libxml2,
  sqlite,
  webkitgtk_6_0,
  nix-update-script,
}:

stdenv.mkDerivation rec {
  pname = "cassette";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "Rirusha";
    repo = "Cassette";
    tag = "v${version}";
    hash = "sha256-DXCOrCntOgUPYMVRqC4jDNTFgUjShCBoYQgLtSnuz6U=";
  };

  nativeBuildInputs = [
    blueprint-compiler
    desktop-file-utils
    meson
    ninja
    pkg-config
    vala
    wrapGAppsHook4
  ];

  buildInputs = [
    glib-networking
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gstreamer
    gtk4
    json-glib
    libadwaita
    libgee
    libsoup_3
    libxml2
    sqlite
    webkitgtk_6_0
  ];

  strictDeps = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "GTK4/Adwaita application that allows you to use Yandex Music service on Linux operating systems";
    homepage = "https://github.com/Rirusha/Cassette";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [ averyanalex ];
    platforms = lib.platforms.linux;
    mainProgram = "cassette";
  };
}
