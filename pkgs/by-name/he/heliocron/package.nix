{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "heliocron";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "mfreeborn";
    repo = "heliocron";
    tag = "v${version}";
    hash = "sha256-5rzFz29Bpy2GR6bEt2DdCq9RtpdcY3SK/KnZrBrHUvk=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-as1rMyLqK0Z+UrO6B7Fzn2nNQM0xRrLoEPd2WlANxe8=";

  meta = {
    description = "Execute tasks relative to sunset, sunrise and other solar events";
    longDescription = "A simple command line application that integrates with `cron` to execute tasks relative to sunset, sunrise and other such solar events.";
    homepage = "https://github.com/mfreeborn/heliocron";
    changelog = "https://github.com/mfreeborn/heliocron/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ TheColorman ];
    mainProgram = "heliocron";
    platforms = lib.platforms.linux;
  };
}
