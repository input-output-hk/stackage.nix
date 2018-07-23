{ pkgs    ? import <nixpkgs> {}
, hackage ? import <hackage>
, haskell ? import <haskell> }@args:
let mkPkgSet = path: import ./package-set.nix (args // { lts-def = import path; }); in
{ lts-9_1  = mkPkgSet ./lts-9.1.nix;
  lts-11_2 = mkPkgSet ./lts-11.2.nix;
  lts-11_5 = mkPkgSet ./lts-11.5.nix;
  lts-12_0 = mkPkgSet ./lts-12.0.nix;
  lts-12_1 = mkPkgSet ./lts-12.1.nix;
  lts-12_2 = mkPkgSet ./lts-12.2.nix;

  # nightlies
  lts-2018-04-21 = mkPkgSet ./nightly-2018-04-21.nix;
  lts-2018-05-02 = mkPkgSet ./nightly-2018-05-02.nix;
  lts-2018-06-29 = mkPkgSet ./nightly-2018-06-29.nix;
}
