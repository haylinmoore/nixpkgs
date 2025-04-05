{ lib
, stdenv
, fetchgit
, cmake
, pkg-config
, lua5_1
, json_c
, libubox-wolfssl
, ubus
, libxcrypt
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "uhttpd";
  version = "0-unstable-2025-04-05";

  src = fetchgit {
    url = "https://git.openwrt.org/project/uhttpd.git";
    rev = "3d6f01b9d01a6ffa9e73705112cd51bfd98ec2fc";
    hash = "sha256-WT2mqYppQgr07w+z0V0hfttQK77I2tn73/dUyeEcoSk=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    lua5_1
    json_c
    libubox-wolfssl
    ubus
    libxcrypt
  ];

  cmakeFlags = [
    "-DUCODE_SUPPORT=off"
    "-DTLS_SUPPORT=on"
    "-DLUA_SUPPORT=on"
  ];

  NIX_LDFLAGS = "-lcrypt";

  # Patch the CMakeLists.txt to install the plugins to the correct location
  postPatch = ''
    # Ensure plugins are installed to the output directory
    sed -i 's|LIBRARY DESTINATION lib/uhttpd/|LIBRARY DESTINATION lib/uhttpd/ COMPONENT plugins|' CMakeLists.txt
  '';

  installPhase = ''
    runHook preInstall

    # Install the main executable
    install -Dm755 uhttpd $out/bin/uhttpd

    # Install the Lua plugin
    install -Dm755 uhttpd_lua.so $out/lib/uhttpd/uhttpd_lua.so
    install -Dm755 uhttpd_ubus.so $out/lib/uhttpd/uhttpd_ubus.so

    # Create a wrapper script that sets the plugin path
    mv $out/bin/uhttpd $out/bin/.uhttpd-unwrapped
    cat > $out/bin/uhttpd << EOF
    #!/bin/sh
    export LD_LIBRARY_PATH=$out/lib/uhttpd:\$LD_LIBRARY_PATH
    exec $out/bin/.uhttpd-unwrapped "\$@"
    EOF
    chmod +x $out/bin/uhttpd

    runHook postInstall
  '';

  meta = {
    description = "Tiny HTTP server from OpenWrt project";
    homepage = "https://openwrt.org/docs/guide-user/services/webserver/uhttpd";
    license = lib.licenses.isc;
    platforms = lib.platforms.unix;
    maintainers = [ lib.maintainers.haylin ];
    mainProgram = "uhttpd";
  };
})
