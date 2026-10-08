# Changelog

## [1.7.5](https://github.com/dryvist/.github/compare/v1.7.4...v1.7.5) (2026-10-08)


### Bug Fixes

* **ci:** assert each path filter base independently ([ca91931](https://github.com/dryvist/.github/commit/ca91931dc5e666a41b8b68900bb7af5bc34012fa))
* **ci:** build focused Nix checks individually ([2c260a5](https://github.com/dryvist/.github/commit/2c260a5ecfec47b88620cb7c4bf8c4bd01596865))
* **ci:** build focused Nix checks individually ([aabd65f](https://github.com/dryvist/.github/commit/aabd65f3e6e6c1baa7a362d3260ad31b924eaaa4))
* **ci:** detect changed paths on branch pushes ([a405e04](https://github.com/dryvist/.github/commit/a405e044369aa9401669f449de97f5d27ad4c2ac))
* **ci:** detect changed paths on branch pushes ([2c1853f](https://github.com/dryvist/.github/commit/2c1853f39fab59e0e7fa31ef4457dba11f148333))

## [1.7.4](https://github.com/dryvist/.github/compare/v1.7.3...v1.7.4) (2026-10-07)


### Bug Fixes

* allow covered requirements changes to narrow Molecule ([ad75cb5](https://github.com/dryvist/.github/commit/ad75cb53c6ffebc1e1e4256ac7a82a40514d2c3d))
* **ci:** cancel stalled workflows with the run API ([1af748a](https://github.com/dryvist/.github/commit/1af748aad09acbf44f2436010487b02fd9b3921a))

## [1.7.3](https://github.com/dryvist/.github/compare/v1.7.2...v1.7.3) (2026-10-07)


### Bug Fixes

* **ci:** reconcile Galaxy requirements after cache restore ([b403b04](https://github.com/dryvist/.github/commit/b403b047793b5d48734f3dca000a82a3515417c1))

## [1.7.2](https://github.com/dryvist/.github/compare/v1.7.1...v1.7.2) (2026-10-07)


### Bug Fixes

* **ci:** honor contract-covered Molecule paths ([6d65991](https://github.com/dryvist/.github/commit/6d65991feccef465a04c8ae5a3e4cb1f505caba4))

## [1.7.1](https://github.com/dryvist/.github/compare/v1.7.0...v1.7.1) (2026-10-07)


### Bug Fixes

* **ci:** enforce focused Ansible Molecule scope ([#249](https://github.com/dryvist/.github/issues/249)) ([e3c0fa8](https://github.com/dryvist/.github/commit/e3c0fa803516d9a85697cce97583bc2b7cc5c6d6))

## [1.7.0](https://github.com/dryvist/.github/compare/v1.6.1...v1.7.0) (2026-10-07)


### Features

* add reusable benchmark result validation ([4c1d77a](https://github.com/dryvist/.github/commit/4c1d77adb9b56f243216c7a14a9101d3fb6875f4))
* add reusable benchmark result validation ([4bde76f](https://github.com/dryvist/.github/commit/4bde76f53180be86236fc87136a7c5d7204a2d6e))


### Bug Fixes

* **ansible-ci:** widen molecule matrix for shared changes ([cb11a3b](https://github.com/dryvist/.github/commit/cb11a3b3fd81c892787e402f2997f253a44703f2))

## [1.6.1](https://github.com/dryvist/.github/compare/v1.6.0...v1.6.1) (2026-10-05)


### Bug Fixes

* handle unknown Merge Gate results ([#240](https://github.com/dryvist/.github/issues/240)) ([9c29df5](https://github.com/dryvist/.github/commit/9c29df57405de7f6f030d3ce6a94f0845efb50d9))

## [1.6.0](https://github.com/dryvist/.github/compare/v1.5.6...v1.6.0) (2026-10-03)


### Features

* **renovate:** ignore the hash-fixer bot as a commit author ([#233](https://github.com/dryvist/.github/issues/233)) ([d217fcf](https://github.com/dryvist/.github/commit/d217fcfc01d2bd1cbf51ef45e0ca75536a4ff5fb))

## [1.5.6](https://github.com/dryvist/.github/compare/v1.5.5...v1.5.6) (2026-10-03)


### Bug Fixes

* **ci-gate:** run Nix checks on deps-only PRs that change Nix files ([#231](https://github.com/dryvist/.github/issues/231)) ([5edd133](https://github.com/dryvist/.github/commit/5edd13311d514f5d3207db903b4fa391919658de))

## [1.5.5](https://github.com/dryvist/.github/compare/v1.5.4...v1.5.5) (2026-10-03)


### Bug Fixes

* **ansible-ci:** run the gated jobs on scripts/** changes ([#229](https://github.com/dryvist/.github/issues/229)) ([13886d7](https://github.com/dryvist/.github/commit/13886d7a5f280caf9525f988ff98c396b5a8564e))

## [1.5.4](https://github.com/dryvist/.github/compare/v1.5.3...v1.5.4) (2026-10-02)


### Bug Fixes

* **flake:** check out the caller repository with an App token in the stale-input job ([#227](https://github.com/dryvist/.github/issues/227)) ([d5d9181](https://github.com/dryvist/.github/commit/d5d91812452ec90563474b619501476c6218b5fe))

## [1.5.3](https://github.com/dryvist/.github/compare/v1.5.2...v1.5.3) (2026-10-02)


### Performance

* **ci:** restore the previous pre-commit cache when the hook config changes ([#223](https://github.com/dryvist/.github/issues/223)) ([cf1779f](https://github.com/dryvist/.github/commit/cf1779f8497b280476e181eae4ae816075b24068))

## [1.5.2](https://github.com/dryvist/.github/compare/v1.5.1...v1.5.2) (2026-10-02)


### Bug Fixes

* **label-sync:** add repos from the org repo inventory to the fan-out ([#221](https://github.com/dryvist/.github/issues/221)) ([227827a](https://github.com/dryvist/.github/commit/227827a1a4d3f7a752c2f8a553263c667a10f7c4))

## [1.5.1](https://github.com/dryvist/.github/compare/v1.5.0...v1.5.1) (2026-10-02)


### Bug Fixes

* **label-sync:** skip archived repos and lift the listing cap ([#219](https://github.com/dryvist/.github/issues/219)) ([2efa9b7](https://github.com/dryvist/.github/commit/2efa9b78efff218a41aeda0f651fdf967b6ec2f0))

## [1.5.0](https://github.com/dryvist/.github/compare/v1.4.0...v1.5.0) (2026-10-01)


### Features

* **ci-gate:** require owned flake inputs at branch head ([#215](https://github.com/dryvist/.github/issues/215)) ([04ec7ea](https://github.com/dryvist/.github/commit/04ec7eab5999ced352fc8746da8d80fbfd6a29d8))
* **flake:** check owned flake inputs and relock only the stale ones ([#211](https://github.com/dryvist/.github/issues/211)) ([58cd281](https://github.com/dryvist/.github/commit/58cd281c28e9fa6600a94e13ae3ada9dd6c2e59a))


### Bug Fixes

* **ci:** deterministic flake-lock PR gate; cache pre-commit envs ([#218](https://github.com/dryvist/.github/issues/218)) ([81e7660](https://github.com/dryvist/.github/commit/81e766008fce15a7120979ca063c43394393b51d))
* **flake:** fail an owned input pinned to a revision ([#216](https://github.com/dryvist/.github/issues/216)) ([8d3a08e](https://github.com/dryvist/.github/commit/8d3a08ef8826fb983ca9ca561ca1793315188deb))
* **flake:** name the relocked inputs in targeted relock PR bodies ([#217](https://github.com/dryvist/.github/issues/217)) ([696ba75](https://github.com/dryvist/.github/commit/696ba7574a7ec86edd742515603602367c97e2b6))
* **renovate:** scope own-org auto-merge to git-refs customManager pins ([#210](https://github.com/dryvist/.github/issues/210)) ([1d13f18](https://github.com/dryvist/.github/commit/1d13f18e3457e7c5af44f0129b253edbf568a80d))
* **renovate:** unstick git-refs digest updates (ansible-galaxy duplicate lookup + minimumReleaseAgeBehaviour) ([#208](https://github.com/dryvist/.github/issues/208)) ([29da180](https://github.com/dryvist/.github/commit/29da18040b51569d37eed32b922f7ab51b29ce3c))

## [1.4.0](https://github.com/dryvist/.github/compare/v1.3.0...v1.4.0) (2026-09-25)


### Features

* **update-flake-lock:** support private flake inputs ([#207](https://github.com/dryvist/.github/issues/207)) ([698ddf1](https://github.com/dryvist/.github/commit/698ddf1f34cb3e708b38d6813410ab3a27b3c470))
* **workflows:** add optional event_type input to dispatch-flake-consumers ([#205](https://github.com/dryvist/.github/issues/205)) ([11ef252](https://github.com/dryvist/.github/commit/11ef252e68b0afbf3a2573e0e24c82576dc6e4a7))
* **workflows:** add reusable disclosure gate (gitleaks + denylist) ([#204](https://github.com/dryvist/.github/issues/204)) ([3887542](https://github.com/dryvist/.github/commit/3887542376241ee4dd29c4c31c900c52591d96fe))

## [1.3.0](https://github.com/dryvist/.github/compare/v1.2.1...v1.3.0) (2026-09-24)


### Features

* **converge:** gate terrakube-apply on GitHub OIDC and a zero-destroy plan ([#202](https://github.com/dryvist/.github/issues/202)) ([d199840](https://github.com/dryvist/.github/commit/d1998407cf3adfd0acbf1d123d3f005a915fb92a))

## [1.2.1](https://github.com/dryvist/.github/compare/v1.2.0...v1.2.1) (2026-09-23)


### Bug Fixes

* **renovate:** keep a v-prefixed pin's own prefix on write-back ([#200](https://github.com/dryvist/.github/issues/200)) ([ee555ec](https://github.com/dryvist/.github/commit/ee555ec5bae93ab0478eb60b9b5ec9e39c67f352))

## [1.2.0](https://github.com/dryvist/.github/compare/v1.1.2...v1.2.0) (2026-09-21)


### Features

* **workflows:** add reusable to cancel queued/in-progress runs on PR close ([4cc0bd0](https://github.com/dryvist/.github/commit/4cc0bd0e76a3cdf8b6b298be21f63b1468778396))
* **workflows:** add reusable to cancel queued/in-progress runs on PR close ([443eebf](https://github.com/dryvist/.github/commit/443eebf0219003a6a4fc91237cab026483d3497b))

## [1.1.2](https://github.com/dryvist/.github/compare/v1.1.1...v1.1.2) (2026-09-21)


### Bug Fixes

* **ansible-ci:** make the molecule runner selection visibility-aware ([#195](https://github.com/dryvist/.github/issues/195)) ([c12402c](https://github.com/dryvist/.github/commit/c12402ca3faa2ee9d3ec81a17b5249b6eaf42061))

## [1.1.1](https://github.com/dryvist/.github/compare/v1.1.0...v1.1.1) (2026-09-20)


### Bug Fixes

* **workflows:** pin shared-script checkout to job.workflow_sha, no main fallback ([#192](https://github.com/dryvist/.github/issues/192)) ([b2cddaf](https://github.com/dryvist/.github/commit/b2cddaf6a2b00a285769c16690dc75531a3c93b6))

## [1.1.0](https://github.com/dryvist/.github/compare/v1.0.0...v1.1.0) (2026-09-20)


### Features

* **release:** wire release-please for this repo ([eb55f72](https://github.com/dryvist/.github/commit/eb55f727035636ae43a039f0da1340a76f3aa4f9))
* **release:** wire release-please for this repo ([4b5af25](https://github.com/dryvist/.github/commit/4b5af250cf8f094c19d64c8fd54ecf11bd3fe1f3))
