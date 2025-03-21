{
  lib,
  bundlerApp,
  bundlerUpdateScript,
  binutils,
}:

bundlerApp {
  pname = "fpm";
  gemdir = ./.;
  exes = [ "fpm" ];

  buildInputs = [
    binutils
  ];

  passthru.updateScript = bundlerUpdateScript "fpm";

  meta = with lib; {
    description = "Tool to build packages for multiple platforms with ease";
    homepage = "https://github.com/jordansissel/fpm";
    license = licenses.mit;
    maintainers = with maintainers; [
      manveru
      nicknovitski
    ];
    platforms = platforms.unix;
    mainProgram = "fpm";
  };
}
