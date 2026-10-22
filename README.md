# Powder Pines

A cozy ski village on both sides of the mountain.

Grow a ski resort across the front and back of a mountain. Unlock runs, watch skiers, improve the chalet, manage staff and sales, and earn capped offline income. Ski a rewarding slalom minigame, advance seasons, finish daily goals, and level up your manager.

## Play

Use the resort navigation to manage runs, chalet upgrades, staff, daily goals and milestones. Pan between the mountain faces and start a ski run to steer through the gates. Permanent progress remains available when seasons advance.

The game supports touch and mouse input, portrait layouts, offline/local progress, achievements and player progression. Web play keeps Android-only ads and Google Play Games features unavailable without blocking the game. Rewarded benefits require the real earned-reward callback; the browser does not grant simulated ad rewards.

## Development

Original code: Apache-2.0. Developer/repository owner: [EthannYakabuski](https://github.com/EthannYakabuski). Third-party assets and plugins retain their own licenses and notices.

Use Godot **4.5.1**, the **Compatibility** renderer, and matching export templates. Android uses Java 17, the Android SDK and a Gradle build. See [native setup and configuration](docs/PLATFORM_SETUP.md). No Windows build is part of the deliverables.

```sh
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_resort.gd
godot --headless --path . --script platform/tests/services_smoke.gd
godot --headless --path . --export-release Web build/web/index.html
godot --headless --path . --install-android-build-template --export-debug Android build/android/game-debug.apk
```

Create build/web and build/android before exporting. The Android application ID is `com.ethannyakabuski.powderpines`. Debug APKs include ARM64 and x86 for the supplied test environment. Exported debug builds are for testing; Google Play publication and final release signing remain with the human owner.

## Integration and handoff

AdMob is wired with Google's official Android test app/ad-unit IDs. Banner placement is on menus; interstitial opportunities occur every two completed rounds; rewarded offers grant their benefit only after the native earned-reward event. Consent-unavailable/no-fill conditions leave normal gameplay available. Google Play Games integration is prepared with local pending achievements/scores and symbolic ID maps; production setup is disabled until the owner supplies real IDs and configures the required console setup. Credentials and signing keys stay outside Git. See platform/config.json and docs/PLATFORM_SETUP.md.

Store text, app/achievement/leaderboard icons, feature art and screenshot provenance are in marketing/. The human owner performs final backend configuration and testing, human playtesting and Google Play publication. Current build/verification status is recorded in HANDOFF.txt; do not infer production service verification from local or mocked tests.

## CI and Web

GitHub Actions imports resources, runs game/service tests with strict error checks, exports Web and an Android debug APK, and uploads artifacts with the accompanying license notices. **Pages deployment is disabled**; this workflow does not publish a live site or submit to Google Play. Current build/test status is recorded below and in `HANDOFF.txt`. A passing run does not verify production services, physical devices or browser interaction.

## Continue development

Open this repository root as the game's Codex project and start a focused task for the requested change. Read `AGENTS.md`, this README, `HANDOFF.txt` and `docs/PLATFORM_SETUP.md` first; a new task must obtain its context from these files and the current Git diff, rather than assume it inherits an earlier chat. This is the active development copy; older publication/export staging copies are archival.

Recorded public CI baseline (2026-10-21): `e7dafbeb8b6592e0bddc07a80c6b384318da3ce7`; [successful build/test run](https://github.com/EthannYakabuski/powder-pines/actions/runs/39526142460).

This game has **20 achievement** and **4 leaderboard** definitions in `game/catalog.json`. Use their symbolic keys in `platform/config.json` under `play_games.achievements` and `play_games.leaderboards`; the existing keys must remain unchanged when inserting console IDs. Play Games is currently disabled and its IDs are blank. Set `play_games.game_id`, and set the same numeric value in the Android export preset at `godot_play_game_services/game_id` in `export_presets.cfg`, before enabling the configured service. Configure the package, OAuth signing fingerprints and authorized testers in the owner consoles.

`platform/config.json` also supplies banner/interstitial/rewarded unit IDs. Its `admob.app_id` is a reference value, not the Android manifest input: set the manifest App ID through Godot Project Settings `admob/general/android/app_id`, serialized as `general/android/app_id` under `[admob]` in `project.godot`, and keep the JSON reference consistent. The missing override is normal while the plugin default is Google's sample App ID. `test_mode` in this adapter only changes the displayed status wording; it does not substitute sample unit IDs or register test devices. Keep Google sample IDs for development, or explicitly configure and verify SDK test devices before using production units. See [platform setup](docs/PLATFORM_SETUP.md).

Preserve original local packages and QA evidence. The accepted local APK hash is in `HANDOFF.txt`; hosted CI archives contain separately built binaries that have not received that local native QA. Documentation-only changes do not require rebuilding or replacing the original QA APK. Run tests with isolated process-local user-data directories, including the platform pending-service store, so the owner's real saves cannot be changed. Preserve notices and inspect explicit file diffs before staging.

## Future extension

Night Lights: floodlit runs, snowboard visitor cosmetics, and fresh slalom challenges. This is a future content idea; the initial game is intended to be independently playable.

The Android test preset uses minimum API 24 and target API 35 with Android texture imports enabled. This does not establish current Google Play release eligibility; release signing, backend configuration and current store requirements need final owner verification.

## Licenses

See [the complete accompanying notices](LICENSES/INDEX.txt) for the engine,
fonts, plugins and assets. Keep the `LICENSES` directory with every redistributed
Android or Web build; original-code Apache licensing does not replace third-party
terms. CI copies these notices beside both exports and includes them with the
Android artifact.

## Public source and local artifacts

Public repository: [Powder Pines](https://github.com/EthannYakabuski/powder-pines). Current source and this continuation documentation are tracked here. Prebuilt exports, real saves, private QA records, credentials and signing material stay outside the published source history. Local artifact availability is described in `HANDOFF.txt`; a fresh clone does not contain the original debug APK.

Original work is Apache-2.0; assets, fonts, engine and plugins retain their own terms in `LICENSES/`, `NOTICE` and source notices. Creature Mixer assets, where used, have custom non-NFT/non-blockchain terms and are not CC0.

## Round Three screenshot supplement

Eighteen fresh unchanged Android screenshots now provide six ordinary menu views per logical phone, 7-inch and 10-inch profile. See [the screenshot scope](docs/SCREENSHOTS_ROUND_THREE.md) and marketing/screenshots-round-three/capture-manifest.json for hashes, actual dimensions/readbacks and visual qualifications. The original APK and packages are unchanged; no rebuild or fresh gameplay/ad/offline pass is claimed. Older rotated screenshots remain dated evidence. The original whole-APK source commit is unknown; source matching is limited to nine recorded runtime inputs.
