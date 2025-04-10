{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  mono,
  dbus-sharp-1_0,
}:

stdenv.mkDerivation rec {
  pname = "dbus-sharp-glib";
  version = "0.5";

  src = fetchFromGitHub {
    owner = "mono";
    repo = "dbus-sharp-glib";

    tag = "v${version}";
    sha256 = "0z8ylzby8n5sar7aywc8rngd9ap5qqznadsscp5v34cacdfz1gxm";
  };

  nativeBuildInputs = [
    pkg-config
    autoreconfHook
    mono # gmcs
  ];
  buildInputs = [
    mono
    dbus-sharp-1_0
  ];

  dontStrip = true;

  meta = with lib; {
    description = "D-Bus for .NET: GLib integration module";
    platforms = platforms.linux;
    license = licenses.mit;
  };
}
