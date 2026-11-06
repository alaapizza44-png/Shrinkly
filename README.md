# Shrinkly - video compressor (prototype)

Shrink your own videos to a size you choose (10 / 25 / 50 / 100 MB, a custom number, or "Auto"), privately on the phone.
Compression runs on the device (nothing is uploaded), continues in the background with a notification, and saves the result
to the Movies folder. English + Arabic (follows the device language). The app name "Shrinkly" is a placeholder - check it is
free on Google Play before publishing, and change it in `tool/patch_android.py` (`APP_LABEL`), `lib/` and the workflows.

## Build the APK without Android Studio
1. Create a new GitHub repository and upload **all files and folders** of this project (keep the folder structure:
   `.github/workflows`, `docs`, `lib`, `tool`, `pubspec.yaml`, `analysis_options.yaml`).
2. Open the **Actions** tab. "Build APK" starts by itself (about 10-15 min). If it does not, choose it and press "Run workflow".
3. When it turns green, open the run and download **Shrinkly-apk** from *Artifacts*, unzip it and install `app-release.apk`.
4. If it fails (red), open the failed step and send the last 30-40 lines of the log.

## Ads (AdMob)
By default Google's TEST ads are used. For real ads create banner + interstitial units in AdMob and add the repository secrets
`ADMOB_APP_ID`, `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID` (Settings -> Secrets and variables -> Actions).

## Signing and privacy policy
Same steps as in the SnappyDown README: run "Create signing key (run once)", add `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`; publish `docs/privacy.html` with GitHub Pages (folder `/docs`). Replace `YOUR_EMAIL@example.com` in
`docs/privacy.html` and `lib/config.dart` with your real contact e-mail first.

## Speed notes
Compression re-encodes every frame on the phone, so large / long / high-resolution / 60 fps videos take a while and the phone may
warm up. Version 2 computes the bitrate itself from the video's duration (single pass) instead of letting the plugin chase a size,
and switches to a lower resolution when the target is very small. Compare with the same file as before and tell me the timing.

## Leaving the app while compressing
Back now sends the app to the background while a compression is running (instead of closing it), the list is saved on the
device, and the app uses a single activity so tapping the progress notification returns to it. If Android still closes the app,
the list comes back when you reopen it and an interrupted video shows "Stopped - press Compress to try again".

## What is NOT verified yet
This prototype has never been compiled or run. It uses the `light_compressor_v2` plugin (API read from its documentation).
Please test on a real phone: a short video, a large video (1 GB+), cancelling, leaving the app during compression, and the
"target size" accuracy. Compressed size is approximate: very small targets may not be reachable (the app then says so).

## Files
`lib/services/compress_queue.dart` (the compression queue), `lib/screens/home_screen.dart` (the whole UI),
`tool/patch_android.py` (manifest, minSdk, signing, icons), `.github/workflows/build-apk.yml`.
