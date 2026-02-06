{
  description = "pwlink";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          pwlink = pkgs.stdenvNoCC.mkDerivation {
            pname = "pwlink";
            version = "0.1.8";
            src = self;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontBuild = true;
            installPhase = ''
              mkdir -p $out/bin
              install -m755 $src/pwlink $out/bin/pwlink
              wrapProgram $out/bin/pwlink \
                --prefix PATH : ${pkgs.python3}/bin \
                --prefix PATH : ${pkgs.pulseaudio}/bin \
                --prefix PATH : ${pkgs.avahi}/bin
            '';
          };
          default = self.packages.${system}.pwlink;
        });

      apps = forAllSystems (system: {
        pwlink = {
          type = "app";
          program = "${self.packages.${system}.pwlink}/bin/pwlink";
        };
        default = self.apps.${system}.pwlink;
      });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              python3
              pulseaudio
              avahi
            ];
          };
        });
    };
}
