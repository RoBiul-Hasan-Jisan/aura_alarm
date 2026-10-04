import 'package:flutter/foundation.dart' show kIsWeb;

/// Base URL of the Express API.
const String apiBaseUrl =
    String.fromEnvironment(
      'API_URL',
      defaultValue: 'https://aura-alarm-backend.onrender.com/api',
    );

const List<String> kCategories = [
  'Morning',
  'Confidence',
  'Self-Love',
  'Gratitude',
  'Focus',
  'Courage',
  'Calm',
  'Health',
  'Success',
  'Sleep',
  'General',
];