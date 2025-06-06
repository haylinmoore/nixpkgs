{
  jitSupport,
  lib,
  llvm,
  nixosTests,
  pg-dump-anon,
  postgresql,
  postgresqlBuildExtension,
  runtimeShell,
}:

postgresqlBuildExtension {
  pname = "postgresql_anonymizer";

  inherit (pg-dump-anon) version src;

  nativeBuildInputs = lib.optional jitSupport llvm;

  # Needs to be after postInstall, where removeNestedNixStore runs
  preFixup = ''
    cat >$out/bin/pg_dump_anon.sh <<'EOF'
    #!${runtimeShell}
    echo "This script is deprecated by upstream. To use the new script,"
    echo "please install pkgs.pg-dump-anon."
    exit 1
    EOF
  '';

  passthru.tests = nixosTests.postgresql.anonymizer.passthru.override postgresql;

  meta = lib.getAttrs [ "homepage" "teams" "license" ] pg-dump-anon.meta // {
    description = "Extension to mask or replace personally identifiable information (PII) or commercially sensitive data from a PostgreSQL database";
  };
}
