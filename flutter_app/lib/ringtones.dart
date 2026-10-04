/// Built-in ringtones (original, generated for this app). Files live in assets/ringtones/.
class Ringtone {
  final String key;
  final String name;
  final String description;
  const Ringtone(this.key, this.name, this.description);
  String get asset => 'assets/ringtones/$key.mp3'; // path used by the alarm package
}

const ringtones = [
  Ringtone('sunrise', 'Sunrise Chimes', 'Gentle rising chimes'),
  Ringtone('bells', 'Morning Bells', 'Warm, full bells'),
  Ringtone('marimba', 'Marimba Pop', 'Bouncy and bright'),
  Ringtone('calm', 'Calm Waves', 'Soft, slowly swelling'),
  Ringtone('classic', 'Classic Alarm', 'The traditional beep-beep'),
  Ringtone('digital', 'Digital Pulse', 'Retro and impossible to ignore'),
];

Ringtone ringtoneByKey(String key) => ringtones.firstWhere((r) => r.key == key, orElse: () => ringtones.first);
