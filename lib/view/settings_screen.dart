import 'dart:async';
import 'dart:convert';

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
  dynamic settingsJson;
  Map<String, dynamic> settingValues = Map();

  SettingsScreenState(FirebaseUser user) {
    _user = user;
  }

  void _loadSettings() async {
    String token = await _user.getIdToken();
    BackendStatusResponse res = await FirebaseBackend.getSettings(token);
    settingsJson = await FirebaseBackend.getSettingsScreen();

    if(res.raw['value'] == null) {
      await FirebaseBackend.setSettings(token, DEFAULT_SETTINGS);
      _loadSettings();
    }
    else {
      dynamic settingsAttribute = json.decode(res.raw['value']);
      settingsAttribute.forEach((k, v) => settingValues[k] = v);
      setState(() {
        _loading = false;
      });
    }
  }

  dynamic _getSetting(String name, dynamic def) {
    if(settingValues.containsKey(name)) {
      return settingValues[name];
    }
    settingValues[name] = def;
    return def;
  }
  void _updateSetting(String name, { dynamic value }) {
    _user.getIdToken().then((token) {
      FirebaseBackend.setSettings(token, settingValues);
    });

    setState(() {
      settingValues[name] = value == null ? !settingValues[name] : value;
    });
  }

  Widget _buildSettingsScreen(dynamic screenData) {
    List<Widget> elements = [];
    String type = screenData['type'];
    if(screenData.containsKey('children')) {
      for (int i = 0; i < screenData['children'].length; i++) {
        elements.add(_buildSettingsScreen(screenData['children'][i]));
      }
    }
    if(type=='container') {
      return Container(
        child: Column(
          children: elements
        )
      );
    }
    if(type=='section') {
      elements.insert(0, Text(screenData['name']));
      elements.add(Divider());
      return Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: elements
        )
      );
    }
    if(type=='checkbox') {
      return ListTile(
        leading: Checkbox(
          value: _getSetting(screenData['name'], screenData['default']),
          onChanged: (bool value) { _updateSetting(screenData['name']); },
        ),
        title: Text(screenData['label']),
        onTap: () { _updateSetting(screenData['name']); }
      );
    }
    if(type=='select') {
      List<DropdownMenuItem<String>> items = [];
      for(int i=0; i<screenData['values'].length; i++) {
        String item = screenData['values'][i];
        items.add(DropdownMenuItem<String>(
            child: Text(item),
            value: item
        ));
      }
      return ListTile(
        leading: DropdownButton<String>(
          items: items,
          value: _getSetting(screenData['name'], screenData['default']),
          onChanged: (String value) {
            _updateSetting(screenData['name'], value: value);
          },
        ),
        title: Text(screenData['label'])
      );
    }
    return Container();
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
          child: _buildSettingsScreen(settingsJson),
          padding: EdgeInsets.all(32.0)
        )
      );
    }
  }
}