{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    ngscopeclient = {
      url = "https://github.com/glscopeclient/scopehal-apps.git";
      flake = false;
      submodules = true;
      type = "git";
    };
    ffts-src = {
      url = "github:anthonix/ffts";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, flake-utils, ngscopeclient, ffts-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        ffts = pkgs.stdenv.mkDerivation {
          name = "ffts";
          src = ffts-src;
          buildInputs = with pkgs; [ cmake ];
          buildCommand = ''
            mkdir -p $out/lib
            cd $out
            cmake $src -DENABLE_SHARED=ON CMAKE_INSTALL_PREFIX=$out/lib
            make
            mv libffts.so $out/lib/libffts.so
            cp -R $src/include $out
          '';
        };

        vulkansdk = pkgs.stdenv.mkDerivation {
          name = "vulkansdk";
          nativeBuildInputs = [
            pkgs.autoPatchelfHook
            # pkgs.wrapQtAppsHook
            pkgs.libsForQt5.wrapQtAppsHook
          ];

          buildInputs = with pkgs; [
            glibc
            stdenv.cc.cc.lib
            xorg.libxcb
            lz4
            zlib
            zstd
            ncurses5
            wayland
            xorg.libX11
            qt5.qtbase
          ];

          src = pkgs.fetchurl {
            url = "https://sdk.lunarg.com/sdk/download/1.3.224.1/linux/vulkansdk-linux-x86_64-1.3.224.1.tar.gz";
            sha256 = "sha256-R8OlvQM6vw/Cqd8ROot/uCmlHYbSNDhb10IxCvwRYxY=";
          };
          installPhase = ''
            mkdir -p $out
            cp -pR x86_64/* $out
          '';
        };
      in
      {
        defaultPackage = pkgs.stdenv.mkDerivation {
          name = "ngscopeclient";
          buildInputs = with pkgs; [
            bash
            cmake
            pkg-config
            gtk3 gtkmm3 glfw cmake yaml-cpp glew catch2 vulkan-loader
          llvmPackages_13.openmp vulkansdk ffts ] ++ lib.lists.optionals pkgs.stdenv.isLinux [ pkgs.pcre2 ];
          src = ngscopeclient;

          patches = [
            ./patch.diff
          ];

          preConfigure = ''
            export VULKAN_SDK=${vulkansdk}
            export VK_LAYER_PATH=${vulkansdk}/etc/vulkan/explicit_layer.d
          '';

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
          ];
        };
        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.bash ffts vulkansdk];
          VK_LAYER_PATH = ''${vulkansdk}/etc/vulkan/explicit_layer.d'';
        };
      }
    );
}
