import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'package:the_check_in/util/spacer.dart' show SpacerBC;
import 'package:map_view/map_view.dart';

class SettingsScreen extends StatefulWidget {
  FirebaseUser _user;
  SettingsScreen(FirebaseUser user) {
    _user = user;
  }
  @override
  State<StatefulWidget> createState() => SettingsScreenState(_user);
}
class SettingsScreenState extends State<SettingsScreen> {
  static const dynamic DEFAULT_SETTINGS = {

  };
  FirebaseUser _user;
  bool _loading = true;

  SettingsScreenState(FirebaseUser user) {
    _user = user;
  }

  void _loadSettings() async {
    String token = await _user.getIdToken();
    BackendStatusResponse res = await FirebaseBackend.getSettings(token);
    print(res.raw);
    if(res.raw['value'] == null) {
      await FirebaseBackend.setSettings(token, DEFAULT_SETTINGS);
      _loadSettings();
    }
    else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
      title: Row(
        children: <Widget>[
          Icon(Icons.settings),
          SpacerBC(),
          Text('Settings')
        ],
      )
    );
    if(_loading) {
      Timer(Duration(milliseconds: 200), () => _loadSettings());
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator()
        )
      );
    }
    else {
      return Scaffold(
        appBar: appBar,
        body: SingleChildScrollView(
          child: Column(
            children: [
              Text('hi')
            ]
          ),
          padding: EdgeInsets.all(32.0)
        )
      );
    }
  }
}