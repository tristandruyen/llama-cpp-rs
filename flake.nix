{
  description = "A Nix-flake-based Rust development environment";
  nixConfig = {
    extra-substituters = [
      "https://nixcache.vlt81.de"
      "https://cuda-maintainers.cachix.org"
      "https://cache.nixos.org"
      "https://cache.garnix.io"
    ];
    extra-trusted-public-keys = [
      "nixcache.vlt81.de:nw0FfUpePtL6P3IMNT9X6oln0Wg9REZINtkkI9SisqQ="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self
    , nixpkgs
    , rust-overlay
    , flake-utils
    , devshell
    , ...
    }:
    flake-utils.lib.eachDefaultSystem
      (system:
      let
        overlays = [
          rust-overlay.overlays.default
          devshell.overlays.default
        ];
        customRustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        config = {
          allowUnfree = true;
        };
        pkgs = import nixpkgs {
          inherit system overlays config;
        };
        makeCmakePaths = packages: builtins.concatStringsSep ":" (map (pkg: "${pkg}/lib/cmake") packages);
        rocmPkgs = with pkgs; [
          rocmPackages.clr
          rocmPackages.hipblas
          rocmPackages.rocblas
          rocmPackages.rocm-device-libs
          rocmPackages.rocm-runtime
          rocmPackages.hsakmt
          rocmPackages.rocm-comgr
          rocmPackages.hipblas-common
        ];
        buildInputs = with pkgs;
          [
            libclang
            libcxx
          ]
          ++ rocmPkgs;
        lib = pkgs.lib;
        makeBindgenClangArgs =
          # Includes normal include path
          (builtins.map (a: ''-I"${a}/include"'') [
            # add dev libraries here (e.g. pkgs.libvmi.dev)
            pkgs.glibc.dev
          ])
          # Includes with special directory paths
          ++ [
            ''-I"${pkgs.llvmPackages_latest.libclang.lib}/lib/clang/${pkgs.llvmPackages_latest.libclang.version}/include"''
            ''-I"${pkgs.glib.dev}/include/glib-2.0"''
            ''-I${pkgs.glib.out}/lib/glib-2.0/include/''
          ]
          ++ [
            ''-pthread'' # TODO check if even needed?
          ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs;
            [
              customRustToolchain
              pkg-config
            ]
            ++ buildInputs;

          buildInputs = buildInputs;

          BINDGEN_EXTRA_CLANG_ARGS = makeBindgenClangArgs;
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
          CMAKE_PREFIX_PATH = "${makeCmakePaths rocmPkgs}";
          MALLOC_CONF = "thp:always,metadata_thp:always";

          shellHook = ''
        '';
        };
      });
}
