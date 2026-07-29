# Selftest for the containment scanner.
#
# Exists because `nix flake check` does not evaluate `lib.` outputs — the
# exported check would otherwise ship with nothing exercising it. The cases
# live in containment-selftest.sh and drive the real containment-scan.sh,
# so the test cannot drift from the logic it claims to cover.
{ pkgs }:

pkgs.runCommand "autonomous-containment-selftest"
  {
    nativeBuildInputs = [ pkgs.bash ];
    # Mirrors the default list in autonomous-containment.nix. Written
    # without a trailing newline by passAsFile, which case 4 relies on.
    forbidden = ''
      renderAutonomous
      = "bypassPermissions"
      = "yolo"'';
    passAsFile = [ "forbidden" ];
  }
  ''
    bash ${./containment-selftest.sh} ${./containment-scan.sh} "$forbiddenPath"
    touch "$out"
  ''
