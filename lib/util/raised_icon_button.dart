import 'package:flutter/material.dart';

class RaisedIconButton extends StatelessWidget {
  RaisedIconButton({this.icon, this.text, this.onPressed});

  final IconData icon;
  final String text;
  final onPressed;

  @override
  Widget build(BuildContext context) {
    return RaisedButton(
      child: Row(
        children: [
          Icon(icon),
          Container(padding: EdgeInsets.only(left: 5.0)),
          Text(text),
        ]
      ),
      onPressed: onPressed,
    );
  }
}
