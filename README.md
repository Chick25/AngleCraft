# angle_craft

A new Flutter project.

## AI Pose Assist

On Android, choose a built-in **standing** or **hand-on-hip** pose, then tap
the focus icon to enable on-device pose guidance. A yellow skeleton means the
pose is still being adjusted; green means the main joint checks have matched
for several processed frames. Built-in styles check general joint rules; they
do not compare against an exact reference photograph. For an imported image or
custom pose, the app checks the detected joint layout while allowing the
person to be repositioned and resized in the frame. The score is a geometric
heuristic, not a probability or a guarantee of an identical pose. Imported
references need visible shoulders, hips, and enough other body joints; images
that do not meet that requirement remain available for manual ghost-overlay
alignment. Pose detection identifies body landmarks and cannot tell whether a
person is physically present or displayed on another screen. Other built-in
catalog styles are currently manual guides only.

Camera frames and reference photos are processed locally with Google ML Kit.
The Android camera stream uses NV21, the format required by the ML Kit plugin.
Frames are skipped while the detector is busy to avoid building up latency.
This feature is currently Android-only; the existing camera and manual overlay
continue to work on other platforms.

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

## Custom Pose Guide & Camera Zoom

Open the pose catalog and tap **+** to create a lightweight custom pose. Choose
a context suggestion, drag joints on the vector silhouette, name the pose, and
save it locally. Only normalized joint coordinates and text are stored; no
reference photo is needed. Custom poses can be overlaid and compared with the
live pose guide on Android. Context tips are user-selected guidance, not automatic
recognition of objects such as railings. Pinch the live camera preview to zoom;
the compact zoom button shows the current magnification and opens a slider for
precise adjustment. When a guide is selected, pinching adjusts the guide by
default; use the labeled mode button to switch pinch gestures to camera zoom.
The guide-size slider provides an alternative to pinching. In the photo viewer,
pinch to zoom and pan; photo paging is paused while zoomed, and the zoom-reset
button restores paging. Tap the preview to set focus; double-tap to show or hide
the exposure control. When
supported by the camera, its vertical EV slider lets you brighten or darken the
live view and reset exposure to 0. Available EV values depend on the camera
hardware.

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
