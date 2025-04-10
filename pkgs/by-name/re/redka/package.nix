{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "redka";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "nalgeon";
    repo = "redka";
    tag = "v${version}";
    hash = "sha256-CCTPhcarLFs2wyhu7OqifunVSil2QU61JViY3uTjVg8=";
  };

  vendorHash = "sha256-aX0X6TWVEouo884LunCt+UzLyvDHgmvuxdV0wh0r7Ro=";

  subPackages = [
    "cmd/redka"
    "cmd/cli"
  ];

  ldflags = [ "-X main.version=v${version}" ];

  postInstall = ''
    mv $out/bin/{cli,redka-cli}
  '';

  meta = {
    description = "Redis re-implemented with SQLite";
    homepage = "https://github.com/nalgeon/redka";
    changelog = "https://github.com/nalgeon/redka/releases/tag/${src.rev}";
    maintainers = with lib.maintainers; [ sikmir ];
    license = lib.licenses.bsd3;
  };
}
