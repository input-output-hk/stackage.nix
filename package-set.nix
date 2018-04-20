{ lts-def ? import ./lts-11.5.nix
, hackage ? import <hackage>
, haskell ? import <haskell> }:

let
  lts = lts-def hackage.exprs;

  pkgs = import <nixpkgs> {};
  driver = haskell.compat.driver;
  host-map = haskell.compat.host-map;

  # packages shipped with ghc.
  # TODO: extract those from the lts-xxx file as well.
  # TODO: also ensure we use the specified ghc for the
  #       lts!
  ghcPackages = {
    ghc = null;
    hoopl = null;
    bytestring = null;
    unix = null;
    base = null;
    time = null;
    hpc = null;
    filepath = null;
    process = null;
    array = null;
    integer-gmp = null;
    containers = null;
    ghc-boot = null;
    binary = null;
    ghc-prim = null;
    ghci = null;
    rts = null;
    terminfo = null;
    transformers = null;
    deepseq = null;
    ghc-boot-th = null;
    pretty = null;
    template-haskell = null;
    directory = null;
  };

  toGenericPackage = stackPkgs: args: name: path:
    let expr = driver { cabalexpr = import path;
             pkgs = pkgs // { haskellPackages = stackPkgs; };
             inherit (host-map pkgs.stdenv) os arch; };
     in pkgs.haskellPackages.callPackage expr args;

in let stackPackages = ghcPackages //
       (let p = (pkgs.lib.mapAttrs (toGenericPackage stackPackages {}) lts)
              // { cassava = toGenericPackage stackPackages { flags = { bytestring--lt-0_10_4 = false; }; } "cassava" lts.cassava; }
              ;
         in p // (with pkgs.haskell.lib;
            { # skip checks to break recursion.
              nanospec = dontCheck p.nanospec;
              hspec    = dontCheck p.hspec;
              hspec-core = dontCheck p.hspec-core;
              hspec-discover = dontCheck p.hspec-discover;
              tasty    = dontCheck p.tasty;
              colour   = dontCheck p.colour;
              text     = dontCheck p.text;
              clock    = dontCheck p.clock;
              text-short = dontCheck p.text-short;
              scientific = dontCheck p.scientific;
              integer-logarithms = dontCheck p.integer-logarithms;
              test-framework = dontCheck p.test-framework;
              # jailbreak
              old-locale = doJailbreak p.old-locale;
              pcre-light = doJailbreak p.pcre-light;
              tagged     = appendConfigureFlag p.tagged "--allow-newer";
              HUnit      = appendConfigureFlag p.HUnit  "--allow-newer";
              test-framework-hunit = appendConfigureFlag p.test-framework-hunit "--allow-newer";
              build-vector = appendConfigureFlag p.build-vector "--allow-newer";
              vector = appendConfigureFlag p.vector "--allow-newer";
              uuid-types = appendConfigureFlag p.uuid-types "--allow-newer";
              cassava = doJailbreak p.cassava;
              # attoparsec is broken?
              attoparsec = dontCheck (appendConfigureFlag p.attoparsec "--allow-newer");
              old-time   = doJailbreak p.old-time;
              # no haddock (haddock: No input file(s).)
              bytestring-builder = dontHaddock p.bytestring-builder;
              nats = dontHaddock p.nats;
              }));
   in  stackPackages
