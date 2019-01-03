import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  FirebaseUser _user;

  ProfileScreen(FirebaseUser user) {
    _user = user;
  }

  @override
  State<StatefulWidget> createState() => ProfileScreenState(_user);
}
class ProfileScreenState extends State<ProfileScreen> {
  FirebaseUser _user;
  bool _loading = false;



  ProfileScreenState(FirebaseUser user) {
    _user = user;
  }

//  void _loadProfile() async {
//    setState(() {
//      _displayName = _user.displayName;
//      _email = _user.email;
//    });
//  }

  @override
  Widget build(BuildContext context) {
    AppBar appBar = AppBar(
      title: Text('Profile')
    );
    if(_loading) {
//      Timer(Duration(milliseconds: 200), () => _loadProfile());
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
        body: ListView(
          children: [
            Divider(),
            Text('Name: '+_user.displayName),
            Divider(),
            Text('Email: '+_user.email),
            Divider()
          ],
          padding: EdgeInsets.all(32.0)
        )
      );
    }
  }
}