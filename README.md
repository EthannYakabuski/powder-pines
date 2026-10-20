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

AdMob is wired with Google's official Android test app/ad-unit IDs. Banner placement is on menus; interstitial opportunities occur every two completed rounds; rewarded offers grant their benefit only after the native earned-reward event. Consent-unavailable/no-fill conditions leave normal gameplay available. Google Play Games integration is prepared with local pending achievements/scores and symbolic ID maps; production setup is disabled until the owner supplies real IDs and console credentials. See platform/config.json and docs/PLATFORM_SETUP.md.

Store text, app/achievement/leaderboard icons, feature art and screenshot provenance are in marketing/. The human owner performs final backend configuration and testing, human playtesting and Google Play publication. Current build/verification status is recorded in HANDOFF.txt; do not infer production service verification from local or mocked tests.

## CI and Web

The hosted GitHub Actions workflow imports resources, requires game and service tests, exports Web and a native Android debug APK, then deploys Web to GitHub Pages. Build outputs and signing keys are excluded from source control. Actual workflow/deployment results are recorded in the handoff after publication.

## Future extension

Night Lights: floodlit runs, snowboard visitor cosmetics, and fresh slalom challenges. This is a future content idea; the initial game is intended to be independently playable.

The Android test preset uses minimum API 24 and target API 35 with Android texture imports enabled. This does not establish current Google Play release eligibility; release signing, backend configuration and current store requirements need final owner verification.

## Licenses

See [the complete accompanying notices](LICENSES/INDEX.txt) for the engine,
fonts, plugins and assets. Keep the `LICENSES` directory with every redistributed
Android or Web build; original-code Apache licensing does not replace third-party
terms. CI copies these notices beside both exports and includes them with the
Android artifact.

## Public source and deployment status

This repository publishes the existing local-test source package. The recorded HANDOFF and docs describe their dated local verification; they do not establish production service, physical-device, audio, browser or human acceptance.

GitHub-hosted build/test/artifact CI is configured. The Pages deployment job is explicitly skipped pending separate authorization; no live Pages site is claimed. No real saves, private coordinator evidence, credentials, signing identities or prebuilt APK/Web exports are committed. Build outputs remain CI artifacts.

Apache-2.0 covers original project work. Third-party assets, fonts, engine and plugins retain their own terms in LICENSES and source notices; where present, Creature Mixer custom terms exclude NFT/blockchain projects and are not CC0.
