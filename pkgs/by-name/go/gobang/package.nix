{
  lib,
  rustPlatform,
  fetchFromGitHub,
  stdenv,
  darwin,
}:
let
  version = "0.1.0-alpha.5";
in
rustPlatform.buildRustPackage {
  pname = "gobang";
  inherit version;

  src = fetchFromGitHub {
    owner = "tako8ki";
    repo = "gobang";
    tag = "v${version}";
    hash = "sha256-RinfQhG7iCp0Xcs9kLs3I2/wjkJEgCjFYe3mS+FY9Ak=";
  };

  cargoPatches = [ ./update-sqlx.patch ];

  useFetchCargoVendor = true;
  cargoHash = "sha256-K9oo0QrqcPNdV7WMlgSCVc+7AVfoyDkovvJLqKJPvTQ=";

  buildInputs =
    with darwin.apple_sdk.frameworks;
    lib.optionals stdenv.hostPlatform.isDarwin [
      CoreFoundation
      Security
      SystemConfiguration
    ];

  meta = {
    description = "Cross-platform TUI database management tool written in Rust";
    homepage = "https://github.com/tako8ki/gobang";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ figsoda ];
  };
}
