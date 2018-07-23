#!/bin/bash
git submodule foreach git pull origin master
for lts in {lts-haskell,stackage-nightly}/*.yaml; do $(find $NIX_TOOLS -type f -name "lts-to-nix") $lts > $(basename ${lts%.yaml}.nix); done
