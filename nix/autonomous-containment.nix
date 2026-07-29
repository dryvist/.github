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

  # Substrings that mean "autonomous posture" in any of the three CLIs'
  # config formats. A home-manager module has no legitimate reason to
  # mention any of them.
  forbidden ? [
    "render-autonomous"
    "renderAutonomous"
    "bypassPermissions"
    "danger-full-access"
    "approval_policy"
    "defaultApprovalMode"
    "requiresContainerBoundary"
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
  }
  ''
    set -euo pipefail

    if [ ! -d "$src" ]; then
      echo "containment: homeManagerModules is not a directory: $src" >&2
      exit 1
    fi

    # Guard against a vacuous pass: with no .nix files every grep below
    # trivially matches nothing, so the check would look green while
    # enforcing nothing. A repo that reorganises its modules out from under
    # this path should fail loudly, not silently stop being checked.
    count=$(find "$src" -type f -name '*.nix' | wc -l)
    if [ "$count" -eq 0 ]; then
      echo "containment: no .nix files under $src — refusing to pass vacuously" >&2
      exit 1
    fi

    status=0
    while IFS= read -r f; do
      rel=''${f#"$src"/}

      if [ -s "$allowlistPath" ] && grep -Fxq -- "$rel" "$allowlistPath"; then
        continue
      fi

      while IFS= read -r pat; do
        [ -z "$pat" ] && continue
        if grep -Fq -- "$pat" "$f"; then
          echo "containment VIOLATION: $rel references '$pat'" >&2
          status=1
        fi
      done < "$forbiddenPath"
    done < <(find "$src" -type f -name '*.nix' | sort)

    if [ "$status" -ne 0 ]; then
      echo "" >&2
      echo "Autonomous config must never render onto a host filesystem." >&2
      echo "Keep it behind the image-build lib, or add the file to" >&2
      echo "allowlist with a comment saying why it is not a host-render" >&2
      echo "path." >&2
      exit 1
    fi

    echo "containment OK: $count home-manager .nix file(s) clean"
    touch "$out"
  ''
