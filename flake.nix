{
  description = "dryvist org-wide config + reusable Nix dev-hygiene flake-module";

  # Lean by design: only what the dev-hygiene module needs (no devenv /
  # crate2nix / devshell), so consumers importing flakeModules.dev-hygiene get
  # a small flake.lock closure. Plain-source consumers (flake = false, e.g. for
  # zizmor.yml) are unaffected by this flake.nix.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:
    {
      # Reusable flake-parts modules for consuming Nix repos. The dev-hygiene
      # module is pre-bound to this repo's treefmt-nix/git-hooks and its own
      # zizmor.yml; see nix/dev-hygiene.nix for the consumer snippet.
      flakeModules.dev-hygiene = import ./nix/dev-hygiene.nix {
        inherit (inputs) treefmt-nix git-hooks;
        zizmorConfig = "${self}/zizmor.yml";
      };
    };
}
