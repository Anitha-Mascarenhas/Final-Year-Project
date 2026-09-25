# PoshanEye - Flutter Authentication & Home Dashboard

## Setup & Local Video Assets
This project requires 3 large MP4 video files (~130 MB each) that are excluded from Git repository history via `.gitignore`.

After cloning the repository, every team member must manually place the three video files inside the local static asset directories:

```
public/videos/
├── video1.mp4
├── video2.mp4
└── video3.mp4
```

(For Flutter Web builds, place copies or links in `web/videos/` as well):
```
web/videos/
├── video1.mp4
├── video2.mp4
└── video3.mp4
```

### Expected Videos:
- `video1.mp4` (Albatross interactive mascot)
- `video2.mp4` (Shark interactive mascot)
- `video3.mp4` (Cheetah interactive mascot)

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
