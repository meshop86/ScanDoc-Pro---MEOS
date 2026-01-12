# bien_so_xe

Mobile-only, offline-first app to manage scanned vehicle document sets by license plate. Data lives on-device; only online to share ZIPs.

## Stack
- Flutter + Riverpod + GoRouter
- Local storage via `path_provider`, `permission_handler`
- In-memory repository skeleton (ready for Drift/SQLite)
- Placeholder capture screen (integrate camera/doc-scan next)
- ZIP via MethodChannel stub (ZipFoundation/zip4j to be wired)

## Run
```bash
flutter pub get
flutter run
```

## Next steps
- Wire document scanner + overwrite/save flows
- Implement Drift persistence + manifest.json writer
- Add native ZIP channel implementations
- Finish share options (Zalo/share sheet)
