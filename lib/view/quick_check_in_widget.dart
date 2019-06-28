import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'package:the_check_in/util/text_divider.dart';
import 'package:the_check_in/view/activity_details_screen.dart';

class QuickCheckInWidget extends StatefulWidget {
  FirebaseUser _user;
  int _buttonCount;
  QuickCheckInWidget(FirebaseUser user, int buttonCount) {
    _user = user;
    _buttonCount = buttonCount;
  }
  @override
  State<StatefulWidget> createState() => QuickCheckInWidgetState(_user, _buttonCount);
}

class QuickCheckInWidgetState extends State<QuickCheckInWidget> {
  FirebaseUser _user;
  int _buttonCount = 3;
  bool _initLoading = true;
  bool _checkInLoading = false;
  dynamic _qciData;

  QuickCheckInWidgetState(FirebaseUser user, int buttonCount) {
    _user = user;
    _buttonCount = buttonCount;
  }

  void _loadQCI() async {
    String token = await _user.getIdToken();
    _qciData = await FirebaseBackend.getQuickCheckIns(token);
    print(_qciData);

    setState(() {
      _initLoading = false;
    });
  }
  dynamic _getButtonText(int index) {
    dynamic meta = _qciData[index];
    if(meta.length == 1 && meta[0].keys.length > 0) {
      return {
        'short': meta[0]['name'].split(' ')[0],
        'long': meta[0]['name']
      };
    }
    else if(meta.length > 1) {
      List<String> names = [];
      for(int i=0; i<meta.length; i++) {
        names.add(meta[i]['name']);
      }
      return {
        'short': meta[0]['name'].split(' ')[0] + ', +'+(meta.length-1).toString(),
        'long': names.join(', ')
      };
    }
    else {
      return {
        'short': '',
        'long': ''
      };
    }
  }
  void _buttonPress(index) async {
    setState(() {
      _checkInLoading = true;
    });

    List<int> recipientList = [];
    for(int i=0; i<_qciData[index].length; i++) {
      recipientList.add(_qciData[index][i]['id']);
    }

    String token = await _user.getIdToken();
    BackendStatusResponse res = await FirebaseBackend.checkIn(token, {}, recipientList, -1, {});

    setState(() {
      _checkInLoading = false;
    });

    if(res.type == 'success') {
      Scaffold.of(context).showSnackBar(
        SnackBar(content: Text(res.message,
          style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white)))
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if(!_initLoading) {
      return Container(
        padding: EdgeInsets.only(
          top: 15.0,
          bottom: 15.0
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              children: [
                Text('Quick Check In', textAlign: TextAlign.left),
                () {
                  if(_checkInLoading) {
                    return Container(
                      padding: EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                          width: 16.0,
                          height: 16.0,
                          child: CircularProgressIndicator(strokeWidth: 2.0)
                      )
                    );
                  }
                  return Container();
                }()
              ]
            ),
            Wrap(
              children: () {
                List<Widget> qciButtons = [];
                double numButtons = _qciData.length.toDouble();
                if(numButtons > _buttonCount.toDouble()) numButtons = _buttonCount.toDouble();
                for(int i=0; i<numButtons; i++) {
                  dynamic buttonText = _getButtonText(i);
                  if(buttonText['short'] != '') {
                    qciButtons.add(FractionallySizedBox(
                      widthFactor: 1.0 / numButtons,
                      child: Tooltip(
                        message: buttonText['long'],
                        preferBelow: false,
                        child: RaisedButton(
                          child: Text(buttonText['short'], style: () {
                            TextStyle style = Theme.of(context).textTheme.button;
                            return style.merge(TextStyle(fontSize: style.fontSize - 1.0));
                          }()),
                          onPressed: () { _buttonPress(i); }
                        )
                      )
                    ));
                  }
                }
                return qciButtons;
              }()
            )
          ]
        )
      );
    }
    else {
      _loadQCI();
      return Container(padding: EdgeInsets.only(top: 15.0));
    }
  }
}