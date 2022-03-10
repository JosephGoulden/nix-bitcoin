{ lib, fetchFromGitHub, buildGoModule, lndBackend ? false }:

buildGoModule rec {
  pname = "peerswap-${if lndBackend then "lnd" else "clightning"}";
  version = "0.2.0-beta";

  src = fetchFromGitHub {
    repo = "peerswap";
    owner = "sputn1ck";
    rev = "d37d4be0be7899e48694068f03c1b02fde1734a0";
    sha256 = "sha256:1axmxrk3svrzpg18sp2c21x7bqakhk3hszz1smpy6pc1x3s7hfsh";
  };

  subPackages = if lndBackend then
    [ "cmd/peerswaplnd/peerswapd" "cmd/peerswaplnd/pscli" ]
  else
    # clightning
    [ "cmd/peerswap" ];

  vendorSha256 = "sha256:13jgk2r8ac2vxrs10xjhilp0x1qvjjgs6knkhf67bmsbx3n9abnl";
  proxyVendor = true;

  meta = with lib; {
    description = "P2P lightning channel rebalancing using lightning<->on-chain atomic swaps";
    homepage = "https://peerswap.dev";
    maintainers = with maintainers; [ sputn1ck ];
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
