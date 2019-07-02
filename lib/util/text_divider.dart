import 'package:flutter/material.dart';

class TextDivider extends StatelessWidget {
  String _text;

  TextDivider({ text="" }) {
    this._text = text;
  }
  @override
  Widget build(BuildContext context) {
    return Row(children: <Widget>[
      Expanded(
        child: new Container(
          margin: const EdgeInsets.only(left: 10.0, right: 20.0),
          child: Divider(
            color: Colors.black,
            height: 36.0,
          )),
      ),
      Text(_text),
      Expanded(
        child: new Container(
          margin: const EdgeInsets.only(left: 20.0, right: 10.0),
          child: Divider(
            color: Colors.black,
            height: 36.0,
          )),
      ),
    ]);
  }
}