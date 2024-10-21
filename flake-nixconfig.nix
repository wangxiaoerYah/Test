localFlake:
{ inputs, lib, self, ... }:
let
  projectRoot = "${inputs.self.outPath}";
  configToml = builtins.fromTOML (builtins.readFile "${projectRoot}/config.toml");
  hostsToml = builtins.fromTOML (builtins.readFile "${projectRoot}/hosts.toml");
  specialArgsFor = _n: {
    inherit inputs projectRoot hostsToml configToml;
  };

  modulesFor = _n: [
    ## ------------------- base -------------------
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
    inputs.colmena.nixosModules.deploymentOptions
    ## ------------------- Theme -------------------
    inputs.catppuccin.nixosModules.catppuccin
    ## ------------------- Custom -------------------
    self.nixosModules.default
    ({ ... }: {
      mod.net.hostName = lib.mkForce (lib.removePrefix "_" _n);
      home-manager.extraSpecialArgs = specialArgsFor _n;
    })
    ("${projectRoot}/hosts" + "/${_n}/configuration.nix")
  ];

  patchedPkgsFor = system: self.allSystems."${system}"._module.args.pkgs;
  patchedNixpkgsFor = system: self.packages."${system}".nixpkgs-patched;

  HP = import ./helpers {
    inherit lib inputs self;
    inherit (self) nixosConfigurations;
  };
in
{
  # ------------------- NixosConfigurations -------------------
  flake.nixosConfigurations = (lib.genAttrs
    (builtins.attrNames (builtins.readDir "${projectRoot}/hosts"))
    (
      _n:
      let
        system = hostsToml.hosts."${_n}".ARCH;
        nixpkgs = patchedNixpkgsFor system;
        pkgs = patchedPkgsFor system;
      in
      nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        modules = modulesFor _n;
        specialArgs = specialArgsFor _n;
      }
    ));

  # ------------------- ColmenaHive -------------------

  flake.colmenaHive = HP.mkColmenaHive { allowApplyAll = false; } (
    lib.filterAttrs (n: _: !lib.hasPrefix "_" n) self.nixosConfigurations
  );

  # ------------------- NixOnDroid -------------------
  flake.nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    modules = [
      (projectRoot + "/NixOnDroid/nix-on-droid.nix")
    ];
    extraSpecialArgs = {
      inherit projectRoot;
    };
    pkgs = import inputs.nixpkgs {
      config = { allowUnfree = true; };
      system = "aarch64-linux"; # only supported "aarch64-linux"
      overlays = [
        inputs.nix-on-droid.overlays.default
      ];
    };
    home-manager-path = inputs.home-manager.outPath;
  };

}
