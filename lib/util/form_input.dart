import 'package:flutter/material.dart';

class FormInput extends StatelessWidget {
  FormInput({this.label, this.formWidget});

  final String label;
  final Widget formWidget;
  final TextStyle labelStyle = TextStyle(fontSize: 16.0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle
        ),
        formWidget
      ]
    );
  }
}