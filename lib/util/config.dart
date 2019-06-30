import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static String _mapsApiKey = '';
  static String backendProtocol = 'http'; // 'http|https'
  static String backendUrl =  'tci.burnscoding.com';
  static String applicationVersion = '1.0.0';
  static SharedPreferences prefs;
  static dynamic _settings;
  static List<dynamic> settingsListeners = [];
  static int maxCheckInsPerMinute = 5;

  static dynamic getSettings() {
    return _settings;
  }
  static void setSettings(dynamic newSettings) {
    _settings = newSettings;
    for(dynamic callback in settingsListeners) {
      callback(_settings);
    }
  }

  static void init() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      Config.prefs = prefs;
    });
  }

  static String getMapsApiKey() {
    return _mapsApiKey;
  }
  static void setMapsApiKey(String key) {
    _mapsApiKey = key;
  }
}