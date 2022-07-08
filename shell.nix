{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  elixir = (beam.packagesWith erlangR23).elixir.override {
    version = "1.13.4";
    sha256 = "1z19hwnv7czmg3p56hdk935gqxig3x7z78yxckh8fs1kdkmslqn4";
  };
in

mkShell {
  buildInputs = [
    elixir
    pkgs.inotify-tools
    pkgs.docker-compose
  ];
}
