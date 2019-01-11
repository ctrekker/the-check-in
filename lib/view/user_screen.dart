import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseUser, PlatformException;
import 'dart:async';
import 'package:the_check_in/main.dart' show auth, appTitle;
import 'package:the_check_in/util/firebase_custom.dart';

class UserScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _UserScreenState();
}
class _UserScreenState extends State<UserScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _siFormKey = GlobalKey<FormState>();
  final _suFormKey = GlobalKey<FormState>();
  final _minPasswordLength = 6;

  String _name;
  String _email;
  bool _emailUnique = true;
  String _password;
  String _passwordConfirm;

  bool _showLoader = false;

  bool _isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
  }

  void _siSubmit() async {
    _siFormKey.currentState.save();
    Timer(Duration(milliseconds: 250), () async {
      FirebaseUser user;
      try {
        user = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
            email: _email,
            password: _password
        );
      } catch(e) {}
      if(user != null && user.getIdToken() != null && user.uid == (await auth.currentUser()).uid) {
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(content: Text(user.uid))
        );
        Navigator.pop(context);
      }
      else {
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(content: Text('Your email or password is incorrect'))
        );
      }
      setState(() {
        _showLoader = false;
      });
    });

    setState(() {
      _showLoader = true;
    });
  }
  void _suSubmit() async {
    _suFormKey.currentState.save();
    Timer(Duration(milliseconds: 250), () async {
      BackendStatusResponse status;
      status = await FirebaseBackend.createUserWithEmailAndPassword(_email, _password, _name);

      if(status.type == 'success') {
        FirebaseUser user = await auth.signInWithEmailAndPassword(email: _email, password: _password);
        _scaffoldKey.currentState.showSnackBar(
            SnackBar(content: Text('Successfully created account'))
        );
        Navigator.pop(context);
      }
      else {
        switch(status.code) {
          case 'auth/email-already-exists':
            _emailUnique = false;
            _suFormKey.currentState.validate();
            _emailUnique = true;
            break;
        }
      }
      setState(() {
        _showLoader = false;
      });
    });

    setState(() {
      _showLoader = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget _signInContainer = ListView(
        padding: EdgeInsets.all(32.0),
        children: [Form(
            key: _siFormKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          hintText: 'you@example.com',
                          labelText: 'Email Address'
                      ),
                      validator: (value) {
                        if(value.isEmpty || !_isEmail(value)) return 'Please enter a valid email';
                      },
                      onSaved: (value) {
                        _email = value;
                      }
                  ),
                  TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Password'
                      ),
                      validator: (value) {
                        if(value.isEmpty) return 'Please enter a password';
                      },
                      onSaved: (value) {
                        _password = value;
                      }
                  ),
                  ButtonBar(
                      children: () {
                        List<Widget> _c = [];
                        if(_showLoader) _c.add(CircularProgressIndicator());
                        _c.addAll([
                          RaisedButton(
                              child: Text('Log In'),
                              onPressed: () {
                                if(_siFormKey.currentState.validate()) {
                                  _siSubmit();
                                }
                              }
                          ),
                        ]);
                        return _c;
                      }()
                  )
                ]
            )
        )]
    );
    Widget _signUpContainer = ListView(
        padding: EdgeInsets.all(32.0),
        children: [Form(
            key: _suFormKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextFormField(
                      decoration: InputDecoration(
                          labelText: 'Name'
                      ),
                      validator: (value) {
                        if(value.isEmpty) return 'Please enter your name';
                        if(value.length > 40) return 'Please enter a name shorter than 40 characters';
                      },
                      onSaved: (value) {
                        _name = value;
                      }
                  ),
                  TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          hintText: 'you@example.com',
                          labelText: 'Email'
                      ),
                      validator: (value) {
                        if(value.isEmpty) return 'Please enter your email';
                        if(!_isEmail(value)) return 'Please enter a valid email';
                        if(!_emailUnique) return 'That email is already in use';
                      },
                      onSaved: (value) {
                        _email = value;
                      }
                  ),
                  TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Password'
                      ),
                      validator: (value) {
                        _password = value;
                        if(value.isEmpty) return 'Please enter your password';
                        if(value.length < 6) return 'Passwords must be at least 6 characters long';
                      },
                      onSaved: (value) {
                        _password = value;
                      }
                  ),
                  TextFormField(
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Confirm Password'
                      ),
                      validator: (value) {
                        _passwordConfirm = value;
                        if(_password != _passwordConfirm) return 'Please enter the same password you did above';
                      },
                      onSaved: (value) {
                        _passwordConfirm = value;
                      }
                  ),
                  ButtonBar(
                      children: () {
                        List<Widget> _c = [];
                        if(_showLoader) _c.add(CircularProgressIndicator());
                        _c.addAll([
                          RaisedButton(
                              child: Text('Create Account'),
                              onPressed: () {
                                if(_suFormKey.currentState.validate()) {
                                  _suSubmit();
                                }
                              }
                          ),
                        ]);
                        return _c;
                      }()
                  )
                ]
            )
        )]
    );

    return DefaultTabController(
        length: 2,
        child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: appTitle,
              bottom: TabBar(
                  tabs: <Widget>[
                    Tab(text: 'Log In'),
                    Tab(text: 'Create Account')
                  ]
              ),
              automaticallyImplyLeading: false,
            ),
            body: TabBarView(
                children: <Widget>[
                  _signInContainer,
                  _signUpContainer,
                ]
            )
        )
    );
  }
}