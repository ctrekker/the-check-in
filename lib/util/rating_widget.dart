import 'package:flutter/material.dart';

class RatingWidget extends StatefulWidget {
  _RatingWidgetState state;
  _RatingWidgetState createState() {
    state = _RatingWidgetState();
    return state;
  }
}
class _RatingWidgetState extends State<StatefulWidget> {
  void _select(int star) {
    setState(() {
      _selected = star;
    });
  }

  int _selected = 0;

  int getValue() {
    return _selected;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stars = [];
    for(int i=1; i<=5; i++) {
      IconData icon;
      Color color;
      if(i > _selected) {
        icon = Icons.star_border;
        color = Colors.black;
      } else {
        icon = Icons.star;
        color = Colors.blue;
      }
      stars.add(
          GestureDetector(
              child: Icon(
                icon,
                color: color,
                size: 30.0,
              ),
              onTap: () {
                _select(i);
              }
          )
      );
    }
    return Row(
        children: [
          Row(
              children: stars
          ),
          Container(
            padding: EdgeInsets.only(left: 12.0),
          ),
          Text(_selected.toString(), style: TextStyle(fontSize: 20.0))
        ]
    );
  }
}