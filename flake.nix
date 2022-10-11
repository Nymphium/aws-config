{
  inputs = {
    opam-nix.url = "github:tweag/opam-nix";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs = { self, flake-utils, opam-nix, nixpkgs }:
    let package = "aws-config";
    in flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        on = opam-nix.lib.${system};
        scope = on.buildOpamProject { } package ./. { };
        devPackages = {
          ocaml-lsp-server = "*";
          utop = "*";
          ocamlformat = "*";
        };
      in {
        packages =
          let
            scope = opam-nix.lib.${system}.buildOpamProject' { } ./. devPackages;
          in
          scope // { default = self.packages.${system}.${package}; };

        devShell =
          pkgs.mkShell {
            buildInputs = [] ++ (builtins.map (s: builtins.getAttr s self.packages.${system})
              (builtins.attrNames devPackages));

            inputsFrom = [ self.packages.${system}.default ];
          };
      });
}
