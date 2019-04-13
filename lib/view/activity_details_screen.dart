import 'package:flutter/material.dart';
import 'package:the_check_in/util/config.dart';
import 'package:html2md/html2md.dart' as html2md;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:map_view/map_view_type.dart';
import 'dart:convert';

import 'package:map_view/static_map_provider.dart';
import 'package:map_view/map_view.dart' as Maps;
import 'package:cached_network_image/cached_network_image.dart';

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
  StaticMapProvider mapProvider = new StaticMapProvider(Config.mapsApiKey);

  ActivityDetailsScreenState(String message) {
    _message = json.decode(message);
  }

  Widget _constructElementTree(dynamic message) {
    List<Widget> columnWidgets = [];

    for(int i=0; i<message.length; i++) {
      dynamic elementData = message[i];

      if(elementData.containsKey('type') && elementData['type'] == 'hidden') continue;

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
        columnWidgets.add(CachedNetworkImage(
          imageUrl: elementData['image_url'],
          placeholder: Center(
            child: CircularProgressIndicator()
          ),
          errorWidget: Icon(Icons.error),
        ));
      }
      if(elementData.containsKey('location')) {
        double latitude = elementData['location']['latitude'].toDouble();
        double longitude = elementData['location']['longitude'].toDouble();

        Maps.Marker locationMarker = Maps.Marker('1', '', latitude, longitude, color: Colors.red);
        Uri mapUri = mapProvider.getStaticUriWithMarkers(
          [
            locationMarker
          ],
          center: Maps.Location(latitude, longitude),
          maptype: Maps.StaticMapViewType.roadmap);
        columnWidgets.add(GestureDetector(
          child: CachedNetworkImage(
            imageUrl: mapUri.toString(),
            placeholder: Center(
              child: CircularProgressIndicator()
            ),
            errorWidget: Icon(Icons.error)
          ),
          onTap: () {
            Maps.MapView _mapView = new Maps.MapView();
            _mapView.onMapReady.listen((_) {
              _mapView.setMarkers([
                locationMarker
              ]);
            });
            _mapView.show(
              new Maps.MapOptions(
                mapViewType: Maps.MapViewType.normal,
                initialCameraPosition: new Maps.CameraPosition(
                    new Maps.Location(latitude, longitude), 14.0),
                title: "Check In Location"
              ),
              toolbarActions: [new Maps.ToolbarAction("Close", 1)],
            );
            _mapView.onToolbarAction.listen((int action) {
              if (action == 1) {
                _mapView.dismiss();
              }
            });
          }
        ));
        columnWidgets.add(Container(padding: EdgeInsets.only(top: 3.0)));
        columnWidgets.add(Row(
          children: [Text(
            'Tap map to interact with it',
            style: TextStyle(fontStyle: FontStyle.italic)
          )],
          mainAxisAlignment: MainAxisAlignment.end,
        ));
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