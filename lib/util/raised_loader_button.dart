import 'package:flutter/material.dart';

class RaisedLoaderButton extends StatelessWidget {
  RaisedLoaderButton({this.showLoading, this.text, this.onPressed});

  final bool showLoading;
  final String text;
  final onPressed;

  @override
  Widget build(BuildContext context) {
    List<Widget> contents = [];
    if(showLoading) {
      contents.addAll([
        CircularProgressIndicator(

        ),
        Container(padding: EdgeInsets.only(left: 5.0))
      ]);
    }
    contents.add(Text(text));
    return RaisedButton(
      child: Row(
          children: contents
      ),
      onPressed: onPressed,
    );
  }
}