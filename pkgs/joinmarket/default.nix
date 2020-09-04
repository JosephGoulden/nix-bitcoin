{ stdenv, fetchurl, nixpkgsUnstablePath, python3 }:

let
  version = "0.7.0";
  src = fetchurl {
    url = "https://github.com/JoinMarket-Org/joinmarket-clientserver/archive/v${version}.tar.gz";
    sha256 = "0ha73n3y5lykyj3pl97a619sxd2zz0lb32s5c61wm0l1h47v9l1g";
  };

  python = python3.override {
    packageOverrides = self: super: let
      joinmarketPkg = pkg: self.callPackage pkg { inherit version src; };
      unstablePyPkg = pkgName:
        self.callPackage "${nixpkgsUnstablePath}/pkgs/development/python-modules/${pkgName}";
    in {
      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      chromalog = self.callPackage ./chromalog {};
      bencoderpyx = self.callPackage ./bencoderpyx {};
      coincurve = self.callPackage ./coincurve {};
      urldecode = self.callPackage ./urldecode {};
      python-bitcointx = self.callPackage ./python-bitcointx {};
      secp256k1 = self.callPackage ./secp256k1 {};

      txtorcon = unstablePyPkg "txtorcon" {};
    };
  };

  runtimePackages = with python.pkgs; [
    joinmarketbase
    joinmarketclient
    joinmarketbitcoin
    joinmarketdaemon
  ];

  pythonEnv = python.withPackages (_: runtimePackages);
in
stdenv.mkDerivation {
  pname = "joinmarket";
  inherit version src;

  buildInputs = [ pythonEnv ];

  buildCommand = ''
    mkdir -p $src-unpacked
    tar xzf $src --strip 1 -C $src-unpacked
    mkdir -p $out/{bin,src}

    # add-utxo.py -> bin/jm-add-utxo
    cpBin() {
      cp $src-unpacked/scripts/$1 $out/bin/jm-''${1%.py}
    }
    cp $src-unpacked/scripts/joinmarketd.py $out/bin/joinmarketd
    cpBin add-utxo.py
    cpBin convert_old_wallet.py
    cpBin receive-payjoin.py
    cpBin sendpayment.py
    cpBin sendtomany.py
    cpBin tumbler.py
    cpBin wallet-tool.py
    cpBin yg-privacyenhanced.py

    chmod +x -R $out/bin
    patchShebangs $out/bin
  '';

  passthru = {
      inherit python runtimePackages pythonEnv;
  };
}
