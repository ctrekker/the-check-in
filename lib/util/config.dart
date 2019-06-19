import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static String _mapsApiKey = '';
  static String backendUrl =  '192.168.1.5';
  static SharedPreferences prefs;
  static dynamic _settings;
  static List<dynamic> settingsListeners = [];

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