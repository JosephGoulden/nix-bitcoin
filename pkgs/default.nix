{ pkgs ? import <nixpkgs> {} }:
let self = {
  lightning-charge = pkgs.callPackage ./lightning-charge { };
  nanopos = pkgs.callPackage ./nanopos { };
  spark-wallet = pkgs.callPackage ./spark-wallet { };
  electrs = pkgs.callPackage ./electrs { };
  elementsd = pkgs.callPackage ./elementsd { withGui = false; };
  hwi = pkgs.callPackage ./hwi { };
  pylightning = pkgs.python3Packages.callPackage ./pylightning { };
  liquid-swap = pkgs.python3Packages.callPackage ./liquid-swap { };
  generate-secrets = pkgs.callPackage ./generate-secrets { };
  nixops19_09 = pkgs.callPackage ./nixops { };
  netns-exec = pkgs.callPackage ./netns-exec { };
  lightning-loop = pkgs.callPackage ./lightning-loop { };
  btcpayserver = pkgs.callPackage ./btcpayserver { inherit (self) linkFarmFromDrvs; };
  nbxplorer = pkgs.callPackage ./nbxplorer { inherit (self) linkFarmFromDrvs; };

  # Temporary backport for btcpayserver
  linkFarmFromDrvs = pkgs.linkFarmFromDrvs or self.pinned.nixpkgsUnstable.linkFarmFromDrvs;

  pinned = import ./pinned.nix;

  lib = import ./lib.nix { inherit (pkgs) lib; };
}; in self
