import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_check_in/util/firebase_custom.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => ForgotPasswordScreenState();
}
class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String _email;

  bool _isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
  }
  void _sendRecoveryEmail() async {
    if(_formKey.currentState.validate()) {
      setState(() {
        _loading = true;
      });
      _formKey.currentState.save();
      await FirebaseBackend.sendPasswordResetEmail(_email);
      setState(() {
        _loading = false;
      });
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Account Recovery')
      ),
      body: Container(
        padding: EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              ButtonBar(
                children: <Widget>[
                  RaisedButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  RaisedButton(
                    child: () {
                      Text _buttonText = Text('Send Recovery Email');
                      if(!_loading) return _buttonText;
                      else {
                        return Row(
                          children: <Widget>[
                            Container(
                              child: SizedBox(
                                child: CircularProgressIndicator(
                                    valueColor: new AlwaysStoppedAnimation<Color>(Colors.white)
                                ),
                                width: 22.0,
                                height: 22.0,
                              ),
                              padding: EdgeInsets.only(right: 16.0)
                            ),
                            _buttonText
                          ],
                        );
                      }
                    }(),
                    color: Colors.blue,
                    textColor: Colors.white,
                    onPressed: _sendRecoveryEmail,
                  )
                ],
              )
            ]
          )
        )
      )
    );
  }
}