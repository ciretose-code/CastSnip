CastSet - reimagined as a fancy replacement for Forecast

## Building

### Maintainers

Open `CastSnip.xcodeproj` in Xcode and build as usual.

### Contributors (other Apple teams)

The checked-in `.xcodeproj` may be signed for a specific team. To build with your own team without fighting over team IDs in git:

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Copy the local signing config and set your Team ID:
   ```bash
   cp Configs/Local.xcconfig.example Configs/Local.xcconfig
   # edit Configs/Local.xcconfig — set DEVELOPMENT_TEAM
   ```
3. Generate a local project: `xcodegen`
4. Open the generated `CastSnip.xcodeproj` and build.

Edit `project.yml` if you need a different bundle identifier or other project settings for your fork.

**Please do not commit** a regenerated `.xcodeproj` whose only change is your `DEVELOPMENT_TEAM`. Keep `Configs/Local.xcconfig` local (it is gitignored). Structural project changes should go through `project.yml` (or a maintainer updating the checked-in project) via pull request.

## Releasing

Maintainers cut a signed, notarized CastSet DMG from `main` and publish it to GitHub Releases:

```bash
./Scripts/release.sh --dry-run   # archive, sign, package; stop before notarizing
./Scripts/release.sh             # notarize, staple, and publish
```

One-time notary setup (keychain profile `castsnip-notary`):

```bash
xcrun notarytool store-credentials "castsnip-notary" \
  --key ~/.private_keys/AuthKey_<KEY_ID>.p8 \
  --key-id <KEY_ID> \
  --issuer <ISSUER_ID>
```

The shipped app is `CastSet.app` inside a notarized DMG. In-app **Check for Updates…** (CastSet menu and Settings → Updates) polls this repo’s GitHub Releases and opens the download page when a newer build is available.
