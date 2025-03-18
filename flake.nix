{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        with pkgs; {
          devShells.default = mkShell {
            buildInputs = [ (elixir_1_18.override { erlang = erlang_27; }) erlang_27 inotify-tools docker-compose ];
            env = {
              POSTGRES_PORT="5432";
              POSTGRES_USER = "postgres";
              POSTGRES_PASSWORD = "postgres";
              POSTGRES_DB = "endo_repo";
            };
          };
        }
    );
}
