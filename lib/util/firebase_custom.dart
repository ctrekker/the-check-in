import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/icon_data.dart';
import 'package:the_check_in/util/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:convert';
import 'dart:async';

class FirebaseBackend {
  static final String baseUrl = Config.backendUrl;
  static Future<BackendStatusResponse> userDetails(String token) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', new Uri.http(baseUrl, '/user/details'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> createUserWithEmailAndPassword(String email, String password, String name) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', new Uri.http(baseUrl, '/user/create'));

    request.bodyFields = {'email': email, 'password': password, 'name': name};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> updateFcmToken(String token, String fcmToken, {bool force=false, int layer=0}) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/device/fcm'));

    String device_id = await getDeviceId(token, force: force);
    print('device_id: '+device_id);
    request.bodyFields = {'token': token, 'device_id': device_id, 'fcm_token': fcmToken};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    BackendStatusResponse res = BackendStatusResponse.fromJSON(json.decode(jsonStr));
    if(res.code == 'device/invalid-id' && layer < 3) {
      print('Device ID invalid. Obtaining new one');
      return await updateFcmToken(token, fcmToken, force: true, layer: layer+1);
    }
    else if(layer >= 3) {
      return res;
    }
    return res;
  }
  static Future<dynamic> getAllRecipients(String token) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', new Uri.http(baseUrl, '/user/recipients/getAll'));

    request.bodyFields = {'token': token};

    try {
      http.StreamedResponse response = await client.send(request).timeout(
          Duration(seconds: 8));
      String jsonStr = await response.stream.bytesToString();

      client.close();

      return json.decode(jsonStr);
    } on TimeoutException catch(_) {
      return null;
    } on SocketException catch(e) {
      print(e);
      return null;
    }
  }
  static Future<BackendStatusResponse> addRecipient(String token, dynamic info) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/recipients/add'));

    request.bodyFields = {'token': token, 'info': json.encode(info)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    print(jsonStr);
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> removeRecipient(String token, int id) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/recipients/remove'));

    request.bodyFields = {'token': token, 'id': id.toString()};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> getActivity(String token) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/activity/get'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> checkIn(String token, dynamic info, List<int> recipients, dynamic flags) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/checkIn'));

    request.bodyFields = {'token': token, 'info': json.encode(info), 'recipients': recipients.join(','), 'flags': json.encode(flags)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<dynamic> getCheckIns(String token, int quantity, int page, String query) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/checkIn/get'));

    request.bodyFields = {'token': token, 'quantity': quantity.toString(), 'page': page.toString(), 'query': query};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return json.decode(jsonStr);
  }
  static Future<BackendStatusResponse> getCheckInsResultCount(String token, String query) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/checkIn/get/resultCount'));

    request.bodyFields = {'token': token, 'query': query};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> getSettings(String token) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/attribute/settings/get'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<dynamic> getSettingsScreen() async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/settings/get'));

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return json.decode(jsonStr);
  }
  static Future<BackendStatusResponse> setSettings(String token, dynamic value) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/attribute/settings/set'));

    request.bodyFields = {'token': token, 'value': json.encode(value)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> setTimezone(String token, String timeZoneName) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/attribute/timezone/set'));

    request.bodyFields = {'token': token, 'value': timeZoneName};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> uploadImage(String token, String imagePath) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/image/upload'));

    File f = File(imagePath);
    String imageDataB64 = base64Encode(f.readAsBytesSync());

    request.bodyFields = {'token': token, 'image': imageDataB64};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<void> sendPasswordResetEmail(email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  static dynamic parseSettings(BackendStatusResponse r) {
    return json.decode(r.raw.value);
  }
  static dynamic constructCheckInInfo({int rating, String message, String imageId, Map<String, double> location}) {
    dynamic out = {};
    if(rating != null) {
      out['rating'] = rating;
    }
    if(message != null) {
      out['message'] = message;
    }
    if(imageId != null) {
      out['image_id'] = imageId;
    }
    if(location != null) {
      out['location'] = json.encode(location);
    }
    return out;
  }
  static Future<String> getDeviceId(String token, {bool force=false}) async {
    if(Config.prefs.getKeys().contains('device_id')&&!force) {
      return Config.prefs.getString('device_id');
    }
    else {
      http.Client client = new http.Client();
      http.Request request = new http.Request('POST', new Uri.http(baseUrl, '/user/device/init'));

      request.bodyFields = {'token': token};

      http.StreamedResponse response = await client.send(request);
      String jsonStr = await response.stream.bytesToString();

      BackendStatusResponse res = BackendStatusResponse.fromJSON(json.decode(jsonStr));
      if(res.type != 'error') {
        Config.prefs.setString('device_id', res.raw['device_id']);
        return res.raw['device_id'];
      }
      else {
        return null;
      }
    }
  }
  static IconData typeToIcon(String type) {
    switch(type) {
      case 'CHECKIN_R':
        return Icons.access_time;
      case 'CHECKIN_S':
        return Icons.access_time;
      case 'CHECKIN_RR':
        return Icons.arrow_forward;
      case 'CHECKIN_RS':
        return Icons.arrow_forward;
      default:
        return Icons.message;
    }
  }
}

class BackendStatusResponse {
  BackendStatusResponse({this.type, this.code, this.message, this.raw});

  final String type;
  final String code;
  final String message;
  final dynamic raw;

  factory BackendStatusResponse.fromJSON(dynamic json) {
    return BackendStatusResponse(
      type: json['type'],
      code: json['code'],
      message: json['message'],
      raw: json
    );
  }

  @override
  String toString() {
    return raw.toString();
  }
}