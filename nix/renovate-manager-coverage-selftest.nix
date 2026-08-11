# Selftest for the Ansible role-defaults Renovate managers.
#
# Exists because a `managerFilePatterns` regex that matches nothing fails
# SILENTLY: Renovate emits no warning, the Dependency Dashboard simply stops
# listing the file, and the pins in it go untracked until someone notices the
# version is a year old. There is no failure mode to observe, so the only way
# to keep these patterns honest is to assert against real path shapes.
#
# The regression this guards: a role may keep its defaults in one
# `defaults/main.yml` or split them into a `defaults/main/` directory, and a
# pattern covering only the first form un-tracks every pin in a split role the
# moment it is refactored. Both layouts are matched; this fails if either stops.
#
# Reads the patterns out of renovate-presets.json rather than restating them,
# so the test cannot drift from the config it claims to cover.
{ pkgs }:

pkgs.runCommand "renovate-manager-coverage-selftest"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python3 ${./renovate-manager-coverage-selftest.py} ${../renovate-presets.json}
    touch "$out"
  ''
