import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/icon_data.dart';
import 'package:the_check_in/main.dart';
import 'package:the_check_in/util/config.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:convert';
import 'dart:async';

import 'package:the_check_in/view/activity_details_screen.dart';

class FirebaseBackend {
  static int lastCheckInTime = new DateTime.now().millisecondsSinceEpoch;
  static int lastCheckInCount = 0;

  static final String baseUrl = Config.backendUrl;
  static Uri getBackendUri(String path) {
    if(Config.backendProtocol == 'https') {
      return new Uri.https(baseUrl, path);
    }
    else {
      return new Uri.http(baseUrl, path);
    }
  }
  static Future<BackendStatusResponse> userDetails(String token) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', getBackendUri('/user/details'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> createUserWithEmailAndPassword(String email, String password, String name) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', getBackendUri('/user/create'));

    request.bodyFields = {'email': email, 'password': password, 'name': name};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> updateFcmToken(String token, String fcmToken, {bool force=false, int layer=0}) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/device/fcm'));

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
    http.Request request = http.Request('POST', getBackendUri('/user/recipients/getAll'));

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
    http.Request request = new http.Request('POST', getBackendUri('/user/recipients/add'));

    request.bodyFields = {'token': token, 'info': json.encode(info)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> removeRecipient(String token, int id) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/recipients/remove'));

    request.bodyFields = {'token': token, 'id': id.toString()};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> getActivity(String token) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/activity/get'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<void> setActivityViewed(String token) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/activity/set/viewed'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> checkIn(String token, dynamic info, List<int> recipients, int associatedWith, dynamic flags) async {
    // Cooldown check
    int currentTime = new DateTime.now().millisecondsSinceEpoch;
    if(lastCheckInTime + 60 * 1000 < currentTime) {
      lastCheckInTime = currentTime;
      lastCheckInCount = 1;
    }
    else if(lastCheckInCount < Config.maxCheckInsPerMinute) {
      lastCheckInCount++;
    }
    else {
      return new BackendStatusResponse(
        type: 'error',
        message: 'You have exceeded the max check in count of ' + Config.maxCheckInsPerMinute.toString() + ' per minute'
      );
    }

    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/checkIn'));

    request.bodyFields = {'token': token, 'info': json.encode(info), 'recipients': recipients.join(','), 'associatedWith': associatedWith.toString(), 'flags': json.encode(flags)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<dynamic> getCheckIns(String token, int quantity, int page, String query) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/checkIn/get'));

    request.bodyFields = {'token': token, 'quantity': quantity.toString(), 'page': page.toString(), 'query': query};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return json.decode(jsonStr);
  }
  static Future<BackendStatusResponse> getCheckInsResultCount(String token, String query) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/checkIn/get/resultCount'));

    request.bodyFields = {'token': token, 'query': query};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<dynamic> getQuickCheckIns(String token) async {
    http.Client client = new http.Client();
    http.Request request = http.Request('POST', getBackendUri('/user/checkIn/qci'));

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
  static Future<BackendStatusResponse> getSettings(String token) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/attribute/settings/get'));

    request.bodyFields = {'token': token};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<dynamic> getSettingsScreen() async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/settings/get'));

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return json.decode(jsonStr);
  }
  static Future<BackendStatusResponse> setSettings(String token, dynamic value) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/attribute/settings/set'));

    request.bodyFields = {'token': token, 'value': json.encode(value)};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<void> updateSettings(String token) async {
    BackendStatusResponse settingsRes = await FirebaseBackend.getSettings(token);
    if(settingsRes.type == 'success') {
      if(settingsRes.raw['value'] == null) {
        Config.setSettings({});
      }
      else {
        Config.setSettings(json.decode(settingsRes.raw['value']));
      }
    }
  }
  static Future<BackendStatusResponse> setTimezone(String token, String timeZoneName) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/attribute/timezone/set'));

    request.bodyFields = {'token': token, 'value': timeZoneName};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<BackendStatusResponse> uploadImage(String token, String imagePath) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/image/upload'));

    File f = File(imagePath);
    String imageDataB64 = base64Encode(f.readAsBytesSync());

    request.bodyFields = {'token': token, 'image': imageDataB64};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return BackendStatusResponse.fromJSON(json.decode(jsonStr));
  }
  static Future<String> getMapsApiKey() async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/maps/apiKey'));

    request.bodyFields = {};

    http.StreamedResponse response = await client.send(request);
    String str = await response.stream.bytesToString();
    return str;
  }
  static Future<void> sendPasswordResetEmail(email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
  static Future<dynamic> checkBlacklistedVersion(String version) async {
    http.Client client = new http.Client();
    http.Request request = new http.Request('POST', getBackendUri('/user/version/' + version + '/checkBlacklisted'));

    request.bodyFields = {};

    http.StreamedResponse response = await client.send(request);
    String jsonStr = await response.stream.bytesToString();
    return json.decode(jsonStr);
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
      http.Request request = new http.Request('POST', getBackendUri('/user/device/init'));

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
        return Icons.check;
      case 'CHECKIN_S':
        return Icons.check;
      case 'CHECKIN_RR':
        return Icons.people;
      case 'CHECKIN_RS':
        return Icons.people;
      case 'CHECKIN_RR_R':
        return Icons.people;
      default:
        return Icons.message;
    }
  }
  static String typeToActionText(String type) {
    switch(type) {
      case 'CHECKIN_R':
        return "VIEW DETAILS";
      case 'CHECKIN_S':
        return "VIEW DETAILS";
      case 'CHECKIN_RR':
        return "CHECK IN";
      case 'CHECKIN_RS':
        return "";
      case 'CHECKIN_RR_R':
        return "CHECKED IN";
      default:
        return "";
    }
  }
  static typeToActionCallback(context, dynamic activity) {
    dynamic viewDetailsCallback = () {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailsScreen(activity['message'])));
    };
    dynamic checkInCallback = () async {
      // Extract user details from activity
      dynamic userDetails;
      dynamic message = json.decode(activity['message']);
      for(int i=0; i<message.length; i++) {
        if(message[i]['title'] == 'user') {
          userDetails = message[i]['value'];
          break;
        }
      }
      if(userDetails == null) {
        print('ERROR: could not extract user details from activity message packet');
        Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen()));
        return;
      }

      FirebaseUser fuser = await auth.currentUser();
      String token = await fuser.getIdToken();

      int recipientId = -1;
      Future<void> getRecipientId([int level = 0]) async {
        if(level >= 2) return;
        List<dynamic> res = await FirebaseBackend.getAllRecipients(token);

        for (int i = 0; i < res.length; i++) {
          if (res[i]['email'] == userDetails['email']) {
            recipientId = res[i]['id'];
          }
        }
        if (recipientId == -1) {
          print('WARN: recipient associated with user details doesn\'t exist. Creating a new one...');
          BackendStatusResponse res = await FirebaseBackend.addRecipient(token, userDetails);
          if (res.type != 'success') {
            print(res);
            return;
          }

          await getRecipientId(level + 1);
        }
      }
      await getRecipientId();

      if(recipientId == -1) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen()));
        return;
      }

      Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen(activity)));
    };
    dynamic empty = () {};
    switch(activity['type']) {
      case 'CHECKIN_R':
        return viewDetailsCallback;
      case 'CHECKIN_S':
        return viewDetailsCallback;
      case 'CHECKIN_RR':
        return checkInCallback;
      case 'CHECKIN_RS':
        return empty;
      case 'CHECKIN_RR_R':
        return null;
      default:
        return empty;
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