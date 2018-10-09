{ pkgs    ? import <nixpkgs> {}
, hackage ? import <hackage>
, haskell ? import <haskell> }@args:
let
  mkPkgSet = path: import ./package-set.nix (args // { lts-def = import path; });
  ltss = import ./ltss.nix mkPkgsSet;
  nightlies = import ./nightlies.nix mkPkgSet;
in
ltss // nightlies
