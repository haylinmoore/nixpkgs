{
  lib,
  asouldocs,
  buildGoModule,
  fetchFromGitHub,
  testers,
}:

buildGoModule rec {
  pname = "asouldocs";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "asoul-sig";
    repo = "asouldocs";
    tag = "v${version}";
    hash = "sha256-ctRE7aF3Qj+fI/m0CuLA6x7E+mY6s1+UfBJI5YFea4g=";
  };

  vendorHash = "sha256-T/KLiSK6bxXGkmVJ5aGrfHTUfLs/ElGyWSoCL5kb/KU=";

  passthru.tests.version = testers.testVersion {
    package = asouldocs;
    command = "asouldocs --version";
  };

  meta = with lib; {
    description = "Web server for multi-language, real-time synchronization and searchable documentation";
    homepage = "https://asouldocs.dev/";
    license = licenses.mit;
    maintainers = with maintainers; [ anthonyroussel ];
    mainProgram = "asouldocs";
  };
}
