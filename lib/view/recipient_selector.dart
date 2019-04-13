import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseUser;
import 'package:flutter/material.dart';
import 'package:the_check_in/main.dart';
import 'package:the_check_in/util/config.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'dart:async';
import 'package:the_check_in/view/add_recipient_dialog.dart' show AddRecipientDialog;
import 'package:the_check_in/util/raised_icon_button.dart' show RaisedIconButton;
import 'package:shared_preferences/shared_preferences.dart';

class RecipientSelector extends StatefulWidget {
  FirebaseUser _user;
  dynamic _handleOffline;
  dynamic _checkedOverride;
  RecipientSelectorState state;
  RecipientSelector(_user, _handleOffline, [dynamic _checkedOverride]) {
    this._user = _user;
    this._handleOffline = _handleOffline;
    this._checkedOverride = _checkedOverride;
  }

  @override
  State<StatefulWidget> createState() {
    state = RecipientSelectorState(_user, _handleOffline, _checkedOverride);
    return state;
  }
}
class RecipientSelectorState extends State<RecipientSelector> {
  FirebaseUser _user;

  dynamic _checked = {};
  bool _checkedOverride = false;
  String _checkedCacheKey = 'recipientsChecked';
  bool _offline = true;
  bool _checkRecipients = true;
  dynamic _recipients;
  bool _loaderOverride = false;
  dynamic _handleOffline;
  Timer _handleOfflineTimer;

  RecipientSelectorState(_user, _handleOffline, [_checkedOverride]) {
    this._user = _user;
    this._handleOffline = _handleOffline;
    if(_checkedOverride != null) {
      this._checkedOverride = true;
      this._checked = _checkedOverride;
    }
  }

  List<int> getRecipients() {
    List<int> out = [];
    _checked.forEach((id,checked) {
      if(checked) {
        out.add(int.parse(id));
      }
    });
    return out;
  }

  void _onRecipientTap(on, id) {
    setState(() {
      _checked[id.toString()] = !_checked[id.toString()];
      Config.prefs.setString(_checkedCacheKey, json.encode(_checked));
    });
  }
  void _onRecipientRemove(id) async {
    setState(() {

    });
    await FirebaseBackend.removeRecipient(await _user.getIdToken(), id);
    setState(() {
      _checkRecipients = true;
    });
  }
  ListTile _createRecipientItem(int id, String name, String sub) {
    return ListTile(
      leading: Checkbox(
        onChanged: (on) {_onRecipientTap(on, id);},
        value: _checked[id.toString()],
      ),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline),
        tooltip: 'Remove recipient',
        onPressed: () {_onRecipientRemove(id);},
      ),
      title: Text(name),
      subtitle: Text(sub),
      onTap: () {_onRecipientTap(null, id);}
    );
  }

  void _getRecipients() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    dynamic _checkedCache;
    if(prefs.getKeys().contains(_checkedCacheKey)) {
      _checkedCache = json.decode(prefs.getString(_checkedCacheKey));
    }

    if(_user == null) {
      _user = await auth.currentUser();
    }
    _recipients = await FirebaseBackend.getAllRecipients(await _user.getIdToken());
    if(_recipients != null && !(_recipients is List) && _recipients['type'] == 'error') _recipients = null;
    if(_recipients != null && !_checkedOverride) {
      for (dynamic recipient in _recipients) {
        if (_checked[recipient['id'].toString()] == null) {
          if(_checkedCache != null && _checkedCache.keys.contains(recipient['id'].toString())) {
            _checked[recipient['id'].toString()] = _checkedCache[recipient['id'].toString()];
          }
          else {
            _checked[recipient['id'].toString()] = false;
          }
        }
      }
    }
    setState(() {
      _checkRecipients = false;
      _offline = _recipients == null;
    });
  }

  Future<Null> _showAddRecipientDialog() async {
    setState(() {
      _loaderOverride = true;
    });
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddRecipientDialog()),
    );
    setState(() {
      _loaderOverride = false;
      _checkRecipients = true;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _handleOffline = () {};
    _handleOfflineTimer.cancel();
  }
  @override
  Widget build(BuildContext context) {
    _handleOfflineTimer = Timer(Duration(milliseconds: 200), () {
      try {
        _handleOffline(_offline);
      } catch(e) {
        print('WARN: unable to call _handleOffline');
      }
    });

    List<Widget> _listRecipients = [];
    if(_checkRecipients) {
      Timer(Duration(milliseconds: 200), () => _getRecipients());
    }
    else if(!_loaderOverride && !_offline) {
      bool _anyRecipients = false;
      for (dynamic recipient in _recipients) {
        _anyRecipients = true;

        String subval = '';
        if(recipient['email'] != null) subval = recipient['email'];
        if(recipient['phone_number'] != null) {
          if(subval.isNotEmpty) subval += '\n';
          subval += recipient['phone_number'];
        }
        _listRecipients.add(_createRecipientItem(recipient['id'], recipient['name'], subval));
      }

      if(!_anyRecipients) {
        _listRecipients.add(Text('\nYou currently don\'t have any recipients. \n Click "Add Recipient" to add one', style: TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center,));
      }
    }


    return Container(
      child: Column(
//        crossAxisAlignment: CrossAxisAlignment.start,
        children: (){
          List<Widget> out = [
            Text('Recipients', style: TextStyle(fontSize: 16.0))
          ];
          if(_checkRecipients || _loaderOverride) {
            out.add(Container(
                child: CircularProgressIndicator(),
                padding: EdgeInsets.all(32.0)
            ));
          }
          else if(_offline) {
            out.add(Container(
              child: Column(
                children: <Widget>[
                  Text('We were unable to contact our servers. Please check your internet connection'),
                  RaisedButton(
                    child: Text('Try Again'),
                    onPressed: () {
                      setState(() {
                        _checkRecipients = true;
                      });
                      Timer(Duration(milliseconds: 500), () {
                        _getRecipients();
                      });
                    }
                  )
                ],
              )
            ));
          }
          else {
            out.addAll([
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: _listRecipients,
              ),
              ButtonBar(
                children: <Widget>[
                  RaisedIconButton(
                    icon: Icons.add,
                    text: 'New Recipient',
                    onPressed: () {
                      _showAddRecipientDialog();
                    }
                  )
                ]
              )
            ]);
          }
          return out;
        }()
      )
    );
  }
}