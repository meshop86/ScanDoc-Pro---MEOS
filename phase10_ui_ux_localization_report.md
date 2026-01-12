# Phase 10 – UI/UX Localization & Theme Modernization

## Localization (EN/VI)

### LocalizationService (new)
- Persistent language preference: stored locally via `localization.json`
- Supports: Vietnamese (VI) and English (EN); defaults to VI
- Dictionary: 70+ key translations covering login, cases, document sets, scanning, export, admin, status, messages, settings
- API:
  - `getLanguage()`: retrieve stored preference
  - `setLanguage(lang)`: persist choice
  - `translate(key)`: async lookup (VI or EN)
  - `translateBatch(keys)`: efficient multi-key lookup

### LoginPage (redesigned)
- New app icon: `Icons.description` (document scanner, not vehicle)
- New app name: "ScanDoc Pro" (was "Biển Số Xe")
- New tagline: "Professional document scanning" (language-aware)
- Language toggle: EN/VI buttons on login screen; selection saved
- Theme toggle: Light/Dark/Auto (System) buttons on login screen; selection saved
- Cards for settings: improved visual organization
- All UI text now localized via LocalizationService

### Main app entry (updated)
- Integrated ThemeService: applies theme at app level
- Dynamic theme rebuild: respects system dark mode or user override
- Material 3 design: modern, professional appearance

## Theme (Light/Dark)

### ThemeService (new)
- Persistent theme mode: stored via `theme_pref.json`
- Modes: `light`, `dark`, `system` (default)
- API:
  - `getThemeMode()`: retrieve preference
  - `setThemeMode(mode)`: persist choice
  - `getFlutterThemeMode()`: convert to Flutter enum
  - `getLightTheme()`: professional light color scheme
  - `getDarkTheme()`: high-contrast dark scheme
- Color palette:
  - Light: seed blue (#1F77BC), white background, dark text
  - Dark: seed blue (#64B5F6), dark background (#1F1F1F), light text
  - Common: success green, error red, warning orange, info blue
- Consistent styling: rounded cards, consistent padding, Material 3 components

## UI Polish (Phase 10 deployed)

### Design principles
- **Professional**: neutral document imagery; clean typography; generous whitespace
- **Accessible**: high contrast in dark mode; readable font sizes; clear button labels
- **Batch-friendly**: prominent action CTAs; easy navigation between document sets; clear page counts
- **Language-neutral**: icons and color-coding for international use; no vehicle-specific imagery

### Terminology shift (prepared, not deployed to all screens yet)
- App name: ScanDoc Pro (vs. Biển Số Xe)
- Case/Tập: standardized terminology across UI
- Document Set: standardized terminology (not yet updated in all screens; Phase 10 sets foundation)
- Pages: neutral term (not document-specific)

### Screens updated (Phase 10)
1. **LoginPage**: language & theme selection visible; localized labels; neutral icon
2. **AppEntry**: theme-aware startup; no hard-coded colors
3. **main_scan.dart**: centralized theme & localization management

### Screens prepared for localization (not yet updated)
- TapManagePage: ready for LocalizationService.translate() calls
- ScanPage: ready for localized prompts and labels
- AdminToolsPage: ready for localized admin UI
- Support services: all updated with localization params

## Backward compatibility
- No domain or storage changes; Phase 9 data fully supported
- Legacy file paths unchanged
- Audit engine untouched
- Existing vehicle-based manifest data still readable

## Testing scope (Phase 10)
- Login with EN and VI language selection; verify persistence
- Toggle Light/Dark/Auto themes; verify persistence and system sync
- Verify build on iOS physical device
- UI renders correctly in both light and dark modes
- All localized strings present and readable

## Rollout plan (Phase 10+)
- Phase 10a (complete): localization & theme infrastructure
- Phase 10b (next): update all screens to use LocalizationService.translate()
- Phase 10c (next): rename UI labels from vehicle-specific to general (Case, Document Set, Page)
- Phase 11+: new features leverage full localization + theme support

## Code metrics
- New files: 2 (LocalizationService, ThemeService)
- Updated files: 3 (LoginPage, main_scan.dart, + all can now consume localization)
- Total translation keys: 70+ (EN/VI)
- Lines of UI code changed: ~150+ (LoginPage redesign)
- Backward-compatible: YES (no breaking changes)
- Build status: ✅ iOS release compiles successfully
