{ stdenv, lib, fetchurl, python3, nbPython3Packages, pkgs }:

let
  version = "0.8.0-bcfa7eb";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/bcfa7eb4ea3ca51b7ecae9aebe65c634a4ab8b0e.tar.gz";
    sha256 = "05akzaxi2vqh3hln6qkr6frfas9xd0d95xa3wd56pj8bzknd410m";
  };

  runtimePackages = with nbPython3Packages; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
  ];

  pythonEnv = python3.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  # Convert links from root-relative to relative to allow hosting ob-watcher with an
  # arbitrary URL path prefix
  patchPhase = ''
    sed -i \
      -e 's|href="/"|href="."|g' \
      -e 's|href="/|href="|g' \
      scripts/obwatch/orderbook.html
  '';

  installPhase = ''
    mkdir -p $out/bin

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp scripts/$1 $out/bin/jm-''${1%.py}
    }

    cp scripts/joinmarketd.py $out/bin/joinmarketd
    cp scripts/obwatch/ob-watcher.py $out/bin/jm-ob-watcher
    cpBin add-utxo.py
    cpBin convert_old_wallet.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py
    cpBin genwallet.py

    chmod +x -R $out/bin
    patchShebangs $out/bin

    # This file must be placed in the same dir as ob-watcher
    cp scripts/obwatch/orderbook.html $out/bin/orderbook.html
  '';
}
