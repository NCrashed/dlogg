{
  description = "Concurrent logging utilities for D";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.buildDubPackage {
            pname = "dlogg";
            version = "0.4.2";
            src = self;

            compiler = pkgs.ldc;
            dubLock = ./dub-lock.json;
            nativeBuildInputs = [ pkgs.dscanner ];

            doCheck = true;
            checkPhase = ''
              runHook preCheck
              for configuration in default colorized; do
                DFLAGS="-de" dub test \
                  --skip-registry=all \
                  --compiler=${pkgs.lib.getExe pkgs.ldc} \
                  --config="$configuration" \
                  --build=unittest
              done
              dscanner lint source
              runHook postCheck
            '';

            installPhase = ''
              runHook preInstall
              install -Dm644 libdlogg.a "$out/lib/libdlogg.a"
              install -d "$out/include/d" "$out/share/doc/dlogg"
              cp -r source/dlogg "$out/include/d/"
              install -m644 README.md CHANGELOG.md LICENSE dub.json "$out/share/doc/dlogg/"
              runHook postInstall
            '';

            meta = {
              description = "Logging utilities for highly loaded D applications";
              homepage = "https://github.com/NCrashed/dlogg";
              license = pkgs.lib.licenses.mit;
              platforms = pkgs.lib.platforms.unix;
            };
          };
        }
      );

      checks = forAllSystems (system: {
        inherit (self.packages.${system}) default;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.ldc
              pkgs.dub
              pkgs.dscanner
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
