import 'package:shared_preferences/shared_preferences.dart';

class Config {
  static String mapsApiKey = 'AIzaSyCc-3ISZ1GuZ9jC6SbDmr-7m_pjYVKlf2c';
  static String backendUrl =  'burnscoding.com:3000';
  static SharedPreferences prefs;

  static void init() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      Config.prefs = prefs;
    });
  }
}