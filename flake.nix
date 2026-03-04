# RISC-V Spike ISA Simulator — Nix Flake（仅静态链接）
# 参考 nvboard 的 flake 结构；引用方将 spike 加入 buildInputs 后可获得 SPIKE_HOME（指向 install 目录）。
#
# 在其他项目中引用：
#   inputs.spike.url = "path:../spike";
#   buildInputs = [ spike.packages.${system}.default ];  # 或 .static
# 编译：-I$SPIKE_HOME/include -L$SPIKE_HOME/lib，链接 -lfesvr -lfdt -lsoftfloat -ldisasm -lriscv
#
{
  description = "RISC-V Spike ISA Simulator (static libs for linking in other projects)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          spikeVersion = self.shortRev or "0.0-nix";
          src = pkgs.lib.cleanSourceWith {
            src = pkgs.lib.cleanSource self;
            filter = path: type:
              type != "directory" || (builtins.baseNameOf path != "build" && builtins.baseNameOf path != ".git");
          };
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "spike";
            version = spikeVersion;
            inherit src;

            nativeBuildInputs = with pkgs; [ meson ninja pkg-config dtc python3 ];
            buildInputs = [ ];

            dontUseMesonConfigure = true;
            mesonBuildType = "release";

            configurePhase = ''
              runHook preConfigure
              meson setup build \
                --prefix=$out \
                --buildtype=release \
                -Ddefault_library=static \
                -Dsoftfloat_pa=true \
                -Ddefault_isa=RV64IMAFDC_zicntr_zihpm \
                -Ddefault_priv=MSU \
                -Ddefault_varch=vlen:128,elen:64
              runHook postConfigure
            '';

            buildPhase = ''
              runHook preBuild
              ninja -C build
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              ninja -C build install
              mkdir -p $out/nix-support
              echo 'export SPIKE_HOME='"$out" > $out/nix-support/setup-hook
              runHook postInstall
            '';

            meta = {
              description = "RISC-V Spike ISA Simulator";
              homepage = "https://github.com/riscv-software-src/riscv-isa-sim";
              license = with pkgs.lib.licenses; bsd3;
              maintainers = [ ];
              platforms = supportedSystems;
            };
          };

          # 仅静态产物，供其他 flake 作为 buildInput 引用（含 SPIKE_HOME setup-hook）
          static = pkgs.runCommand "spike-static" { } ''
            mkdir -p $out/lib $out/include $out/nix-support
            cp -r ${self.packages.${system}.default}/lib/*.a $out/lib/ 2>/dev/null || true
            cp -r ${self.packages.${system}.default}/include/* $out/include/ 2>/dev/null || true
            [ -n "$(ls -A $out/lib 2>/dev/null)" ] || { echo "no static libs"; exit 1; }
            echo 'export SPIKE_HOME='"$out" > $out/nix-support/setup-hook
          '';

          spike = self.packages.${system}.default;
        });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              meson
              ninja
              pkg-config
              dtc
              python3
            ];

            shellHook = ''
              export SPIKE_HOME="$(pwd)"
              echo "SPIKE_HOME is set to: $SPIKE_HOME"
              echo "Build: meson setup build --prefix=\$SPIKE_HOME && ninja -C build && ninja -C build install"
              echo "Or use: nix build .#default"
            '';
          };
        });

      overlays.default = final: prev: {
        spike = self.packages.${final.system}.default;
        spike-static = self.packages.${final.system}.static;
      };
    };
}
