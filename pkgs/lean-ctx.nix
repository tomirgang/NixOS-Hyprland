# lean-ctx: context compression for coding agents (crates.io, Apache-2.0)
{
  lib,
  rustPlatform,
  fetchCrate,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "lean-ctx";
  version = "3.12.0";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-nUK95eQFDFE/mVf3CE0rIlPZVZ/WJOYudEeTKYUA2u0=";
  };

  cargoHash = "sha256-s427K/sYGjROYx6bSlf16GAUubDYnGA0z9X2/aM9Rx0=";

  doCheck = false; # tests need network and a writable home

  meta = {
    description = "Context compression for coding agents";
    homepage = "https://github.com/yvgude/lean-ctx";
    license = lib.licenses.asl20;
    mainProgram = "lean-ctx";
  };
})
