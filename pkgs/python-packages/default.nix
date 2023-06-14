nbPkgs: python3:
let
  # Ignore eval error:
  # `OpenSSL 1.1 is reaching its end of life on 2023/09/11 and cannot
  # be supported through the NixOS 23.05 release cycle.`
  openssl_1_1 = python3.pkgs.pkgs.openssl_1_1.overrideAttrs (old: {
    meta = builtins.removeAttrs old.meta [ "knownVulnerabilities" ];
  });
in
rec {
  pyPkgsOverrides = self: super: let
    inherit (self) callPackage;
    clightningPkg = pkg: callPackage pkg { inherit (nbPkgs.pinned) clightning; };
  in
    {
      coincurve = callPackage ./coincurve {};
      txzmq = callPackage ./txzmq {};

      pyln-client = clightningPkg ./pyln-client;
      pyln-proto = clightningPkg ./pyln-proto;
      pyln-bolt7 = clightningPkg ./pyln-bolt7;
      pylightning = clightningPkg ./pylightning;

      # bitstring 3.1.9, required by pyln-proto
      bitstring = callPackage ./specific-versions/bitstring.nix {};

      # Packages only used by joinmarket
      bencoderpyx = callPackage ./bencoderpyx {};
      chromalog = callPackage ./chromalog {};
      python-bitcointx = callPackage ./python-bitcointx {
        inherit (nbPkgs) secp256k1;
        openssl = openssl_1_1;
      };
      runes = callPackage ./runes {};
      sha256 = callPackage ./sha256 {};
    };

  # Joinmarket requires a custom package set because it uses older versions of Python pkgs
  pyPkgsOverridesJoinmarket = self: super: let
    inherit (self) callPackage;
    joinmarketPkg = pkg: callPackage pkg { inherit (nbPkgs.joinmarket) version src; };
  in
    (pyPkgsOverrides self super) // {
      joinmarketbase = joinmarketPkg ./jmbase;
      joinmarketclient = joinmarketPkg ./jmclient;
      joinmarketbitcoin = joinmarketPkg ./jmbitcoin;
      joinmarketdaemon = joinmarketPkg ./jmdaemon;

      ## Specific versions of packages that already exist in nixpkgs

      # cryptography 3.3.2, required by joinmarketdaemon
      cryptography = callPackage ./specific-versions/cryptography {
        openssl = openssl_1_1;
        cryptography_vectors = callPackage ./specific-versions/cryptography/vectors.nix {};
      };

      # autobahn 20.12.3, required by joinmarketclient
      autobahn = callPackage ./specific-versions/autobahn.nix {};

      # pyopenssl 21.0.0, required by joinmarketdaemon
      pyopenssl = callPackage ./specific-versions/pyopenssl.nix {};

      # txtorcon 22.0.0, required by joinmarketdaemon
      txtorcon = callPackage ./specific-versions/txtorcon.nix {};
    };

  nbPython3Packages = (python3.override {
    packageOverrides = pyPkgsOverrides;
  }).pkgs;

  nbPython3PackagesJoinmarket = (python3.override {
    packageOverrides = pyPkgsOverridesJoinmarket;
  }).pkgs;
}
