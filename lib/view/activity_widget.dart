import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'package:the_check_in/view/activity_details_screen.dart';

class ActivityWidget extends StatefulWidget {
  FirebaseUser _user;
  ActivityWidget(FirebaseUser user) {
    _user = user;
  }
  @override
  State<StatefulWidget> createState() => ActivityWidgetState(_user);
}

class ActivityWidgetState extends State<ActivityWidget> {
  FirebaseUser _user;
  bool _loading = true;
  bool _silentReload = false;
  Timer _silentReloadTimer;
  dynamic _activities;

  ActivityWidgetState(FirebaseUser user) {
    _user = user;
  }

  void _loadActivities() async {
    try {
      BackendStatusResponse activityResponse = await FirebaseBackend
          .getActivity(await _user.getIdToken()).timeout(Duration(seconds: 7));

      _activities = activityResponse.raw['activity'];
      if(_silentReloadTimer != null) {
        _silentReloadTimer.cancel();
      }
      setState(() {
        _loading = false;
        _silentReload = true;
      });
    } on TimeoutException catch(_) {
      setState(() {
        _loading = false;
        _silentReload = true;
        _activities = null;
      });
    }
  }
  Widget _buildActivityList() {
    List<Widget> cardList = [];
    if(_activities == null) {
      cardList = [
        Text('We were unable to contact our servers. Please check your internet connection'),
        RaisedButton(
            child: Text('Try Again'),
            onPressed: () {
              setState(() {
                _loading = true;
              });
//              Timer(Duration(milliseconds: 500), () {
//                _getRecipients();
//              });
            }
        )
      ];
    }
    else {
      /*
      () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailsScreen(_activities[i]['message'])));
            }
       */
      for (int i = 0; i < _activities.length; i++) {
        cardList.add(_buildActivityCard(
          FirebaseBackend.typeToIcon(_activities[i]['type']),
          _activities[i]['title'],
          _activities[i]['summary'],
          _activities[i]['date'],
          _activities[i]['message'],
          FirebaseBackend.typeToActionText(_activities[i]['type']),
          FirebaseBackend.typeToActionCallback(context, _activities[i])));
      }
      if (cardList.length == 0) {
        cardList = [
          Container(
              padding: EdgeInsets.all(12.0),
              child: Text(
                  'Recent activity will show up here. This includes when you check in, and when others check in with you',
                  style: TextStyle(fontStyle: FontStyle.italic))
          )
        ];
      }
    }
    return Column(
      children: cardList,
    );
  }
  Widget _buildActivityCard(IconData icon, String title, String summary, String date, dynamic message, String actionText, dynamic actionCallback) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(top: 10.0),
            child: ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
//                Text(summary),
                    Text(date),
                    ButtonTheme.bar( // make buttons use the appropriate styles for cards
                      padding: EdgeInsets.only(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0),
                      child: ButtonBar(
                        children: <Widget>[
                          FlatButton(
                            child: Text(actionText),
                            onPressed: actionCallback,
                          ),
                        ],
                      ),
                    )
                  ]
              ),
            ),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if(_silentReload) {
      _silentReload = false;
      _silentReloadTimer = Timer(Duration(seconds: 10), () => _loadActivities());
    }
    if(_loading) {
      _loadActivities();
    }
    return Container(
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.title,
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                tooltip: 'Refresh Activity',
                onPressed: () {
                  setState(() {
                    _loading = true;
                  });
                },
              )
            ],
          ),
          Divider(),
          () {
            if(!_loading) return _buildActivityList();
            else return Container(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: CircularProgressIndicator()
              )
            );
          }()
        ],
        crossAxisAlignment: CrossAxisAlignment.start,
      ),
      padding: EdgeInsets.all(12.0)
    );
  }
}