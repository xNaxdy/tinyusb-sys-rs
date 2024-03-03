{
  description = "Rust wrapper for the TinyUSB library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=23.11";

    rust-overlay.url = "github:oxalica/rust-overlay?ref=master";

    flake-utils.url = "github:numtide/flake-utils";

    tinyusb = {
      url = "github:hathach/tinyusb?ref=0.16.0";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , rust-overlay
    , flake-utils
    , tinyusb
    }: (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          rust-overlay.overlays.default
        ];
      };

      rustToolchain = pkgs.rust-bin.stable.latest.default.override {
        extensions = [
          "rust-src"
          "rust-std"
        ];
      };

      mkSource = { defines ? { }, addLines ? "" }:
        let
          pkginfo = (builtins.fromTOML (builtins.readFile ./Cargo.toml));

          defineInstructs = builtins.concatStringsSep "\n" (map
            (e:
              "#define ${e.name} ${if builtins.typeOf e.value == "string" then "\"${e.value}\"" else
                (if builtins.typeOf e.value == "bool" then (if e.value then "true" else "false") else (builtins.toString e.value))}")
            (pkgs.lib.attrsToList defines));
        in
        pkgs.runCommandLocal "${pkginfo.package.name}-${pkginfo.package.version}-source"
          {
            tusbConfig = ''
              #ifndef _TUSB_CONFIG_H_
              #define _TUSB_CONFIG_H_

              ${defineInstructs}
              ${addLines}

              #endif
            '';
          }
          ''
            mkdir -p $out
            cp -r ${self}/* $out/
            cp -r ${tinyusb} $out/tinyusb
            chmod +w $out/tusb_config.h

            echo "$tusbConfig" > $out/tusb_config.h
          '';
    in
    {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = builtins.attrValues {
          inherit rustToolchain;
        };

        LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";

        shellHook = ''
          cp -r ${tinyusb} ./tinyusb
        '';
      };

      packages.source = pkgs.callPackage mkSource { };
    }));
}
