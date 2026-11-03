# ProAlbums — full project context

## 1. Vision
A production-quality Android gallery app that clones the *behaviour and layout* of the iQOO/Vivo "Albums" app (Photos / Albums / For You (Recommended) / Search tabs), with our own theme. Quality bar: Play Store ready, smooth at 120 Hz. No publish deadline — correctness and structure over speed.

## 2. Reference screens (docs/reference/s00–s08.jpg, 12 per sheet, ids #0–#97)
Source device screenshots of the iQOO app. Behaviour to replicate:

**Bottom nav (4 tabs):** Photos, Albums, For You/Recommended, Search. Dark theme (navy-black) is primary; one light-theme Albums shot (#90).

**Photos tab (#50, #49):** Title "Photos" + search icon + select-check icon + overflow. "Library — N items" header with filter chips All / Photo / Videos. Grid grouped by date headers ("Today October 31", "October 27 Tuesday") — each header has a checkbox for group select. Video tiles show duration badge. Fast-scroll thumb on right. Pinch zoom changes column count. Limited-access banner exists for partial permission.

**Selection mode (#37, #43, #45, #46, #48, #51, #59, #61):** Top: tri-state select-all checkbox, "N selected", X. Date headers show group checkboxes. Bottom bar: Share, Move/Copy, Create, Delete, More. More menu: Hide, Copy to clipboard, PDF/PPT, Print (some greyed when multi-select). Delete dialog: "Delete N items? Any selected item will be deleted from all albums and moved to 'Recently deleted'" with red Delete + Cancel. Drag across tiles selects ranges.

**Media viewer (#38–#47, #52, #53, landscape/video shots in s00–s03):** Top bar: back + date + time; right icons: document-scan (extract text), favorite heart, info (i). Bottom bar: Share, Edit, Delete, More. Filmstrip of neighbours above bottom bar (images and videos). Info card (#40, #47): Name, Time, Size, resolution, camera params + histogram, Path. More menu (image): Set as wallpaper, Extract text, Google Lens, Move/Copy, Hide, Super Documents, Rename, Compress size, Slideshow, Contact profile picture, Rotate, Copy to clipboard, PDF/PPT, Screen Mirroring, Print (menu scrolls; items depend on media). Video More: Set as wallpaper, Move/Copy, Hide, Rename, Compress size, Slideshow, Screen Mirroring, Convert to standard codec (H.264). Video has centre play button + seek/filmstrip. Tap toggles immersive mode (bars + date label hide). Delete toast "Moved to 'Recently deleted'" with Undo (#88, #90).

**Albums tab (#54–#59, #63, #73–#77, #90–#93, #96):** Title "Albums", search, "+" (new album dialog "New album" with text field, OK/Cancel #54), overflow (Select, Settings #58). Top block of system albums as 3-col tiles with name + count: All, Camera, Favorites, Videos, Screenshots. "More albums" section: user/other folders (empty ones show placeholder tile, count 0). "Intelligent classification" horizontal strip (People, Location, Documents, Group photo, Selfie, Plants, Food, Building, Accessories, Flower, Cars, Motorbikes — #57 shows the full page). Row "Cleanup suggestions N" and row "Recently deleted N". Later builds add Internal storage card (#93, #96) → Storage analysis page (#95, #97: donut of used GB + tiles Photos/Videos/Screenshots/Recently deleted/Other/Free). Album select mode (#59, #78–#82): tiles get checkboxes; bottom bar Move to Others / Share / Delete / Rename / More; "Change cover" pill appears when exactly 1 selected; Rename disabled for system albums. "Other albums" page (#80) lists grouped albums.

**Album detail (#60, #62, #65, #67, #68, #76):** Back + album name, select icon, overflow menu: Zoom in, Zoom out, Sort, Change cover. Same grid features as Photos. Sort = "Browsing order" dialog (newest/oldest first). Pictures (#76) is large title style.

**Move/Copy flow (#72, #69):** Move/Copy opens album picker: "New album" row first, then albums (Camera, Movies, Pictures…). "Select a method to add: Copy / Move / Cancel" dialog (#69) when adding items into an album via picker.

**Add-to-album picker "Select items" (#83, #84, #70, #71):** Segmented Photos | Albums, photo grid with checkboxes, bottom pill "Select items (N)" + Done. Change cover uses a similar picker.

**Recently deleted (#61, #64, #89):** Banner "Deleted content is kept for 30 days before permanent deletion". Tiles show "29 days" remaining badge. Select mode bottom bar: Restore, Delete. Settings (#92): toggle to turn off Recently deleted with a warning dialog (permanent delete).

**Cleanup suggestions (#66):** Cards: Duplicate images (count, thumbs, "Clean up now (2.40 MB)"), Similar images (count, "Clean up now (711 MB)").

**Settings (#92):** toggles: Live photo autoplay, Intelligent classification, Cleanup suggestions, Recently deleted (+ explanation), Save method after editing, Keep screen on while viewing.

**Search (#69–#71 background, s02):** Search bar "Search for photos", chips All / Images / Videos / Live photos, grid of results with same selection features.

**Favorites (#67):** heart badge on tiles; Favorites album.

## 3. What is built (phases 0–4.5 + perf work)
- Photos tab: shared GalleryGrid with date headers, sticky header, fast scroll, pinch zoom, drag select, selection controller, filter chips.
- Viewer: ViewerSession + openMediaViewer, scale/fade route, ExtendedImageGesturePageView, screen-size decoding (`viewerImageLongEdge` 1080–2560), filmstrip, video_player, rotation only in viewer, More actions menu scaffolding, info, favorite.
- Albums: MediaStore buckets via photo_manager; real folders under Pictures/<name>; blank albums via remembered folders; Android trash; Favorites in Drift; album detail on the shared grid with own zoom/order (`albumViewSettings`), first-300-then-full loading, skeleton while loading.
- Selection bar Move/Copy (branch `feature/move-copy`): bar → `context.push<bool>(AppRoutes.moveCopy(fromAlbumId:), extra: items)` → `MoveCopyPage` (albums feature; X + "Move/Copy", "New album" row, then real-folder albums via `transferDestinations`, source album hidden) → "Select a method to add" dialog → `runTransfer` (spinner) → snackbar → pops `true` → selection exits. `TransferTarget` (albumId = MediaStore bucket id, or `Pictures/<name>` for new/empty albums); native `FolderChannel.transfer` resolves the album's real RELATIVE_PATH (DCIM/Camera etc.). New-album flow + rename reuse the same pieces (`transfer_flow.dart`, `createNewAlbum`). ✅ Verified on device 2026-11-03: move into Camera (lands in DCIM/Camera/), new album + move, copy, move from inside an album (source album hidden in the list), move OUT of Camera.
  - Fixed: Move of other apps' files (Camera photos) failed silently when "Media management" (MANAGE_MEDIA) was on — the code skipped `createWriteRequest`, but MANAGE_MEDIA only skips the dialog, it does not allow direct writes. Now every move calls `createWriteRequest` (on this iQOO the system dialog still appears even with MANAGE_MEDIA allowed).
  - Known Android limit: a non-system app can put images only under DCIM/ or Pictures/ (videos also Movies/). E.g. copying a photo into "Movies" fails → reported as "N could not be copied".
- Perf session 2026-11-03 (iQOO I2302, profile, FrameMonitor v2 = per-burst p90/p99/max of max(build,raster), budget from peak Hz):
  - Normal scroll: 120 fps, ~0–1% jank. ✅
  - Drag-select auto-scroll was capped at 60 fps by `Timer.periodic(16ms)` → fixed with a vsync Ticker (px/second). Now 120 fps but 3–35% jank (avg ~8%).
  - Pinch zoom (cold-cache A/B, same sequence 4→6→8→6→4→3→4): worst frame per zoom ~15 ms → ~10 ms (jank frames 7 → 5). CPU profile showed the zoom frame = rows regroup (~5 ms) + per-tile Riverpod subscriptions (~6 ms) + tile build/layout. Fixed: `photosRowsFor`/`photosGroups` keepAlive families + idle prewarm of the other zoom levels (Photos tab only, album grid not yet); `GalleryItemsRow` watches selection/hearts once per row as bitmasks, `SelectableTile`/`MediaThumbnailView` are plain widgets; thumbnail reuse (`MediaThumbnailImage.readyAtLeast/readyBelow`) avoids re-decoding on zoom. Still ~1 janky frame (~10 ms build+layout) per zoom.
  - Texture uploads run on `1.io` (UploadTextureToPrivate), not raster — the earlier "zoom = upload burst" guess was wrong.
  - The ~20-frame raster bursts = the fast-scroll thumb's 180 ms fade-out, ~1.4 s after a scroll stops (scroll itself 0 jank). Raster in those frames is 2–3× normal, and how bad varies run to run (jank per fade: 10, 7, 3, 0). Tried: fade via colour alpha instead of AnimatedOpacity (no offscreen layer) → no change (20, 2, 0, 7, 13), so it was REVERTED. Best explanation: the GPU clocks down within ~1 s of idle (DVFS) and any animation then runs on a slow GPU — device behaviour, not an app bug. Possible later mitigation (UX call): hide the thumb instantly / shorter fade = fewer frames on the slow GPU. Perf work paused here (2026-11-03) to focus on features.
  - Not thermal: GPU ~60 °C during the session, throttling starts at 90 °C.
  - OPEN: raster climbs to 5–7 ms avg (15–34% jank) during long drag-select auto-scroll into new content (~1100 px/s); build side is fine (~1.6 ms).
  - Logging on this phone: some app processes write NOTHING to logcat (flutter run then cannot attach). Fallback: launch with `--disable-service-auth-codes`, find the VM service port from `/proc/net/tcp` (LISTEN, app uid 10331), `adb forward tcp:8181`, and read FrameMonitor's `proalbums.frames` events with the scratchpad listener.
  - OLD NOTE: raster spikes 12–21 ms during drag-select auto-scroll and after every pinch zoom (~20 frames). Trace: whole cost in `RenderPassGLES::EncodeCommandsInReactor` while cheap frames take 1.4 ms → most likely first-use texture upload of new thumbnails on Impeller GLES (uploads happen inside that slice). Ideas to measure: fewer/fixed thumbnail sizes (zoom cache reuse, less upload), cap new image uploads per frame, try Vulkan backend (find why GLES was chosen).
  - Tools: `flutter run --profile`; VM service on device port from logcat ("Dart VM service is listening on") → `adb forward tcp:8181 tcp:<port>`; scratchpad scripts `trace.dart` (records timeline, top slices) / `slowest.dart`.
- Perf (verified on device, earlier): flow jank ~5.8% build / 0.7% raster; fast scroll+drag 3.8%/0.5%.
- Unverified/open: viewer-back jank not diagnosed; occasional raster spike; shimmer skeleton not built (Photos still uses CircularProgressIndicator); `albumload1` needs build_runner; test fakes of `AlbumRepository` may need `getFirstAlbumItems`.

## 4. Key design (read before coding)
- `GalleryRow` = ToolbarRow | DateHeaderRow | ItemsRow, built by `GalleryRowsBuilder`. `GalleryGeometry` holds fixed heights and `GridOrigin.extent` (reported by `_SliverOriginReporter`). `GalleryGrid` takes `leadingSlivers`, rows, selection, viewer items.
- **Universal screen recipe (done 2026-11-03):** a screen wraps its Scaffold in `MediaScope(id, mediaContext, items, albumId, pickMode, onPick, onOpen, thumbnailLoader, tileLabel)` and uses `GalleryGrid` (+ `SelectionActionBar` while selecting). Everything below reads the scope; no parameters threaded.
  - Selection: `MediaSelectionController(scope)` family, autoDispose — every screen has its own (`MediaScope.photos`, `.album(id)`, `.picker(name)`, `.trash`). `mediaSelectionOf(context)`; use `exitIfOpen()` after awaits.
  - Actions: `MediaAction` (ONE list) + `MediaContext` (library/album/search/trash) → `selectionActionsFor(context)` (bar + More), `viewerMoreActionsFor(context, item)`, `isActionEnabled` (greyed rules). `runMediaAction()` is the ONE place each action is wired (exhaustive switch: a new action must be added there). Done: share, moveCopy, delete, restore, deleteForever, copyToClipboard (ClipboardChannel.kt: MediaStore image URIs in one ClipData; Android 13+ shows its own "Copied", older gets a snackbar; selection stays). Others = showComingSoon. More-menu rule: Copy to clipboard, PDF/PPT, Print enabled ONLY for pictures-only selections; Hide always.
  - Picker: `PickMode.single` (tap = `onPick`) / `multi` (checkboxes always, tap toggles, drag select). Used by Select items + Change cover.
  - `onOpen` replaces "open viewer" on tap (trash: start selecting); `thumbnailLoader` overrides the loader (trash thumbnails via TrashRepository); `tileLabel` = small badge ("29 days"), hides the video badge.
  - Viewer: `ViewerSession` holds `ViewerSessionData{items, mediaContext, albumId}`, filled by `openMediaViewer` from the scope. Viewer More menu = `viewerMoreActionsFor` + `runMediaAction`.
- Messages: always `AppToast` (shared/widgets/app_toast.dart; `showAppSnackBar` delegates): pill with app icon + text, theme `pillSurface`, 2 s (3.5 s with an action such as Undo), one at a time, fixed place above the bottom bar (`bottomInset` for the viewer). Capture `AppToast.of(context)` before awaits. Icon = `assets/branding/app_icon.png` (REPLACE when the real launcher icon is set).
- Loading: always `GalleryGridSkeleton` / `SliverGalleryGridSkeleton` (shimmer, `shared/widgets/shimmer_skeleton.dart`: one CustomPainter, no saveLayer, shared phase). No spinners in grids.
- Move/Copy progress: FolderChannel `transferProgress` (≤30/s) → `TransferProgress` callback → `_TransferProgressDialog` ("Moving to X", bar, N / total).
- Trash viewer: `ViewerSessionData.imageLoader` (= the scope's `thumbnailLoader`) feeds thumbnail, screen-size picture and filmstrip from the trash's native decoder; videos show a still frame (no player). `viewerBarActionsFor(context)` gives the viewer its own bar (trash: Restore, Delete); `viewerShowsFavorite`. `MediaAction.destructive` → theme `error` colour when enabled.

## 5. Roadmap (order)
1. ~~Shared grid + viewer universal (MediaSelection, MediaScope/context/actions, picker mode, trash on shared grid)~~ done. Next: the actions themselves via `runMediaAction` (Create, Hide, Copy to clipboard, PDF/PPT, Print, viewer More items), trash viewer.
2. ~~Shimmer skeleton in every grid~~ done.
3. Tabs: Search, For You/Recommended, Recently deleted (Trash viewer + restore/delete + 30-day badge), Cleanup suggestions, Storage analysis, Settings structure.
4. Later: vault/Hide (phase 6), intelligent classification (8), cleanup suggestions engine (9), backup (12).
5. Release prep: replace assets/branding/app_icon.png with the real icon, OFL font licence, licences page, R8 release test, signing, privacy policy, Play listing.

## 6. Working agreement
Finish a tab fully → optimise → Aayush commits. Explain why. No compiler/device in chat sessions earlier — Claude Code now can run `flutter analyze/test`; device profiling is still Aayush's (`flutter run --profile`, DevTools).
