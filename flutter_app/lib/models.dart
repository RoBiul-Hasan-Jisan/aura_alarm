class Affirmation {
  final String id;
  final String text;
  final String category;
  final bool isFavorite;

  Affirmation({required this.id, required this.text, required this.category, required this.isFavorite});

  factory Affirmation.fromJson(Map<String, dynamic> j) => Affirmation(
        id: j['_id'],
        text: j['text'],
        category: j['category'] ?? 'General',
        isFavorite: j['isFavorite'] ?? false,
      );
}

class Alarm {
  final String id;
  final String label;
  final String time; // "HH:mm"
  final List<int> repeatDays; // 1=Mon..7=Sun
  final bool enabled;
  final String? affirmationId;
  final String? affirmationText;
  final String? affirmationCategory;
  final String ringtone;
  final int snoozeMinutes;
  final bool vibrate;

  Alarm({
    required this.id,
    required this.label,
    required this.time,
    required this.repeatDays,
    required this.enabled,
    this.affirmationId,
    this.affirmationText,
    this.affirmationCategory,
    this.ringtone = 'sunrise',
    this.snoozeMinutes = 5,
    this.vibrate = true,
  });

  factory Alarm.fromJson(Map<String, dynamic> j) {
    final aff = j['affirmationId']; // populated object or null
    return Alarm(
      id: j['_id'],
      label: j['label'] ?? '',
      time: j['time'],
      repeatDays: List<int>.from(j['repeatDays'] ?? []),
      enabled: j['enabled'] ?? true,
      affirmationId: aff is Map ? aff['_id'] : null,
      affirmationText: aff is Map ? aff['text'] : null,
      affirmationCategory: aff is Map ? aff['category'] : null,
      ringtone: j['ringtone'] ?? 'sunrise',
      snoozeMinutes: (j['snoozeMinutes'] ?? 5) as int,
      vibrate: j['vibrate'] ?? true,
    );
  }

  /// "07:30" -> "7:30 AM"
  String get prettyTime {
    final p = time.split(':');
    final h = int.parse(p[0]);
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${p[1]} ${h < 12 ? 'AM' : 'PM'}';
  }

  String get repeatLabel {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    return repeatDays.map((d) => names[d - 1]).join(', ');
  }
}
