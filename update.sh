#!/bin/bash
# ensure we have the most recent submodules
git submodule foreach git pull origin master
# update lts/nightly descriptions.

# update them all in parallel...
N=$(getconf _NPROCESSORS_ONLN)
for lts in {lts-haskell,stackage-nightly}/*.yaml
do
    $(find $NIX_TOOLS -type f -name "lts-to-nix") $lts > $(basename ${lts%.yaml}.nix) &
    while [[ $(jobs -r -p | wc -l) -gt $N ]]; do
	# can't use `wait -n` on older bash versions.
	# e.g. what ships with macOS High Sierra
	sleep 1;
    done
done
wait
# update nightlies
echo "mkPkgSet: {" > nightlies.nix;
for a in nightly-*.nix; do echo "  \"${a%%.nix}\" = mkPkgSet ./$a;" >> nightlies.nix; done;
echo "}" >> nightlies.nix
# update lts
echo "mkPkgsSet: {" > ltss.nix;
for a in lts-*.nix; do echo "  \"${a%%.nix}\" = mkPkgSet ./$a;" >> ltss.nix; done;
echo "}" >> ltss.nix
