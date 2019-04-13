import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static String mapsApiKey = 'AIzaSyCc-3ISZ1GuZ9jC6SbDmr-7m_pjYVKlf2c';
  static String backendUrl =  '192.168.1.20:3000';
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
}