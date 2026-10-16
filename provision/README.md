# Android Box Provisioning Kit

Programs a new Android box / Firestick with your full app lineup and settings in
one command. Safe to re-run on the same box any time (installs just upgrade).

## Fastest path (Windows, zero setup)

Already have one box set up exactly how you want it? Clone it:

1. Download this `provision` folder to your computer
   (GitHub: green **Code** button → Download ZIP → unzip → open `provision`).
2. Enable ADB Debugging on the **golden box** (your finished one), then
   right-click **`capture.ps1`** → **Run with PowerShell**. It downloads ADB
   by itself and pulls every app you installed on that box into `apks\`.
3. For each **new box**: enable ADB Debugging, then right-click
   **`bootstrap.ps1`** → **Run with PowerShell** and enter the new box's IP.
4. When a TV asks **"Allow USB debugging?"** → tick *Always allow* → OK.

Note: capture copies the *apps*, not their in-app settings. For your IPTV
player's playlists/logins, use the app's own backup/export on the golden box,
put the backup file in `configs\` (it gets copied to every new box's
Download folder), and restore from it in the app on first launch.

The manual steps below are only for Mac users or if you prefer to set things
up yourself.

```
provision/
├── provision.ps1          <- run this on Windows (PowerShell)
├── provision.sh           <- run this on Mac/Linux (or Git Bash on Windows)
├── apks/                  <- drop your APK files here (not committed to git)
├── configs/               <- optional: files to copy to every box (playlists etc.)
└── customers.csv.example  <- copy to customers.csv to provision from a list
```

## One-time computer setup

### 1. Install ADB

- **Windows:** download [SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools),
  unzip to `C:\platform-tools`, then add that folder to PATH:
  Start menu → "Edit the system environment variables" → Environment Variables →
  select `Path` → Edit → New → `C:\platform-tools` → OK.
  Open a **new** PowerShell window and check: `adb version`
- **Mac:** `brew install android-platform-tools` then check `adb version`

### 2. Fill the APK kit

Put every APK you install on a box into `apks/`. Get them from official
sources (APKMirror is the trusted mirror for apps not on a store). Examples:
your IPTV player, Downloader, a file manager.

### 3. Set your main app's package name

Open `provision.ps1` (or `provision.sh`) and set `MainAppPackage` at the top —
it's used for the final "does the app actually launch" test.
TiviMate is `ar.tvplayer.tv`; find any app's package after a first install with:

```
adb shell pm list packages | findstr /i tivi     (Windows)
adb shell pm list packages | grep -i tivi        (Mac/Git Bash)
```

## Per-box routine

1. Unbox, connect the box to the same Wi-Fi as your computer.
2. Enable ADB debugging on the box:
   - **Fire TV:** Settings → My Fire TV → About → click device name 7 times,
     then Developer Options → **ADB Debugging ON**
   - **Android TV box:** Settings → Device Preferences → About → click Build
     7 times, then Developer Options → **Network debugging ON**
3. Note the box's IP address (Settings → Network).
4. On the computer, from this folder:

   ```powershell
   .\provision.ps1 192.168.1.50        # Windows
   ```
   ```bash
   ./provision.sh 192.168.1.50         # Mac / Git Bash
   ```

5. First contact only: the TV shows **"Allow USB debugging?"** — tick
   *Always allow* and press OK with the box's remote. The script waits up to
   60 seconds for this.
6. Watch the summary at the end. `DONE` = box is ready.

Several boxes at once: `.\provision.ps1 192.168.1.50 192.168.1.51 192.168.1.52`

## Provisioning from a customer list

Copy `customers.csv.example` to `customers.csv` (kept out of git — it's
customer data), fill it in, then:

```powershell
.\provision.ps1 -Csv customers.csv      # Windows
./provision.sh --csv customers.csv      # Mac / Git Bash
```

## What the script does to each box

1. Installs every APK in `apks/`
2. Sets the screen to never sleep
3. Copies everything in `configs/` to the box's `/sdcard/Download/`
4. Launches your main IPTV app to verify the install worked
5. Disconnects and prints an OK/FAILED summary

## Troubleshooting

| Symptom | Fix |
|---|---|
| `adb not found` | PATH not set, or open a new terminal window (step 1) |
| `Cannot reach <ip>` | ADB debugging off, wrong IP, or box on a different network. Some boxes turn debugging off after a reboot — re-toggle it. |
| `never authorized` | Accept the Allow prompt on the TV (tick *Always allow*), re-run |
| Install fails with `INSTALL_FAILED_NO_MATCHING_ABIS` | Wrong APK build for that box's CPU — download the arm/armeabi-v7a (or universal) variant |
| App launch test fails | Package name at the top of the script doesn't match your app |
