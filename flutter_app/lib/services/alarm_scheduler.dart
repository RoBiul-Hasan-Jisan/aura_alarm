import 'dart:async';
import 'dart:convert';
import 'package:alarm/alarm.dart' as ap; // prefixed: our own model is also called Alarm
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart' as m;
import '../nav.dart';
import '../ringtones.dart';
import '../screens/ring_screen.dart';
import 'api_service.dart';
import 'ringtone_player.dart';

/// Everything the ring screen needs to know about a ringing alarm.
class RingInfo {
  final int settingsId;
  final String alarmId; // MongoDB id ('' for the test alarm)
  final String label;
  final String? text;
  final String? category;
  final String ringtone;
  final int snooze;
  final bool vibrate;
  final bool oneTime;
  final bool web;

  const RingInfo({
    required this.settingsId,
    required this.alarmId,
    required this.label,
    this.text,
    this.category,
    this.ringtone = 'sunrise',
    this.snooze = 5,
    this.vibrate = true,
    this.oneTime = false,
    this.web = false,
  });

  bool get isSnoozeRing => settingsId % 16 == AlarmScheduler.snoozeSlot;

  RingInfo copyWith({int? settingsId, bool? web}) => RingInfo(
        settingsId: settingsId ?? this.settingsId,
        alarmId: alarmId, label: label, text: text, category: category, ringtone: ringtone,
        snooze: snooze, vibrate: vibrate, oneTime: oneTime, web: web ?? this.web,
      );

  String toPayload() => jsonEncode({
        'alarmId': alarmId, 'label': label, 'text': text, 'cat': category,
        'tone': ringtone, 'snooze': snooze, 'vibrate': vibrate, 'once': oneTime,
      });

  factory RingInfo.fromSettings(ap.AlarmSettings s) {
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode(s.payload ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    return RingInfo(
      settingsId: s.id,
      alarmId: j['alarmId'] ?? '',
      label: j['label'] ?? s.notificationSettings.title,
      text: j['text'],
      category: j['cat'],
      ringtone: j['tone'] ?? 'sunrise',
      snooze: (j['snooze'] ?? 5) as int,
      vibrate: j['vibrate'] ?? true,
      oneTime: j['once'] ?? false,
    );
  }
}

/// Turns the alarms stored in MongoDB into real device alarms that ring like a normal alarm clock.
///
/// Android / iOS: uses the `alarm` package (rings with the app closed, shows a notification, vibrates, loops the
/// ringtone). Repeating alarms are scheduled for every matching day in the next 14 days each time the app syncs.
/// Web: browsers cannot ring in the background, so alarms ring while the tab is open (checked every second).
class AlarmScheduler {
  static const snoozeSlot = 14; // id slot for snoozed / test alarms (never cleaned up by sync)
  static const _onceSlot = 15; // id slot for one-time alarms
  static const _horizonDays = 14;
  static const _testId = 0x7E57 * 16 + snoozeSlot;

  static bool get _native =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static List<m.Alarm> _cache = [];
  static final Set<int> _showing = {};
  static final Set<String> _webFired = {};
  static Timer? _webTimer;
  static bool _syncing = false, _syncAgain = false;

  // ---------- setup ----------
  static Future<void> init() async {
    if (_native) {
      await ap.Alarm.init();
      ap.Alarm.ringing.listen((set) {
        for (final a in set.alarms) {
          _showRing(RingInfo.fromSettings(a));
        }
      });
    } else {
      _webTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _webTick());
    }
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    try {
      await Permission.notification.request();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final st = await Permission.scheduleExactAlarm.status;
        if (st.isDenied) await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {}
  }

  // ---------- ids & times ----------
  static int _baseId(String mongoId) => int.parse(mongoId.substring(mongoId.length - 6), radix: 16);

  static RingInfo _infoFor(m.Alarm a, {bool web = false}) => RingInfo(
        settingsId: _baseId(a.id) * 16 + (web ? 12 : 0),
        alarmId: a.id,
        label: a.label.isEmpty ? 'Alarm' : a.label,
        text: a.affirmationText,
        category: a.affirmationCategory,
        ringtone: a.ringtone,
        snooze: a.snoozeMinutes,
        vibrate: a.vibrate,
        oneTime: a.repeatDays.isEmpty,
        web: web,
      );

  /// Upcoming ring times for an alarm: (id, time) pairs.
  static List<(int, DateTime)> _occurrences(m.Alarm a, DateTime now) {
    final p = a.time.split(':');
    final h = int.parse(p[0]), mi = int.parse(p[1]);
    final base = _baseId(a.id) * 16;
    if (a.repeatDays.isEmpty) {
      var at = DateTime(now.year, now.month, now.day, h, mi);
      if (!at.isAfter(now)) at = DateTime(now.year, now.month, now.day + 1, h, mi);
      return [(base + _onceSlot, at)];
    }
    final out = <(int, DateTime)>[];
    for (var i = 0; i < _horizonDays; i++) {
      final at = DateTime(now.year, now.month, now.day + i, h, mi);
      if (!at.isAfter(now) || !a.repeatDays.contains(at.weekday)) continue;
      final epochDay = DateTime.utc(at.year, at.month, at.day).difference(DateTime.utc(1970)).inDays;
      out.add((base + epochDay % _horizonDays, at)); // stable id per calendar date
    }
    return out;
  }

  static ap.AlarmSettings _settings(RingInfo i, int id, DateTime at) => ap.AlarmSettings(
        id: id,
        dateTime: at,
        assetAudioPath: ringtoneByKey(i.ringtone).asset,
        loopAudio: true,
        vibrate: i.vibrate,
        warningNotificationOnKill: defaultTargetPlatform == TargetPlatform.iOS,
        androidFullScreenIntent: true,
        payload: i.toPayload(),
        volumeSettings: ap.VolumeSettings.fade(fadeDuration: const Duration(seconds: 6)), // not const: the library asserts on Duration
        notificationSettings: ap.NotificationSettings(
          title: i.label,
          body: i.text ?? 'Rise and shine. Today is yours.',
          stopButton: 'Stop',
        ),
      );

  static bool _same(ap.AlarmSettings a, ap.AlarmSettings b) =>
      a.dateTime.isAtSameMomentAs(b.dateTime) &&
      a.assetAudioPath == b.assetAudioPath &&
      a.vibrate == b.vibrate &&
      a.payload == b.payload &&
      a.notificationSettings.body == b.notificationSettings.body &&
      a.notificationSettings.title == b.notificationSettings.title;

  // ---------- sync ----------
  /// Called every time the app loads the alarm list.
  static Future<void> sync(List<m.Alarm> alarms) async {
    _cache = alarms;
    if (!_native) return; // web uses the in-tab timer
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _syncAgain = false;
        await _syncNative(_cache);
      } while (_syncAgain);
    } catch (e) {
      debugPrint('Alarm sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _syncNative(List<m.Alarm> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final wanted = <int, ap.AlarmSettings>{};
    final finished = <String>[]; // one-time alarms that already rang

    for (final a in alarms) {
      final key = 'once_${a.id}';
      if (!a.enabled) {
        await prefs.remove(key);
        continue;
      }
      final once = a.repeatDays.isEmpty;
      if (once) {
        // We remember when a one-time alarm was due. If that moment has passed (even while the app was closed)
        // it has rung, so switch it off instead of scheduling it again for tomorrow.
        final saved = prefs.getString(key)?.split('|');
        if (saved != null && saved.length == 2 && saved[1] == a.time) {
          final due = DateTime.tryParse(saved[0]);
          if (due != null && !due.isAfter(now)) {
            await prefs.remove(key);
            finished.add(a.id);
            continue;
          }
        }
      }
      for (final (id, at) in _occurrences(a, now)) {
        wanted[id] = _settings(_infoFor(a), id, at);
        if (once) await prefs.setString(key, '${at.toIso8601String()}|${a.time}');
      }
    }

    final existing = await ap.Alarm.getAlarms();
    final ringingIds = ap.Alarm.ringing.value.alarms.map((e) => e.id).toSet();
    for (final s in existing) {
      if (s.id % 16 == snoozeSlot || wanted.containsKey(s.id) || ringingIds.contains(s.id)) continue;
      if (!s.dateTime.isAfter(now)) continue; // due right now: leave it alone
      await ap.Alarm.stop(s.id); // deleted / disabled / edited alarm
    }
    for (final s in wanted.values) {
      final same = existing.where((e) => e.id == s.id);
      if (same.isNotEmpty && _same(same.first, s)) continue;
      await ap.Alarm.set(alarmSettings: s);
    }
    for (final id in finished) {
      try {
        await ApiService.toggleAlarm(id); // switch the finished one-time alarm off
      } catch (_) {}
    }
  }

  static Future<void> cancelAll() async {
    _cache = [];
    _webFired.clear();
    if (_native) {
      try {
        await ap.Alarm.stopAll();
      } catch (_) {}
    }
    await RingtonePlayer.stop();
  }

  // ---------- ringing ----------
  static Future<void> _showRing(RingInfo info) async {
    if (!_showing.add(info.settingsId)) return;
    for (var i = 0; i < 30 && navigatorKey.currentState == null; i++) {
      await Future.delayed(const Duration(milliseconds: 300)); // app still starting
    }
    final nav = navigatorKey.currentState;
    if (nav == null) {
      _showing.remove(info.settingsId);
      return;
    }
    await nav.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => RingScreen(info: info)));
    _showing.remove(info.settingsId);
  }

  static Future<void> _webRing(RingInfo info) async {
    await RingtonePlayer.play(info.ringtone, loop: true);
    _showRing(info);
  }

  static void _webTick() {
    final now = DateTime.now();
    for (final a in _cache) {
      if (!a.enabled) continue;
      final p = a.time.split(':');
      if (now.hour != int.parse(p[0]) || now.minute != int.parse(p[1])) continue;
      if (a.repeatDays.isNotEmpty && !a.repeatDays.contains(now.weekday)) continue;
      if (!_webFired.add('${a.id}-${now.year}-${now.month}-${now.day}-${now.hour}-${now.minute}')) continue;
      _webRing(_infoFor(a, web: true));
    }
  }

  static void _refresh() => ApiService.alarms().catchError((_) => <m.Alarm>[]);

  static Future<void> _finishOneTime(String alarmId) async {
    if (alarmId.isEmpty) return;
    final match = _cache.where((a) => a.id == alarmId && a.enabled);
    if (match.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('once_$alarmId');
      await ApiService.toggleAlarm(alarmId); // one-time alarm switches itself off after ringing
    } catch (_) {}
  }

  /// Stop button.
  static Future<void> stopRing(RingInfo info) async {
    if (info.web) {
      await RingtonePlayer.stop();
    } else {
      await ap.Alarm.stop(info.settingsId);
    }
    if (info.oneTime && !info.isSnoozeRing) await _finishOneTime(info.alarmId);
    _refresh();
  }

  /// Snooze button: silence now, ring again in [info.snooze] minutes.
  static Future<void> snoozeRing(RingInfo info) async {
    final delay = Duration(minutes: info.snooze);
    final snoozeId = (info.settingsId & ~15) | snoozeSlot;
    if (info.web) {
      await RingtonePlayer.stop();
      Timer(delay, () => _webRing(info.copyWith(settingsId: snoozeId)));
    } else {
      await ap.Alarm.stop(info.settingsId);
      await ap.Alarm.set(alarmSettings: _settings(info.copyWith(settingsId: snoozeId), snoozeId, DateTime.now().add(delay)));
    }
    if (info.oneTime && !info.isSnoozeRing) await _finishOneTime(info.alarmId);
    _refresh();
  }

  /// "Test ring in 10 seconds" button.
  static Future<void> scheduleTest({String ringtone = 'sunrise'}) async {
    final info = RingInfo(
      settingsId: _testId,
      alarmId: '',
      label: 'Test alarm',
      text: 'This is how your alarm will sound and look.',
      category: 'Aura',
      ringtone: ringtone,
    );
    if (_native) {
      await ap.Alarm.set(alarmSettings: _settings(info, _testId, DateTime.now().add(const Duration(seconds: 10))));
    } else {
      Timer(const Duration(seconds: 10), () => _webRing(info.copyWith(web: true)));
    }
  }
}
