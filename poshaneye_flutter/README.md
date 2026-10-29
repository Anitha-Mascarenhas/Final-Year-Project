# PoshanEye - Flutter Authentication & Home Dashboard

## Setup & Local Video Assets
Mascot videos are large MP4 files and are excluded from Git via `.gitignore`.
To enable video playback on both Flutter mobile and web, obtain these files
from a teammate and place them in `assets/videos/`:

```
assets/videos/
├── albatross.mp4
├── cheetah.mp4
└── shark.mp4
```

The app loads these as Flutter assets. If an asset is missing, mascot mode
shows its animated preview instead of remaining on a loading screen. Web
deployments may also provide the legacy static files under `web/videos/`
(`video1.mp4` for Albatross, `video2.mp4` for Shark, and `video3.mp4` for
Cheetah) as a web-only fallback.

---

## Run:
1. `flutter pub get`
2. `flutter run -d chrome` (or `flutter run`)

### Parent demo sign-in:
- Child ID: PE-1048
- Password: 12345678

This sign-in is local prototype validation only. Replace it with a backend authentication service before production use.

### UX Architecture Notes:
- `go_router` owns the role and authentication entry routes with curved fade/scale transitions.
- `flutter_riverpod` owns session-level state; form input remains local to each form screen.
- `flutter_animate` provides staggered entrance motion on the role-selection surface.
- The existing custom `AppTheme` defines Material 3 component defaults and fluid page transitions.
