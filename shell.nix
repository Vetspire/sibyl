{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  inherit (lib) optional optionals;

  # `sha256` can be programmatically obtained via running the following:
  # `nix-prefetch-url --unpack https://github.com/elixir-lang/elixir/archive/v${version}.tar.gz`
  elixir_1_15_7 = (beam.packagesWith pkgs.erlangR26).elixir_1_15.override {
    version = "1.15.7";
    sha256 = "0yfp16fm8v0796f1rf1m2r0m2nmgj3qr7478483yp1x5rk4xjrz8";
  };
in

mkShell {
  buildInputs = [
    elixir_1_15_7
    pkgs.inotify-tools
    pkgs.docker-compose
  ];
}
