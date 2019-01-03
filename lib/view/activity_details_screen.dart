import 'package:flutter/material.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:flutter_markdown/flutter_markdown.dart';

class ActivityDetailsScreen extends StatefulWidget {
  String _message;
  ActivityDetailsScreen(String message) {
    _message = message;
  }
  @override
  State<StatefulWidget> createState() => ActivityDetailsScreenState(_message);
}
class ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  String _message;

  ActivityDetailsScreenState(String message) {
    _message = message;
  }

  @override
  Widget build(BuildContext context) {
    String md = html2md.convert(_message);
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details')
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(32.0),
        child: new MarkdownBody(data: md),
      )
    );
  }
}