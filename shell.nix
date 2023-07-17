{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    pkgs.elixir_1_12
    pkgs.inotify-tools
    pkgs.docker-compose
  ];
}
