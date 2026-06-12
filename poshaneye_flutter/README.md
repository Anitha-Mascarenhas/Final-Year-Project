# PoshanEye Flutter App

A Flutter conversion of the PoshanEye TSX/Vite app — an AI-powered pediatric nutrition screening application.

## Screens Included
- **Dashboard** — Hero card, nearby hospitals, nutrition awareness cards, recent activity
- **Scan** — Camera interface with distraction mode toggle, target overlay, controls
- **Analysis Results** — MUAC value, AI confidence, clinical explanation, PDF export
- **Nutrition Plan** — Personalized daily meal regimen with clinical rationale
- **BMI Calculator** — Gender selector, age stepper, height/weight sliders, live BMI result
- **Clinical Benchmarks** — WHO growth standards, data table, growth trend chart
- **Voice Assistant** — Bottom sheet with animated mic orb and suggestion chips

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Dart SDK ≥ 3.0.0

### Setup
```bash
flutter pub get
flutter run
```

### Dependencies
- `google_fonts` — Montserrat + Inter fonts (matching the web design)
- `fl_chart` — Charts (for future growth chart enhancements)
- `percent_indicator` — Circular progress indicators
- `cached_network_image` — Efficient network image loading

## Project Structure
```
lib/
├── main.dart                     # App entry point
├── theme/
│   └── app_theme.dart            # Color palette + typography
└── screens/
    ├── main_scaffold.dart        # Bottom nav + layout wrapper
    ├── dashboard_screen.dart     # Home screen
    ├── scan_screen.dart          # Camera/scan screen
    ├── analysis_results_screen.dart
    ├── bmi_calculator_screen.dart
    ├── nutrition_plan_screen.dart
    ├── clinical_benchmarks_screen.dart
    └── voice_assistant_sheet.dart
```

## Design Notes
- Color system maps directly from Material You tokens used in the TSX (`primary`, `secondary`, `surface-container-*`)
- Typography uses Montserrat (headlines) + Inter (body) via `google_fonts`
- Animations mirror the `motion/react` transitions (fade + slide)
- Bottom nav replicates the elevated center Scan button pattern
