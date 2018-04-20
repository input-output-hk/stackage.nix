{ lts-9_1 = import ./package-set.nix { lts-def = import ./lts-9.1.nix; };
  lts-11_5 = import ./package-set.nix { lts-def = import ./lts-11.5.nix; };
}
