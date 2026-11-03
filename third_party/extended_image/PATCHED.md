# extended_image 10.1.0 — ProAlbums patched copy

Copied from pub.dev `extended_image` 10.1.0 (MIT, see LICENSE; `example/`
left out) and used through `dependency_overrides` in the app's pubspec.yaml.

## The one change
`lib/src/editor/edit_action_details.dart` → `updateCropRect` (+ helper
`_uprightImageRectOnScreen`), marked "ProAlbums patch".

Bug: in the crop editor, when a corner was dragged past the picture's edge,
the original code pulled it back along the crop frame's DIAGONAL towards
the frame's centre, which also moved the other corners (the opposite corner
"shrank"). Patch: when the picture is turned by a multiple of 90° (always in
ProAlbums' editor), each side of the frame is simply stopped at the
picture's edge. Only for a FREE crop: with a fixed shape (A4, 1:1 ...) the diagonal keeps
the shape, so it keeps the original code, as do other angles.

## Updating the library later
1. Copy the new version's files here (lib, LICENSE, pubspec.yaml, README,
   CHANGELOG).
2. Re-apply the change above (search the old copy for "ProAlbums patch").
3. If upstream fixed the bug: delete this folder and the
   `dependency_overrides` entry instead.
