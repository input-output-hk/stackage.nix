{ lts-def 
, pkgs    ? import <nixpkgs> {}
, hackage ? import <hackage>
, haskell ? import <haskell> }:

let
  lts = lts-def hackage.exprs;

  driver = haskell.compat.driver;
  host-map = haskell.compat.host-map;

  # packages shipped with ghc.
  ghcPackages = pkgs.lib.mapAttrs (name: value: null) lts.compiler.packages;

  # compiler this lts set is built against.
  compiler = pkgs.haskell.packages.${lts.compiler.nix-name};

  toGenericPackage = stackPkgs: args: name: path:
    let expr = driver { cabalexpr = import path;
             pkgs = pkgs // { haskellPackages = stackPkgs; };
             inherit (host-map pkgs.stdenv) os arch; };
     # Use `callPackage` from the `compiler` here, to get the
     # right compiler.
     in compiler.callPackage expr args;

in let stackPackages = ghcPackages //
       (let p = (pkgs.lib.mapAttrs (toGenericPackage stackPackages {}) lts.packages)
              // { cassava = toGenericPackage stackPackages { flags = { bytestring--lt-0_10_4 = false; }; } "cassava" lts.packages.cassava; }
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
              hashable = dontCheck p.hashable;
              test-framework = dontCheck p.test-framework;
              unordered-containers = dontCheck p.unordered-containers;
              # jailbreak
              old-locale = doJailbreak p.old-locale;
              pcre-light = doJailbreak p.pcre-light;
              mtl        = doJailbreak p.mtl;
              utf8-string = doJailbreak p.utf8-string;
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
   in compiler.override {
      initialPackages = { pkgs, stdenv, callPackage }: self: stackPackages;
      configurationCommon = { ... }: self: super: {};
      compilerConfig = self: super: {};
   }
