#!/usr/bin/env bash
# ensure we have the most recent submodules
git submodule foreach git pull origin master
# update lts/nightly descriptions.

curl -L -O https://raw.githubusercontent.com/commercialhaskell/stackage-content/master/stack/global-hints.yaml
# update them all in parallel...
LTSS=$(find stackage-snapshots -name "*.yaml")
if [ -z LTS_TO_NIX ]; then
  LTS_TO_NIX=$(find -L "$NIX_TOOLS" -type f -name "lts-to-nix")
fi

for lts in $LTSS
do
  nix=$(echo "$lts" | awk -F/ '{ if ($2 == "lts") { printf "lts-%d.%d.nix", $3, $4 } else { printf "nightly-%04d-%02d-%02d.nix", $3, $4, $5 } }')
  if [[ ! -f "$nix" ]]; then
    GLOBAL_HINTS=./global-hints.yaml "$LTS_TO_NIX" "$lts" > "$nix"
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
