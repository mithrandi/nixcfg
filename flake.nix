{
  inputs = {
    # Principle inputs (updated by `nix run .#update`)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-flake.url = "github:srid/nixos-flake";
    impermanence.url = "github:nix-community/impermanence";
    emacs-overlay.url = "github:nix-community/emacs-overlay";
  };

  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      imports = [ inputs.nixos-flake.flakeModule ];

      flake = let myUserName = "mithrandi";
      in {
        # Configurations for Linux (NixOS) machines
        nixosConfigurations = {
          lorien = self.nixos-flake.lib.mkLinuxSystem {
            nixpkgs.hostPlatform = "x86_64-linux";
            imports = [
              self.nixosModules.common # See below for "nixosModules"!
              self.nixosModules.linux
              ({ pkgs, ... }: {
                boot = {
                  initrd = {
                    availableKernelModules =
                      [ "vmd" "xhci_pci" "ahci" "nvme" "usbhid" ];
                    kernelModules = [ ];
                  };
                  kernelModules = [ "kvm-intel" ];
                  extraModulePackages = [ ];
                  loader = {
                    systemd-boot = {
                      enable = true;
                      consoleMode = "max";
                    };
                    efi.canTouchEfiVariables = true;
                  };
                };
                fileSystems = {
                  "/" = {
                    device = "none";
                    fsType = "tmpfs";
                    options = [ "defaults" "size=4G" "mode=755" ];
                  };
                  "/boot" = {
                    device = "/dev/disk/by-uuid/5719-229A";
                    fsType = "vfat";
                  };
                  "/nix" = {
                    device =
                      "/dev/disk/by-uuid/007f178d-bd1d-42cc-905d-b18820ace491";
                    fsType = "btrfs";
                    options = [ "subvol=@nix" ];
                  };
                  "/persist" = {
                    neededForBoot = true;
                    device =
                      "/dev/disk/by-uuid/007f178d-bd1d-42cc-905d-b18820ace491";
                    fsType = "btrfs";
                    options = [ "subvol=@persist" ];
                  };
                  "/home/mithrandi" = {
                    device =
                      "/dev/disk/by-uuid/007f178d-bd1d-42cc-905d-b18820ace491";
                    fsType = "btrfs";
                    options = [ "subvol=@mithrandi" ];
                  };
                  "/home/mithrandi/.steam" = {
                    device =
                      "/dev/disk/by-uuid/007f178d-bd1d-42cc-905d-b18820ace491";
                    fsType = "btrfs";
                    options = [ "subvol=@mithrandi-steam" ];
                  };
                };
                swapDevices = [
                  {
                    device =
                      "/dev/disk/by-uuid/bc364186-f979-471e-aba2-83c9b51cc5bd";
                  }
                  {
                    device =
                      "/dev/disk/by-uuid/17605cc1-6fe9-40cf-8258-9a5bd38d53b8";
                  }
                ];
                networking = {
                  hostName = "lorien";
                  useDHCP = true;
                  interfaces.eno1.useDHCP = true;
                };

                # Load nvidia driver for Xorg and Wayland
                services.xserver.videoDrivers = [ "nvidia" ];
                hardware = {
                  cpu.intel.updateMicrocode = true;
                  opengl = {
                    enable = true;
                    driSupport = true;
                    driSupport32Bit = true;
                    extraPackages = [ pkgs.vaapiVdpau ];
                  };

                  nvidia = {
                    modesetting.enable = true;
                    powerManagement.enable = true;
                    open = false;
                    nvidiaSettings = true;
                  };
                };
                system.stateVersion = "23.05";
              })
              # Your home-manager configuration
              self.nixosModules.home-manager
              {
                home-manager.users.${myUserName} = {
                  imports = [
                    self.homeModules.common # See below for "homeModules"!
                    self.homeModules.linux
                  ];
                  home.stateVersion = "22.11";
                };
              }
            ];
          };
        };

        # Configurations for macOS machines
        darwinConfigurations = {
          # TODO: Change hostname from "example1" to something else.
          example1 = self.nixos-flake.lib.mkMacosSystem {
            nixpkgs.hostPlatform = "aarch64-darwin";
            imports = [
              self.nixosModules.common # See below for "nixosModules"!
              self.nixosModules.darwin
              # Your machine's configuration.nix goes here
              ({ pkgs, ... }: {
                # Used for backwards compatibility, please read the changelog before changing.
                # $ darwin-rebuild changelog
                system.stateVersion = 4;
              })
              # Your home-manager configuration
              self.darwinModules.home-manager
              {
                home-manager.users.${myUserName} = {
                  imports = [
                    self.homeModules.common # See below for "homeModules"!
                    self.homeModules.darwin
                  ];
                  home.stateVersion = "22.11";
                };
              }
            ];
          };
        };

        nixosModules = {
          common = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [ hello ];
          };
          # NixOS specific configuration
          linux = { pkgs, lib, ... }: {
            imports = [ inputs.impermanence.nixosModules.impermanence ];

            environment.persistence = {
              "/persist" = {
                directories = [
                  "/var/lib/systemd"
                  "/var/lib/nixos"
                  "/var/log"
                  "/srv"
                  "/var/lib/systemd/coredump"
                  "/var/lib/bluetooth"
                ];
              };
            };
            environment.enableAllTerminfo = true;
            boot.initrd.systemd.enable = true;
            users = {
              mutableUsers = false;
              users = {
                root.initialHashedPassword =
                  "$7$CU..../....yi2Hef0oRsRabWWDyjwGM1$FFKMElPyaMUj9ApjEiO4fTGEw9v1FIkQB6EwNuniaj8";
                ${myUserName} = {
                  initialHashedPassword =
                    "$7$CU..../....7gAMhjkgsvMogdq/sU3BU0$s94hqUw7NE8/zoWUIrn8.vmp7CFyezuOQGNFi0UVBC3";
                  isNormalUser = true;
                  shell = pkgs.fish;
                  extraGroups = [ "wheel" ];
                };
              };
            };
            nixpkgs = {
              config = { allowUnfree = true; };
              overlays = [ inputs.emacs-overlay ];
            };
            nix = {
              settings = {
                substituters = [ "https://nix-community.cachix.org" ];
                trusted-public-keys = [
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
                trusted-users = [ "root" "@wheel" ];
                auto-optimise-store = lib.mkDefault true;
                experimental-features = [ "nix-command" "flakes" "repl-flake" ];
                warn-dirty = false;
                system-features = [ "kvm" "big-parallel" "nixos-test" ];
                flake-registry = ""; # Disable global flake registry
              };
              gc = {
                automatic = true;
                dates = "weekly";
                # Delete older generations too
                options = "--delete-older-than 14d";
              };

              # Add each flake input as a registry
              # To make nix3 commands consistent with the flake
              registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

              # Add nixpkgs input to NIX_PATH
              # This lets nix2 commands still use <nixpkgs>
              nixPath = [ "nixpkgs=${inputs.nixpkgs.outPath}" ];
            };
            programs = {
              dconf.enable = true;
              steam.enable = true;
            };
            security = {
              pam.loginLimits = [
                {
                  domain = "@wheel";
                  item = "nofile";
                  type = "soft";
                  value = "524288";
                }
                {
                  domain = "@wheel";
                  item = "nofile";
                  type = "hard";
                  value = "1048576";
                }
              ];
              rtkit.enable = true;
            };
            hardware = {
              enableRedistributableFirmware = true;
              pulseaudio.enable = false;
              ckb-next.enable = true;
            };
            services = {
              pipewire = {
                enable = true;
                alsa.enable = true;
                alsa.support32Bit = true;
                pulse.enable = true;
              };
              xserver = {
                desktopManager.gnome.enable = true;
                displayManager.gdm.enable = true;
              };
            };
          };
          # nix-darwin specific configuration
          darwin = { pkgs, ... }: {
            security.pam.enableSudoTouchIdAuth = true;
          };
        };

        homeModules = {
          common = { pkgs, ... }: {
            programs = {
              git.enable = true;
              starship.enable = true;
              fish.enable = true;
              emacs = {
                enable = true;
                package = pkgs.emacsPgtk;
              };
              home-manager.enable = true;

              alacritty = {
                enable = true;
                settings = {
                  window.startup_mode = "Maximized";
                  font = { size = 11; };
                  colors = {
                    primary = {
                      background = "0x002b36";
                      foreground = "0x839496";
                    };
                    cursor = {
                      text = "0x002b36";
                      cursor = "0x839496";
                    };
                    normal = {
                      black = "0x073642";
                      red = "0xdc322f";
                      green = "0x859900";
                      yellow = "0xb58900";
                      blue = "0x268bd2";
                      magenta = "0xd33682";
                      cyan = "0x2aa198";
                      white = "0xeee8d5";
                    };
                    bright = {
                      black = "0x002b36";
                      red = "0xcb4b16";
                      green = "0x586e75";
                      yellow = "0x657b83";
                      blue = "0x839496";
                      magenta = "0x6c71c4";
                      cyan = "0x93a1a1";
                      white = "0xfdf6e3";
                    };
                  };
                };
              };
              direnv = {
                enable = true;
                nix-direnv.enable = true;
              };
            };
            home = {
              packages = [
                pkgs.dhall-json
                pkgs.dhall-lsp-server
                pkgs.btop
                pkgs.delta
                pkgs.nixfmt
                pkgs.nil
                pkgs.fluxcd
                pkgs.kubeconform
                pkgs.cmctl
                pkgs.gh
                pkgs.emacs-all-the-icons-fonts
                (pkgs.nerdfonts.override {
                  fonts = [ "NerdFontsSymbolsOnly" ];
                })
              ];
            };
            services = {
              lorri.enable = true;
              emacs.enable = true;
            };
          };
          linux = {
            xsession = {
              enable = true;
              numlock.enable = true;
            };
            fonts.fontconfig.enable = true;
            services.easyeffects.enable = true;
          };
          darwin = { };
        };
      };
      perSystem = { pkgs, config, ... }: {
        nixos-flake.primary-inputs =
          [ "nixpkgs" "home-manager" "nix-darwin" "nixos-flake" ];
        devShells.default = pkgs.mkShell {
          NIX_CONFIG =
            "extra-experimental-features = nix-command flakes repl-flake";
          buildInputs = [ pkgs.nixpkgs-fmt pkgs.nixos-install-tools ];
        };
      };
    };
}
