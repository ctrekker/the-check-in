import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:health_check/util/firebase_custom.dart';
import 'package:health_check/view/activity_details_screen.dart';

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
  dynamic _activities;

  ActivityWidgetState(FirebaseUser user) {
    _user = user;
  }

  void _loadActivities() async {
    BackendStatusResponse activityResponse = await FirebaseBackend.getActivity(await _user.getIdToken());
    _activities = activityResponse.raw['activity'];
    setState(() {
      _loading = false;
      _silentReload = true;
    });
  }
  Widget _buildActivityList() {
    List<Widget> cardList = [];
    for(int i=0; i<_activities.length; i++) {
      cardList.add(_buildActivityCard(FirebaseBackend.typeToIcon(_activities[i]['type']), _activities[i]['title'], _activities[i]['summary'], _activities[i]['message']));
    }
    if(cardList.length == 0) {
      cardList = [
        Container(
          padding: EdgeInsets.all(12.0),
          child: Text('Recent activity will show up here. This includes when you check in, and when others check in with you', style: TextStyle(fontStyle: FontStyle.italic))
        )
      ];
    }
    return Column(
      children: cardList,
    );
  }
  Widget _buildActivityCard(IconData icon, String title, String summary, String message) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: EdgeInsets.only(top: 16.0)
          ),
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(summary),
          ),
          ButtonTheme.bar( // make buttons use the appropriate styles for cards
            child: ButtonBar(
              children: <Widget>[
                FlatButton(
                  child: const Text('VIEW DETAILS'),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailsScreen(message)));
                  },
                ),
              ],
            ),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if(_silentReload) {
      _silentReload = false;
      Timer(Duration(seconds: 10), () => _loadActivities());
    }
//    return Text('Your recent activity will appear here, including your latest check-ins, as well as when other people add you as a recipient when they check in');
    if(_loading) {
      _loadActivities();
      return Container(
        padding: EdgeInsets.all(48.0),
        child: Center(
          child: CircularProgressIndicator()
        )
      );
    }
    else {
      return Container(
        child: Column(
          children: <Widget>[
            Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20.0),
//            textAlign: TextAlign.left,
            ),
//          Container(
//            padding: EdgeInsets.only(top: 10.0)
//          ),
            Divider(),
            _buildActivityList()
          ],
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
        padding: EdgeInsets.all(12.0)
      );
    }
  }
}