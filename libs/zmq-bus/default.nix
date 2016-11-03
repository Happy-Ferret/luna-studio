{ haskellPackages ? import ../../nix/overrides.nix,
  flowbox ? import ../../nix/flowbox.nix
}:

haskellPackages.cabal.mkDerivation (self: {
  pname = "flowbox-bus";
  version = "0.1";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  buildDepends = with flowbox; with haskellPackages; [
    async either flowboxConfig flowboxRpc flowboxUtils MissingH mmorph
    monadLoops mtl pipes pipesConcurrency transformers zeromq4Haskell
  ];
  meta = {
    license = self.stdenv.lib.licenses.unfree;
    platforms = self.ghc.meta.platforms;
  };
})
