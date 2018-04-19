{ lts-def ? import ./lts-11.5.nix
, hackage ? import <hackage/all-cabal-expr.nix>
, hashes  ? import <hackage/all-cabal-hashes.nix> }:

let
  lts = lts-def hackage;

  pkgs = import <nixpkgs> {};
  driver = import ./nix/driver.nix;
  host-map = import ./nix/host-map.nix;

  toGenericPackage = stackPkgs: name: path:
    let expr = driver { cabalexpr = import path;
             pkgs = pkgs // { haskellPackages = stackPkgs; };
             inherit (host-map pkgs.stdenv) os arch; };
     in pkgs.haskellPackages.callPackage expr {};

in let stackPackages = pkgs.lib.mapAttrs (toGenericPackage stackPackages) lts;
   in  stackPackages
