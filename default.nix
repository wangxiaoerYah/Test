{ config ? { }
, pkgs ? { }
, lib ? pkgs.lib
, inputs
, nixosConfigurations ? null
, self ? null
, ...
}:
let
  mkScope =
    f:
    let
      # Modified from lib.callPackageWith
      call =
        file:
        let
          f = import file;
          callFn =
            f:
            let
              fargs = lib.functionArgs f;
              allArgs = builtins.intersectAttrs fargs (pkgs // scope);
              missingArgs = lib.attrNames (
                lib.filterAttrs (_: value: !value) (removeAttrs fargs (lib.attrNames allArgs))
              );
            in
            if missingArgs == [ ] then f allArgs else null;
        in
        if lib.isFunction f then callFn f else f;
      scope = f call;
    in
    scope;
in
mkScope (call: rec {
  inherit
    config
    pkgs
    lib
    inputs
    nixosConfigurations;

  mkColmenaHive = call ./mk-colmena-hive.nix;

})
