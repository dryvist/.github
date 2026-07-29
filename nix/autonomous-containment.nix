# Autonomous-config containment check
#
# One invariant, shared by every per-CLI Nix repo (nix-claude-code,
# nix-codex, nix-agy):
#
#   The autonomous/CI agent configs — bypassPermissions, approval_policy
#   "never", danger-full-access, yolo — exist only to be baked into
#   container images, where the container boundary IS the safety model. No
#   home-manager code path may render them onto a workstation filesystem,
#   where there is no such boundary and the human is the permission model.
#
# This enforces that at the source level: the home-manager module tree must
# not reference the autonomous renderers or their postures. An import added
# to a home-manager module is how these configs would actually reach a
# host, so that is the vector worth guarding. It deliberately proves
# nothing about a running machine — a Nix check cannot.
#
# Exported as a plain function rather than a flake-parts module because the
# leaf repos are plain flakes (`checks = forAllSystems ...`). It cannot
# live in nix-ai: nix-ai consumes nix-claude-code as a flake input, so a
# leaf importing nix-ai back would be a circular flake input.
#
# Consumer snippet (plain flake):
#
#   checks = forAllSystems (pkgs: {
#     autonomous-containment = dryvist-github.lib.autonomousContainment {
#       inherit pkgs;
#       homeManagerModules = ./modules;
#     };
#   });
{
  pkgs,

  # Directory holding the repo's home-manager module(s). Every .nix file
  # under it is scanned.
  homeManagerModules,

  name ? "autonomous-containment",

  # Two unambiguous signals that a module renders autonomous config:
  # importing a renderer, or ASSIGNING an autonomous value.
  #
  # Bare value names are deliberately NOT listed. A home-manager options
  # module has to name "bypassPermissions" in its `types.enum` to type the
  # option at all, and its description has to explain what the mode does —
  # both are legitimate, and matching the bare name flags them. (The first
  # real consumer, nix-claude-code, hits exactly this in
  # modules/core.nix and modules/options-settings.nix.) Matching the
  # assignment form instead distinguishes "declares this value as
  # permissible" from "sets it as the rendered default".
  #
  # Known limitation: prose and enum declarations are intentionally not
  # flagged, and a value smuggled through string interpolation or a shell
  # alias (`c = "claude --yolo"`) will not match. This guards the realistic
  # accident — an import or a changed default — not deliberate evasion.
  forbidden ? [
    "render-autonomous"
    "renderAutonomous"
    "requiresContainerBoundary"
    ''= "bypassPermissions"''
    ''= "danger-full-access"''
    ''= "yolo"''
    ''approval_policy = "never"''
  ],

  # Paths to skip, relative to homeManagerModules. Use only with a comment
  # justifying why that file is not a host-render path.
  allowlist ? [ ],
}:

pkgs.runCommand name
  {
    src = homeManagerModules;
    forbidden = builtins.concatStringsSep "\n" forbidden;
    allowlist = builtins.concatStringsSep "\n" allowlist;
    passAsFile = [
      "forbidden"
      "allowlist"
    ];
    nativeBuildInputs = [ pkgs.bash ];
  }
  ''
    bash ${./containment-scan.sh} "$src" "$forbiddenPath" "$allowlistPath"
    touch "$out"
  ''
