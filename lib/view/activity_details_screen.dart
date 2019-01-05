import 'package:flutter/material.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';

class ActivityDetailsScreen extends StatefulWidget {
  String _message;
  ActivityDetailsScreen(String message) {
    _message = message;
  }
  @override
  State<StatefulWidget> createState() => ActivityDetailsScreenState(_message);
}
class ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  dynamic _message;

  ActivityDetailsScreenState(String message) {
    _message = json.decode(message);
  }

  Widget _constructElementTree(dynamic message) {
    List<Widget> columnWidgets = [];

    for(int i=0; i<message.length; i++) {
      dynamic elementData = message[i];

      if(elementData.containsKey('title')) {
        columnWidgets.add(Text(
          elementData['title'],
          style: TextStyle(
            fontSize: 20.0
          )
        ));
        columnWidgets.add(Container(padding: EdgeInsets.only(top: 8.0)));
      }
      if(elementData.containsKey('text')) {
        columnWidgets.add(Text(
          elementData['text']
        ));
      }
      if(elementData.containsKey('image_url')) {
        columnWidgets.add(Image.network(elementData['image_url']));
      }
      columnWidgets.add(Container(padding: EdgeInsets.only(top: 16.0)));
      columnWidgets.add(Divider());
    }
    return Column(
      children: columnWidgets,
      crossAxisAlignment: CrossAxisAlignment.start,
    );
  }

  @override
  Widget build(BuildContext context) {
    print(_message[0]);
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details')
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(32.0),
        child: _constructElementTree(_message)
      )
    );
  }
}