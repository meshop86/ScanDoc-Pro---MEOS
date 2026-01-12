class LabelOption {
  final String key;
  final String label;
  final List<String> values;
  final bool system;

  const LabelOption({
    required this.key,
    required this.label,
    required this.values,
    this.system = false,
  });
}

class LabelPresets {
  // System labels: auto-populated, read-only
  static const List<LabelOption> tapSystemLabels = [
    LabelOption(
      key: 'state',
      label: 'State',
      values: ['DRAFT', 'OPEN', 'LOCKED', 'EXPORTED'],
      system: true,
    ),
    LabelOption(
      key: 'tap_code',
      label: 'Tap Code',
      values: [],
      system: true,
    ),
  ];

  static const List<LabelOption> documentSystemLabels = [
    LabelOption(
      key: 'tap_code',
      label: 'Tap Code',
      values: [],
      system: true,
    ),
  ];

  // User labels: selectable, no free text
  static const List<LabelOption> tapUserLabels = [
    LabelOption(
      key: 'priority',
      label: 'Độ ưu tiên',
      values: ['low', 'normal', 'high'],
    ),
    LabelOption(
      key: 'channel',
      label: 'Kênh nhận',
      values: ['onsite', 'drop_off', 'other'],
    ),
  ];

  static const List<LabelOption> documentUserLabels = [];
}
