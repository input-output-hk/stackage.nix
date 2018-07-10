{ pkgs ? import <nixpkgs> {} }:
{ lts-9_1  = import ./package-set.nix { inherit pkgs; lts-def = import ./lts-9.1.nix; };
  lts-11_2 = import ./package-set.nix { inherit pkgs; lts-def = import ./lts-11.2.nix; };
  lts-11_5 = import ./package-set.nix { inherit pkgs; lts-def = import ./lts-11.5.nix; };
  # nightlies
  lts-2018-04-21 = import ./package-set.nix { inherit pkgs; lts-def = import ./nightly-2018-04-21.nix; };
  lts-2018-05-02 = import ./package-set.nix { inherit pkgs; lts-def = import ./nightly-2018-05-02.nix; };
  lts-2018-06-29 = import ./package-set.nix { inherit pkgs; lts-def = import ./nightly-2018-06-29.nix; };  
}
