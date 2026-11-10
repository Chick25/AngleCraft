# angle_craft

A new Flutter project.

## AI Pose Assist

On Android, choose a built-in **standing** or **hand-on-hip** pose, then tap
the focus icon to enable on-device pose guidance. A yellow skeleton means the
pose is still being adjusted; green means the main joint checks have matched
for several processed frames. The score is a heuristic guide, not a guarantee
of an identical pose. Other catalog styles and gallery images remain available
for manual ghost-overlay alignment.

Pose frames are processed locally with Google ML Kit. Frames are skipped while
the detector is busy to avoid building up latency. This feature is currently
Android-only; the existing camera and manual overlay continue to work on other
platforms.

## Angle Vault

After taking a photo, choose **LƯU GÓC** in the confirmation message to save
the captured reference image and the current grid, overlay, opacity, and
overlay-position settings to the on-device Angle Vault. Saved entries are
available offline; open the bookmark icon on the camera to preview them, mark
favorites, delete entries, or load a saved configuration back into the camera.
Images are copied to the app's documents directory and settings are stored in
Hive. Nothing is uploaded.

## Capture & Local Media Gallery

The shutter temporarily hides the camera controls, level indicator, grid, and
pose overlays before capturing a clean camera frame. Captures are saved to the
app's local photo collection and exported to the device photo library. Open the
photo-library icon on the camera to browse images, pinch to zoom, share, or
delete the app's local copy of a capture. A copy already exported to the
device's photo library is not removed by deleting it from AngleCraft.
The photo viewer also provides lightweight tone and lighting previews using
Flutter's built-in color filters; previews do not modify the original or
shared image.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
