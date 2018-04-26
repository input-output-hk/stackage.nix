{ lts-def
, pkgs    ? import <nixpkgs> {}
, hackage ? import <hackage>
, haskell ? import <haskell> }:

{ extraDeps ? hsPkgs: {} }:
let

  # packages that we must never try to reinstal.
  nonReinstallablePkgs = [ "rts" "ghc" "ghc-prim" "integer-gmp" "integer-simple" "base" ];

  hackagePkgs = with pkgs.lib;
                let shippedPkgs = filterAttrs (n: _: builtins.elem n nonReinstallablePkgs)
                                   (mapAttrs (name: version: { ${version} = null; })
                                     (lts-def {}).compiler.packages);
                in recursiveUpdate hackage.exprs shippedPkgs;

  # We may depend on packages shipped with ghc, or need to rebuild them.
  ghcPackages = pkgs.lib.mapAttrs (name: version: hackagePkgs.${name}.${version}) (lts-def {}).compiler.packages;

  # Thus the final package set in our augmented (extrDeps) lts set is the following:
  ltsPkgs = ghcPackages
         // (lts-def hackagePkgs).packages
         // extraDeps hackagePkgs;

  driver = haskell.compat.driver;
  host-map = haskell.compat.host-map;


  # compiler this lts set is built against.
  compiler = pkgs.haskell.packages.${(lts-def {}).compiler.nix-name};

  # This is a tiny bit better than doJailbreak.
  #
  # We essentially *know* the dependencies, and with the
  # full cabal file representation, we also know all the
  # flags.  As such we can sidestep the solver.
  #
  # Pros:
  #  - no need for doJailbreak
  #    - no need for jailbreak-cabal to be built with
  #      Cabal2 if the cabal file requires it.
  #  - no reliance on --allow-newer, which only made
  #    a very short lived appearance in Cabal.
  #    (Cabal-2.0.0.2 -- Cabal-2.2.0.0)
  #
  # Cons:
  #  - automatic flag resolution won't happen and will
  #    have to be hard coded.
  #
  # Ideally we'd just inspect the haskell*Depends fields
  # we feed the builder. However because we null out the
  # lirbaries ghc ships (e.g. base, ghc, ...) this would
  # result in an incomplete --dependency=<name>=<name>-<version>
  # set and not lead to the desired outcome.
  #
  # If we could still have base, etc. not nulled, but
  # produce some virtual derivation, that might allow us
  # to just use the haskell*Depends fields to extract the
  # name and version for each dependency.
  #
  # Ref: https://github.com/haskell/cabal/issues/3163#issuecomment-185833150
  # ---
  # ghc-pkg should be ${ghcCommand}-pkg; and --package-db
  # should better be --${packageDbFlag}; but we don't have
  # those variables in scope.
  doExactConfig = pkg: pkgs.haskell.lib.overrideCabal pkg (drv: {
    # TODO: need to run `ghc-pkg field <pkg> id` over all `--dependency`
    #       values.  Should we encode the `id` in the nix-pkg as well?
    preConfigure = (drv.preConfigure or "") + ''
    configureFlags+=" --exact-configuration"
    globalPackages=$(ghc-pkg list --global --simple-output)
    localPackages=$(ghc-pkg --package-db="$packageConfDir" list --simple-output)
    for pkg in $globalPackages; do
      pkgName=''${pkg%-*}
      if [ "$pkgName" != "rts" ]; then
        if [[ " ${pkgs.lib.concatStringsSep " " nonReinstallablePkgs} " =~ " $pkgName " ]]; then
            configureFlags+=" --dependency="''${pkg%-*}=$pkg
        fi
      fi
    done
    for pkg in $localPackages; do
      configureFlags+=" --dependency="''${pkg%-*}=$pkg
    done
    #echo "<<< <<< <<<"
    #echo ''${configureFlags}
    configureFlags=$(for flag in ''${configureFlags};do case "X''${flag}" in
          X--dependency=*)
            pkgId=$(ghc-pkg --package-db="$packageConfDir" field ''${flag##*=} id || ghc-pkg --global field ''${flag##*=} id)
            echo ''${flag%=*}=$(echo $pkgId | awk -F' ' '{ print $2 }')
            ;;
          *) echo ''${flag};;
          esac; done)
    #echo "--- --- ---"
    #echo ''${configureFlags}
    #echo ">>> >>> >>>"
'';
  });
  doAllowNewer = pkg: pkgs.haskell.lib.appendConfigureFlag pkg "--allow-newer";


  # fast -- the logic is as follows:
  #  - test are often broken and we have a curated set
  #    thus, let us assume we don't need no tests. (also time consuming)
  #  - haddocks are not used, and sometimes fail.  (also time consuming)
  #  - The curated set has proper version bounds, so we can just
  #    jailbreak (--allow-newer) -- THIS SHOULD BE FIXED VIA --exact-config!
  fast = drv: with pkgs.haskell.lib;
              doExactConfig
               (disableLibraryProfiling
                (disableExecutableProfiling
                 (dontHaddock
                  (dontCheck drv))));

  toGenericPackage = stackPkgs: args: name: path:
    if path == null then null else
    let expr = driver { cabalexpr = import path;
             pkgs = pkgs // { haskellPackages = stackPkgs; }
                  # haskell lib -> nix lib mapping
                  // { crypto = pkgs.openssl;
                       "c++" = null; # no libc++
                       ssl = pkgs.openssl;
                       z = pkgs.zlib;
                       };
             inherit (host-map pkgs.stdenv) os arch;
             version = compiler.ghc.version; };
     # Use `callPackage` from the `compiler` here, to get the
     # right compiler.
     in compiler.callPackage expr args;

in let stackPackages =
       (let p = (pkgs.lib.mapAttrs (toGenericPackage stackPackages {}) ltsPkgs)
              // { cassava = toGenericPackage stackPackages
                    { flags = { bytestring--lt-0_10_4 = false; }; }
                    "cassava" ltsPkgs.cassava;
                   time-locale-compat = toGenericPackage stackPackages
                     { flags = { old-locale = false; }; }
                     "time-locale-compat" ltsPkgs.time-locale-compat;
                 }
              ;
         in (pkgs.lib.mapAttrs (_: v: if v == null then null else fast v) p) // (with pkgs.haskell.lib;
            { # skip checks to break recursion.
              # nanospec = dontCheck p.nanospec;
              # hspec    = dontCheck p.hspec;
              # hspec-core = dontCheck p.hspec-core;
              # hspec-discover = dontCheck p.hspec-discover;
              # tasty    = dontCheck p.tasty;
              # colour   = dontCheck p.colour;
              # text     = dontCheck p.text;
              # clock    = dontCheck p.clock;
              # text-short = dontCheck p.text-short;
              # scientific = dontCheck p.scientific;
              # integer-logarithms = dontCheck p.integer-logarithms;
              # hashable = dontCheck p.hashable;
              # test-framework = doJailbreak (dontCheck p.test-framework);
              # unordered-containers = dontCheck p.unordered-containers;
              # # jailbreak
              # old-locale = doJailbreak p.old-locale;
              # pcre-light = doJailbreak p.pcre-light;
              # mtl        = doJailbreak p.mtl;
              # utf8-string = doJailbreak p.utf8-string;
              # tagged     = appendConfigureFlag p.tagged "--allow-newer";
              # HUnit      = appendConfigureFlag p.HUnit  "--allow-newer";
              # test-framework-hunit = appendConfigureFlag p.test-framework-hunit "--allow-newer";
              # build-vector = appendConfigureFlag p.build-vector "--allow-newer";
              # vector = appendConfigureFlag p.vector "--allow-newer";
              # uuid-types = appendConfigureFlag p.uuid-types "--allow-newer";
              # cassava = doJailbreak p.cassava;
              # # attoparsec is broken?
              # attoparsec = dontCheck (appendConfigureFlag p.attoparsec "--allow-newer");
              # old-time   = doJailbreak p.old-time;
              # # no haddock (haddock: No input file(s).)
              # bytestring-builder = dontHaddock p.bytestring-builder;
              # nats = dontHaddock p.nats;

              # # cardano
              # mwc-random = dontCheck p.mwc-random;
              # HTTP = dontCheck p.HTTP;
              # http-streams = dontCheck p.http-streams;
              # options = dontCheck p.options;
              # system-filepath = dontCheck p.system-filepath;
              # time-locale-compat = doJailbreak p.time-locale-compat;
              # fail = dontHaddock p.fail;
              # extra = dontCheck p.extra;
              # xmlgen = dontCheck p.xmlgen;
              # # network-transport-tests has invalid
              # # bounds: network-transport >=0.4.1.0 && <0.5
              # network-transport-inmemory = dontCheck p.network-transport-inmemory;
              # network-transport-tcp = dontCheck p.network-transport-tcp;

              # # HUnit version missmatch
              # parsec = dontCheck p.parsec;
              # lifted-base = dontCheck p.lifted-base;
              # concurrent-extra = dontCheck p.concurrent-extra;
              # lzma = dontCheck p.lzma;
              # uuid = dontCheck p.uuid;

              # either = doJailbreak (dontCheck p.either);
              # # this depends on ghc/ghci, which depend on transformers
              # # which is different from the one we have in the set :(
              # # Also ghc/ghci can't be reinstalled...
              doctest = null;
              # # Maybe we can do doctest=pkgs.doctest?
              # # the following depend on doctest...
              # network = dontCheck p.network;
              # distributive = dontCheck p.distributive;
              # http-date = dontCheck p.http-date;
              # unix-time = dontCheck p.unix-time;
              # comonad = dontCheck p.comonad;
              # iproute = dontCheck p.iproute;
              # semigroupoids = dontCheck p.semigroupoids;
              # # test fails...
              # filelock = dontCheck p.filelock;
              # threads = dontCheck p.threads;
              # zlib = dontCheck p.zlib;
              # tar = dontCheck p.tar;

              # # daemon-test: /home/erebe/log: openFile: does not exist (No such file or directory)
              # systemd = dontCheck p.systemd;
              # # Variable not in scope: getUnicodeString :: a0 -> FilePath
              # rocksdb-haskell-ng = dontCheck p.rocksdb-haskell-ng;
              # nuke out tools that are already present anyway.
              hsc2hs = null;
              #
              cardano-sl-update = disableLibraryProfiling (fast p.cardano-sl-update);
              # o-clock = dontJailbreak (doExactConfig (fast p.o-clock));
              # log-warper = dontJailbreak (doExactConfig (fast p.log-warper));
              }));
   in compiler.override {
      initialPackages = { pkgs, stdenv, callPackage }: self: stackPackages;
      configurationCommon = { ... }: self: super: {};
      compilerConfig = self: super: {};
   }
