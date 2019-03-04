#!/usr/bin/env bash
# ensure we have the most recent submodules
git submodule foreach git pull origin master
# update lts/nightly descriptions.

# update them all in parallel...
for lts in {lts-haskell,stackage-nightly}/*.yaml
do
  if [[ ! -f $(basename ${lts%.yaml}.nix) ]]; then
    $(find -L $NIX_TOOLS -type f -name "lts-to-nix") $lts > $(basename ${lts%.yaml}.nix)
  fi
done
# update nightlies
echo "{" > nightlies.nix;
for a in nightly-*.nix; do echo "  \"${a%%.nix}\" = import ./$a;" >> nightlies.nix; done;
echo "}" >> nightlies.nix
# update lts
echo "{" > ltss.nix;
for a in $(ls lts-*.nix | sort -Vtx -k 1,1); do echo "  \"${a%%.nix}\" = import ./$a;" >> ltss.nix; done;
echo "}" >> ltss.nix
