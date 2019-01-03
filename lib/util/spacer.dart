import 'package:flutter/material.dart';

class SpacerBC extends StatelessWidget {
  SpacerBC({this.space = 20.0});

  final double space;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(left: space)
    );
  }
}
