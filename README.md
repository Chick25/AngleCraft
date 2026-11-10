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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
