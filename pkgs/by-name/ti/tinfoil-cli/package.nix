{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "tinfoil-cli";
  version = "0.0.5";

  src = fetchFromGitHub {
    owner = "tinfoilsh";
    repo = "tinfoil-cli";
    rev = "v${version}";
    hash = "sha256-rd1aD6M593mRL2hCxZe7cS8PXiYBma2E6AG7oaLjfJs=";
  };

  vendorHash = "sha256-PGtifBDWDws/EVwgvjlzV49Xlcb1eO0HQEMDu3srbYY=";

  doCheck = false;

  postInstall = ''
    mv $out/bin/tinfoil-cli $out/bin/tinfoil
  '';

  meta = {
    description = "Command-line interface for making verified HTTP requests to Tinfoil enclaves and validating attestation documents";
    homepage = "https://github.com/tinfoilsh/tinfoil-cli";
    license = lib.licenses.gpl3;
    maintainers = [ lib.maintainers.haylin ];
    mainProgram = "tinfoil";
  };
}
