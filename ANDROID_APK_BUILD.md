# Android APK Build Guide (Trusted Web Activity)

Your punaHub app can be wrapped as a native Android APK using **Trusted Web Activity (TWA)**. This keeps all your existing Web Push notifications working perfectly.

## What is TWA?

Trusted Web Activity wraps your PWA in a native Android app that:
- ✅ Shows your web app in fullscreen (no browser UI)
- ✅ Supports **all Web Push notifications** (background + foreground)
- ✅ Can be published to Google Play Store
- ✅ Works offline with service worker
- ✅ Adds to home screen like native app

---

## Prerequisites

1. **Node.js 16+** installed
2. **Java JDK 11+** installed
3. **Android SDK** with build-tools
4. Your domain **must serve over HTTPS**
5. `assetlinks.json` must be accessible at `/.well-known/assetlinks.json`

---

## Step 1: Install Bubblewrap CLI

```bash
npm install -g @bubblewrap/cli
```

---

## Step 2: Initialize TWA Project

```bash
cd sex-main

# Initialize with your domain
bubblewrap init --manifest https://your-domain.com/manifest.json

# Or use the local twa-manifest.json
bubblewrap init --manifest ./twa-manifest.json
```

**When prompted:**
- **Application name**: `punaHub`
- **Short name**: `punaHub`  
- **Start URL**: `/`
- **Icon URL**: Press Enter to use manifest
- **Maskable icon URL**: Press Enter
- **Monochrome icon URL**: Press Enter
- **Display mode**: `standalone`
- **Theme color**: `#0d0f14`
- **Background color**: `#0d0f14`

---

## Step 3: Build APK

```bash
# Build debug APK
bubblewrap build

# Or build release APK (requires signing)
bubblewrap build --release
```

APK will be output to `app/build/outputs/apk/release/app-release-signed.apk`

---

## Step 4: Get SHA-256 Fingerprint for Asset Links

After first build, get your certificate fingerprint:

```bash
# For debug build
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# For your release keystore
keytool -list -v -keystore android.keystore -alias punahub
```

Look for `SHA256:` and copy the fingerprint.

---

## Step 5: Update assetlinks.json

Edit `/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.punahub.app",
      "sha256_cert_fingerprints": [
        "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
      ]
    }
  }
]
```

**Upload this file to your server** at:
```
https://your-domain.com/.well-known/assetlinks.json
```

Must return `Content-Type: application/json`

---

## Step 6: Test APK Installation

```bash
# Install to connected Android device
adb install app/build/outputs/apk/release/app-release-signed.apk

# Or drag APK to Android emulator
```

---

## Push Notifications in APK

Your existing Web Push setup works automatically:

```javascript
// Same code works in APK
await window.__punaPush.requestPermission(userEmail);
await window.__punaPush.send(toEmail, 'Title', 'Body', { type: 'follow' });
```

**Android-specific features enabled:**
- ✅ Notification channels (Android 8+)
- ✅ Vibration patterns
- ✅ Action buttons
- ✅ High priority FCM delivery

---

## Publishing to Play Store

1. **Create Play Console account** ($25 one-time)
2. **Build AAB** (Android App Bundle):
   ```bash
   bubblewrap build --release --format aab
   ```
3. **Upload `app-release-signed.aab`** to Play Console
4. **Set up app signing** in Play Console
5. **Update assetlinks.json** with Play Store signing key

---

## Troubleshooting

### "Digital asset links not verified"
- Ensure `assetlinks.json` is accessible at exact URL
- Check HTTPS is working
- Verify SHA-256 fingerprint matches

### Push notifications not working in APK
- Check `gcm_sender_id` in `manifest.json`
- Ensure VAPID keys match between client and Edge Function
- Test push in browser first

### App opens in browser instead of TWA
- Rebuild with `bubblewrap build`
- Clear Android app data
- Check `assetlinks.json` is valid

---

## Files Added for TWA

| File | Purpose |
|------|---------|
| `/.well-known/assetlinks.json` | Validates domain ownership for TWA |
| `/twa-manifest.json` | TWA build configuration |
| `/ANDROID_APK_BUILD.md` | This guide |

---

## Quick Commands Reference

```bash
# Full rebuild
bubblewrap build

# Update with new manifest changes
bubblewrap update

# Build debug version
bubblewrap build --debug

# Build release with signing
bubblewrap build --release
```

---

## Need Help?

- [Bubblewrap Docs](https://github.com/GoogleChromeLabs/bubblewrap)
- [TWA Guide](https://developer.chrome.com/docs/android/trusted-web-activity/)
- [Play Store Publishing](https://play.google.com/console/)
