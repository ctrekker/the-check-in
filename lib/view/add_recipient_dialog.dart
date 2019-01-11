import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseUser, PlatformException;
import 'package:the_check_in/util/firebase_custom.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class AddRecipientDialog extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _AddRecipientDialogState();
}
class _AddRecipientDialogState extends State<AddRecipientDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;

  String _name;
  String _email;
  String _phone;

  bool _hasEmail = false;
  bool _hasPhone = false;

  //FocusNode _emailFocus = FocusNode();
  //FocusNode _phoneFocus = FocusNode();

  bool _isEmail(String em) {
    String p = r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
    RegExp regExp = new RegExp(p);
    return regExp.hasMatch(em);
  }

  void _addRecipient() async {
    if(_formKey.currentState.validate()) {
      setState(() {
        _loading = true;
      });
      _formKey.currentState.save();
      dynamic info = {};
      info['name'] = _name;
      if(_hasEmail) {
        info['email'] = _email;
      }
      if(_hasPhone) {
        info['phone_number'] = _phone;
      }
      BackendStatusResponse res = await FirebaseBackend.addRecipient(await (await _auth.currentUser()).getIdToken(), info);
      if(res.type == 'success') {
        Navigator.pop(context);
      }
      else {
        setState(() {
          _loading = false;
        });
        print('Failure:');
        print('\t'+res.code);
      }
    }
  }

  @override
  void initState() {
    super.initState();
//    _emailFocus = FocusNode();
//    _phoneFocus = FocusNode();
  }
  @override
  void dispose() {
//    _emailFocus.dispose();
//    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add New Recipient')
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(32.0),
          children: <Widget>[
            TextFormField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Recipient Name'
              ),
              validator: (value) {
                if(value.isEmpty) return 'Please enter the name of this recipient';
              },
              onSaved: (value) {
                _name = value;
              }
            ),
            () {
              if(_hasEmail) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    TextFormField(
//                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'them@example.com',
                        labelText: 'Recipient Email'
                      ),
                      validator: (value) {
                        if(!_isEmail(value)) return 'Please enter a valid email';
                      },
                      onSaved: (value) {
                        _email = value;
                      }
                    ),
                    RaisedButton(
                      child: Text('Remove Email'),
                      onPressed: () {
                        setState(() {
                          _hasEmail = false;
                        });
                      },
                    )
                  ],
                );
              } else {
                return RaisedButton(
                  child: Text('Add Email'),
                  onPressed: () {
                    setState(() {
//                      FocusScope.of(context).requestFocus(_emailFocus);
                      _hasEmail = true;
                    });
                  }
                );
              }
            }(),
            () {
              if(_hasPhone) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    TextFormField(
//                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Recipient Phone Number'
                      ),
                      onSaved: (value) {
                        _phone = value;
                      }
                    ),
                    RaisedButton(
                      child: Text('Remove Phone Number'),
                      onPressed: () {
                        setState(() {
                          _hasPhone = false;
                        });
                      }
                    )
                  ],
                );
              } else {
                return RaisedButton(
                  child: Text('Add Phone'),
                  onPressed: () {
                    setState(() {
//                      FocusScope.of(context).requestFocus(_phoneFocus);
                      _hasPhone = true;
                    });
                  }
                );
              }
            }(),
            Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                () {
                  if(_loading) return CircularProgressIndicator();
                  else return Container();
                }(),
                Container(
                  padding: EdgeInsets.all(8.0),
                ),
                RaisedButton(
                  child: Text('Add Recipient'),
                  onPressed: _addRecipient,
                ),
              ],
            )
          ],
        )
      )
    );
  }
}