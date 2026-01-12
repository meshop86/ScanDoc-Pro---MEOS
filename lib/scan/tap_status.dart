enum TapStatus { draft, open, locked, exported }

extension TapStatusX on TapStatus {
  String get value {
    switch (this) {
      case TapStatus.draft:
        return 'DRAFT';
      case TapStatus.open:
        return 'OPEN';
      case TapStatus.locked:
        return 'LOCKED';
      case TapStatus.exported:
        return 'EXPORTED';
    }
  }

  bool get isDraft => this == TapStatus.draft;
  bool get isOpen => this == TapStatus.open;
  bool get isLocked => this == TapStatus.locked;
  bool get isExported => this == TapStatus.exported;

  static TapStatus from(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'DRAFT':
        return TapStatus.draft;
      case 'LOCKED':
        return TapStatus.locked;
      case 'EXPORTED':
        return TapStatus.exported;
      case 'OPEN':
      default:
        return TapStatus.open;
    }
  }
}
