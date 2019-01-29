#!/usr/bin/env bash
# ensure we have the most recent submodules
git submodule foreach git pull origin master
# update lts/nightly descriptions.

# update them all in parallel...
N=3
for lts in {lts-haskell,stackage-nightly}/*.yaml
do
    $(find -L $NIX_TOOLS -type f -name "lts-to-nix") $lts > $(basename ${lts%.yaml}.nix) &
    while [[ $(jobs -r -p | wc -l) -gt $N ]]; do
	# can't use `wait -n` on older bash versions.
	# e.g. what ships with macOS High Sierra
	wait -n;
    done
done

# update nightlies
echo "{" > nightlies.nix;
for a in nightly-*.nix; do echo "  \"${a%%.nix}\" = import ./$a;" >> nightlies.nix; done;
echo "}" >> nightlies.nix
# update lts
echo "{" > ltss.nix;
for a in lts-*.nix; do echo "  \"${a%%.nix}\" = import ./$a;" >> ltss.nix; done;
echo "}" >> ltss.nix
