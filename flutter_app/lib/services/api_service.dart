import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';
import 'alarm_scheduler.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Flutter -> Express REST client. Every call attaches the Firebase ID token
/// so the backend can verify who is asking (no custom JWT involved).
class ApiService {
  static const _timeout = Duration(seconds: 50); // free hosting can take ~30-60 s to wake up
  static Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException('You are signed out. Please log in again.', 401);
    final token = await user.getIdToken();

    final uri = Uri.parse('$apiBaseUrl$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    try {
      late http.Response res;
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'GET': res = await http.get(uri, headers: headers).timeout(_timeout); break;
        case 'POST': res = await http.post(uri, headers: headers, body: encoded).timeout(_timeout); break;
        case 'PUT': res = await http.put(uri, headers: headers, body: encoded).timeout(_timeout); break;
        case 'PATCH': res = await http.patch(uri, headers: headers, body: encoded).timeout(_timeout); break;
        case 'DELETE': res = await http.delete(uri, headers: headers).timeout(_timeout); break;
      }
      final data = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      final msg = data is Map && data['message'] != null ? data['message'] : 'Request failed (${res.statusCode})';
      throw ApiException(msg.toString(), res.statusCode);
    } on http.ClientException {
      throw ApiException('Cannot reach the server. Check that the API is running and your connection.');
    } on TimeoutException {
      throw ApiException('The server is waking up (free hosting sleeps when idle). Wait a few seconds and try again.');
    } on FormatException {
      throw ApiException('Unexpected response from the server.');
    }
  }

  // ---- Users ----
  static Future<void> syncUser({String? name}) =>
      _send('POST', '/users/sync', body: {if (name != null) 'name': name});
  static Future<void> demoSeed() => _send('POST', '/users/demo-seed', body: {});
  static Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await _send('GET', '/users/me'));
  static Future<void> updateName(String name) => _send('PUT', '/users/me', body: {'name': name});
  static Future<void> updateProfile({List<String>? followed, int? theme}) => _send('PUT', '/users/me',
      body: {if (followed != null) 'followedCategories': followed, if (theme != null) 'theme': theme});

  // ---- Affirmations ----
  static Future<List<Affirmation>> affirmations({String? category, bool favoritesOnly = false}) async {
    final q = <String>[
      if (category != null) 'category=${Uri.encodeQueryComponent(category)}',
      if (favoritesOnly) 'favorite=true',
    ];
    final data = await _send('GET', '/affirmations${q.isEmpty ? '' : '?${q.join('&')}'}') as List;
    return data.map((e) => Affirmation.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> categorySummary() async =>
      Map<String, dynamic>.from(await _send('GET', '/affirmations/categories'));

  static Future<int> starterPack() async {
    final d = await _send('POST', '/affirmations/starter', body: {});
    return (d['added'] ?? 0) as int;
  }

  static Future<Affirmation?> dailyAffirmation() async {
    final data = await _send('GET', '/affirmations/daily');
    return data == null ? null : Affirmation.fromJson(data);
  }

  static Future<void> createAffirmation(String text, String category, bool fav) =>
      _send('POST', '/affirmations', body: {'text': text, 'category': category, 'isFavorite': fav});

  static Future<void> updateAffirmation(String id, String text, String category, bool fav) =>
      _send('PUT', '/affirmations/$id', body: {'text': text, 'category': category, 'isFavorite': fav});

  static Future<void> toggleFavorite(String id) => _send('PATCH', '/affirmations/$id/favorite');
  static Future<void> deleteAffirmation(String id) => _send('DELETE', '/affirmations/$id');

  // ---- Alarms ----
  static Future<List<Alarm>> alarms() async {
    final data = await _send('GET', '/alarms') as List;
    final list = data.map((e) => Alarm.fromJson(e)).toList();
    AlarmScheduler.sync(list); // keep the phone's real alarms in step with the server (fire and forget)
    return list;
  }

  static Map<String, dynamic> _alarmBody(String label, String time, List<int> days, bool enabled, String? affId,
          String ringtone, int snooze, bool vibrate) =>
      {
        'label': label, 'time': time, 'repeatDays': days, 'enabled': enabled, 'affirmationId': affId,
        'ringtone': ringtone, 'snoozeMinutes': snooze, 'vibrate': vibrate,
      };

  static Future<void> createAlarm(String label, String time, List<int> days, bool enabled, String? affId,
          {String ringtone = 'sunrise', int snooze = 5, bool vibrate = true}) =>
      _send('POST', '/alarms', body: _alarmBody(label, time, days, enabled, affId, ringtone, snooze, vibrate));

  static Future<void> updateAlarm(String id, String label, String time, List<int> days, bool enabled, String? affId,
          {String ringtone = 'sunrise', int snooze = 5, bool vibrate = true}) =>
      _send('PUT', '/alarms/$id', body: _alarmBody(label, time, days, enabled, affId, ringtone, snooze, vibrate));

  static Future<void> toggleAlarm(String id) => _send('PATCH', '/alarms/$id/toggle');
  static Future<void> deleteAlarm(String id) => _send('DELETE', '/alarms/$id');
}
