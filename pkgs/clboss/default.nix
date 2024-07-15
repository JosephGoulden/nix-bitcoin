{ lib, stdenv, fetchFromGitHub, autoconf-archive, autoreconfHook, pkg-config, curl, libev, sqlite }:

let
  curlWithGnuTLS = curl.override { gnutlsSupport = true; opensslSupport = false; };
in
stdenv.mkDerivation rec {
  pname = "clboss";
  version = "0.13.1";

  src = fetchFromGitHub {
    owner = "ZmnSCPxj";
    repo = "clboss";
    rev = "508a4fe903e1c2c611a025ab8ed8891311c3e715";
    hash = "sha256-rGc4k5IxJfDwTe/OPaPQM5y8hGNAXBRpwGHLxYrE12Y=";
  };

  nativeBuildInputs = [
    autoreconfHook
    autoconf-archive
    pkg-config
    libev
    curlWithGnuTLS
    sqlite
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Automated C-Lightning Node Manager";
    homepage = "https://github.com/ZmnSCPxj/clboss";
    changelog = "https://github.com/ZmnSCPxj/clboss/blob/v${version}/ChangeLog";
    license = licenses.mit;
    maintainers = with maintainers; [ nixbitcoin ];
    platforms = platforms.linux;
  };
}
