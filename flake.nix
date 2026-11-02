# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#  Fork for the host "frame" (Framework Laptop 13, 13th Gen Intel).
#  Upstream modules live in modules/, own modules in local/, own packages in
#  pkgs/, development shells in devshells/. See NixOS.md in Nextcloud.
{
  description = "KoolDots -- NixOS-Hyprland (host frame)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim = {
      url = "github:nix-community/nixvim/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  To build from source, not recommended
    # hyprland = {
    #   url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    waybar = {
      url = "github:alexays/waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ags = {
      type = "github";
      owner = "aylur";
      repo = "ags";
      ref = "v1";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  ghee - git, as a place you leave open (packaged by upstream)
    ghee = {
      url = "git+https://justaguy.dev/drew/ghee";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  butterpal - wallpaper palette generator for the butter setups
    butterpal = {
      url = "git+https://justaguy.dev/drew/butterpal";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  quickshell = {
    #    url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    #    inputs.nixpkgs.follows = "nixpkgs";
    #  };

    hyprmod-src = {
      url = "github:BlueManCZ/hyprmod";
      flake = false;
    };

    #  frame: hardware profile (only for the real host, not for frame-vm)
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    #  frame: Secure Boot, imported from Phase 5 on (local/secureboot.nix)
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    #  frame: ESP-IDF for devShell embedded (own nixpkgs pin, binary cache of upstream)
    esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ags,
    hyprmod-src,
    ...
  }: let
    system = "x86_64-linux";
    host = "frame";
    username = "tom";

    # Own packages, available as pkgs.<name> in all modules and in Home Manager.
    # rtk and framework-control come from nixpkgs.
    localOverlay = final: prev: {
      lean-ctx = final.callPackage ./pkgs/lean-ctx.nix {};
    };

    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
      overlays = [localOverlay];
    };
    waybarWeatherPkg = pkgs.callPackage ./pkgs/waybar-weather.nix {};
    hyprlandBindings = pkgs.callPackage ./pkgs/hyprland-python-bindings.nix {};
    hyprmodPkg = pkgs.callPackage ./pkgs/hyprmod.nix {
      hyprmodSrc = hyprmod-src;
      inherit hyprlandBindings;
    };

    # extraModules: what differs between the real host and the test VM
    mkHost = extraModules:
      nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit system;
          inherit inputs;
          inherit username;
          inherit host;
          customPkgs = {inherit hyprmodPkg;};
        };
        modules =
          [
            ./hosts/${host}/config.nix
            {nixpkgs.overlays = [localOverlay];}
            ./modules/overlays.nix # nixpkgs overlays (CMake policy fixes)
            ./modules/quickshell.nix # quickshell module
            ./modules/hyprland.nix # Hyprland session (enable, polkit agent, session pkgs)
            ./modules/packages.nix # Software packages
            # Allow broken packages (temporary fix for broken CUDA in nixos-unstable)
            {nixpkgs.config.allowBroken = true;}
            ./modules/fonts.nix # Fonts packages
            ./modules/portals.nix # portal
            ./modules/theme.nix # Set dark theme
            # ./modules/ly.nix # frame: greetd instead of ly (local/security.nix)
            ./modules/nh.nix # nix helper
            inputs.catppuccin.nixosModules.catppuccin

            # frame: own modules
            ./local/security.nix
            ./local/framework.nix
            ./local/virtualisation.nix
            ./local/apps.nix
            ./local/dev.nix
            ./local/backup.nix
            ./local/electronics.nix
            # ./local/secureboot.nix # Phase 5

            # Integrate Home Manager as a NixOS module
            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-bak";

              # Ensure HM modules can access flake inputs (e.g., inputs.nixvim)
              home-manager.extraSpecialArgs = {
                inherit
                  inputs
                  system
                  username
                  host
                  ;
              };

              home-manager.users.${username} = {
                home.username = username;
                home.homeDirectory = "/home/${username}";
                home.stateVersion = "25.11";

                imports = [
                  ./home/${username}.nix
                ];
              };
            }
          ]
          ++ extraModules;
      };
  in {
    packages.${system} = {
      waybar-weather = waybarWeatherPkg;
      hyprmod = hyprmodPkg;
      inherit (pkgs) lean-ctx;
    };

    nixosConfigurations = {
      # Real hardware: LUKS with FIDO2, nixos-hardware profile
      frame = mkHost [
        ./hosts/frame/hardware.nix
        ./hosts/frame/luks.nix
        inputs.nixos-hardware.nixosModules.framework-13th-gen-intel
      ];

      # Test VM for nixos-rebuild build-vm: no LUKS, no nixos-hardware
      frame-vm = mkHost [
        ./hosts/frame/vm.nix
      ];
    };

    devShells.${system} = {
      cpp = import ./devshells/cpp.nix {inherit pkgs;};
      cpp-qt6 = import ./devshells/cpp-qt6.nix {inherit pkgs;};
      cross = import ./devshells/cross.nix {inherit pkgs;};
      docs = import ./devshells/docs.nix {inherit pkgs;};
      embedded = import ./devshells/embedded.nix {inherit pkgs inputs system;};
      k8s = import ./devshells/k8s.nix {inherit pkgs;};
    };

    # nix flake check: borgmatic configuration outside borgmatic.d
    checks.${system}.borgmatic-external =
      self.nixosConfigurations.frame.config.local.backup.externalConfigCheck;

    # Code formatter
    formatter.x86_64-linux = pkgs.alejandra;
  };
}
