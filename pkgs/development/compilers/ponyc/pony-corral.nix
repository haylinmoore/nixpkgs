{
  lib,
  stdenv,
  fetchFromGitHub,
  ponyc,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "corral";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "ponylang";
    repo = "corral";
    tag = finalAttrs.version;
    hash = "sha256-arcMtCSbXFLBT2ygdj44UKMdGStlgHyiBgt5xZpPRhs=";
  };

  strictDeps = true;

  nativeBuildInputs = [ ponyc ];

  installFlags = [
    "prefix=${placeholder "out"}"
    "install"
  ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Corral is a dependency management tool for ponylang (ponyc)";
    homepage = "https://www.ponylang.io";
    changelog = "https://github.com/ponylang/corral/blob/${finalAttrs.version}/CHANGELOG.md";
    license = licenses.bsd2;
    maintainers = with maintainers; [
      redvers
      numinit
    ];
    inherit (ponyc.meta) platforms;
  };
})
