# ProAlbums — project rules for Claude Code

Flutter gallery app (appId `com.aayush.proalbums`), modelled on the iQOO "Albums" app. Android first (minSdk 31, target 36), Play Store quality.
Owner: Aayush. He writes Hinglish; reply in Hinglish. He makes the git commits himself (never commit/push unless asked). Work on the `dev` branch; do NOT create new branches unless he asks.

Project context (product, reference screens, status, roadmap) — auto-loaded; keep it updated after every finished task:
@docs/PROJECT_CONTEXT.md

Reference screenshots: `docs/reference/s00.jpg`–`s08.jpg` (contact sheets, 12 screens each, numbered #0–#97).

## Stack
Riverpod 3 + riverpod_generator (`dart run build_runner build -d`), go_router, fpdart, Drift, SharedPreferences, photo_manager, extended_image, share_plus, video_player, native_exif, wakelock_plus, intl, lucide_icons_flutter. Fonts bundled (no google_fonts). Impeller on opengles backend.

## Architecture
- Clean architecture, feature-first: `features/<name>/{domain,data,presentation}`.
- Avoid cross-feature dependencies. Shared UI in `shared/`, plumbing in `core/`.
- Gallery never imports albums. Openers set `ViewerSession` then `context.push(AppRoutes.viewer(id))` (helper: `openMediaViewer`).
- Routing: go_router `StatefulShellRoute.indexedStack`; full-screen routes use `parentNavigatorKey: rootNavigatorKey`; route strings only via `AppRoutes`.
- Every widget/dialog/screen uses the app theme: `context.colors`, `context.colorScheme`, `context.textTheme`. No hard-coded colours/fonts.
- Icons: ONLY `lucide_icons_flutter` (`LucideIcons.*`), never Material `Icons.*`. One exception: the FILLED favourite heart is `Icons.favorite` (Lucide has no filled icons) — red in the viewer, white on grid tiles; the empty heart stays `LucideIcons.heart`.

## Consistency rule (most important)
ONE shared grid (`GalleryGrid` + `GalleryRow`s from `GalleryRowsBuilder`) and ONE viewer for every tab (Photos, Album detail, Search, For You, Trash). Same features everywhere: drag-select, fast-scroll thumb, sticky date header, pinch zoom, SelectableTile, same thumbnail size/cache key. Never build a second grid/viewer. New features go into the shared component first; tabs only supply data (rows) and their own app bar/header.

## Performance rules
- Profile on a real device: `flutter run --profile` (iQOO I2302, 120 Hz, budget 8.3 ms). Honest metric = max(build, raster), not `elapsed`. Measure before/after; do not guess.
- Thumbnails: one size function `thumbnailSizeFor` (step 32, 96–512), one cache key `(id,size)`. ImageCache 256 MB / 3000 (set in main.dart).
- No per-tile `ref.watch` for never-changing providers (use `ref.read`). Never use `SliverLayoutBuilder` to measure (rebuilds subtree every scroll frame) — use render-object reporters.
- Rows are fixed height. Rebuild only what changes. Load big albums in slices (first 300, then full).

## Workflow
- One feature/phase at a time, fully finished, then optimise, then Aayush commits.
- ASK before doing anything new or not explicitly requested (new behaviour, UI choices, extra refactors). Propose, wait for a yes.
- Run `dart run build_runner build -d`, `flutter analyze`, `flutter test` before saying "done". State what is unverified on device.
- Tests next to the feature under `test/features/...`.
- Do not touch user-owned files (`app.dart`, `main.dart`, theme files, `settings_screen.dart`) without saying so.
- Explain WHY, admit mistakes/unknowns. Show `git diff` summary at the end.
- Release prep (later): OFL font licence, OSS licences page, R8 release test, signing, privacy policy, Play listing.
