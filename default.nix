{ pkgs    ? import <nixpkgs> {}
, hackage ? import <hackage>
, haskell ? import <haskell> }@args:
let
  mkPkgSet = path: (haskell hackage).mkPkgSet pkgs path;
  ltss = import ./ltss.nix mkPkgSet;
  nightlies = import ./nightlies.nix mkPkgSet;
in
ltss // nightlies
