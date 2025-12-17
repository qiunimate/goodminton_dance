# Badminton Footwork Trainer Mobile App

This is a Flutter mobile application ported from the Python desktop version. It runs on both Android and iOS.

## Prerequisites

1. **Install Flutter**: Follow the instructions at [flutter.dev](https://flutter.dev/docs/get-started/install).
2. **Android Setup**: Ensure you have Android Studio and the Android SDK installed.
3. **iOS Setup** (Mac only): Ensure you have Xcode installed.

## How to Run

1. Open a terminal in this directory (`mobile_app`).
2. Get dependencies:
   ```bash
   flutter pub get
   ```
3. Connect your device (or start an emulator).
   - **Note**: The camera might not work on the iOS simulator. Use a real device.
   - Android emulator camera needs to be configured to use the webcam.
4. Run the app:
   ```bash
   flutter run
   ```

## Troubleshooting

- **Permissions**: If the camera doesn't open, ensure you've granted camera permissions. The app requests them on startup.
- **Android Min SDK**: If you see an error about `minSdkVersion`, open `android/app/build.gradle` and change `minSdkVersion` to 21 or higher.
- **iOS Info.plist**: For iOS, you need to add `NSCameraUsageDescription` to `ios/Runner/Info.plist`. (This is automatically handled if you use `flutter create`, but check if you need to add it manually).

### Adding iOS Permissions
Open `ios/Runner/Info.plist` and add:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to detect body movements for training.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for video recording (optional).</string>
```
