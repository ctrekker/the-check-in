library health_check.main;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseUser, PlatformException;
import 'package:the_check_in/util/config.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'dart:io';
import 'package:the_check_in/util/rating_widget.dart' show RatingWidget;
import 'package:the_check_in/util/raised_icon_button.dart' show RaisedIconButton;
import 'package:the_check_in/util/form_input.dart' show FormInput;
import 'package:the_check_in/view/activity_widget.dart';
import 'package:the_check_in/view/history_screen.dart';
import 'package:the_check_in/view/recipient_selector.dart';
import 'package:the_check_in/view/settings_screen.dart';
import 'package:the_check_in/view/user_screen.dart' show UserScreen;
import 'package:the_check_in/view/camera_view.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'package:the_check_in/view/profile_screen.dart' show ProfileScreen;
import 'package:map_view/map_view.dart' as Maps;

final FirebaseAuth auth = FirebaseAuth.instance;
FirebaseUser fuser;


final Text appTitle = Text('The Check In');

void main() {
  Config.init();

  Maps.MapView.setApiKey(Config.mapsApiKey);
  runApp(new MyApp());
  cameraInit();
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    //initPlatformState();

//    _locationSubscription =
//        _location.onLocationChanged().listen((Map<String,double> result) {
//          setState(() {
//            _currentLocation = result;
//          });
//        });
  }
  Map<String, double> _startLocation;
  Map<String, double> _currentLocation;

  StreamSubscription<Map<String, double>> _locationSubscription;

  bool _permission;
  String error;
  Location _location = new Location();
  initPlatformState() async {
    Map<String, double> location;
    // Platform messages may fail, so we use a try/catch PlatformException.

    try {
      _permission = await _location.hasPermission();
      location = await _location.getLocation();

      print(location);

      error = null;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        error = 'Permission denied';
      } else if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        error = 'Permission denied - please ask the user to enable it from the app settings';
      }

      location = null;

      print(error);
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    //if (!mounted) return;

  }
  @override
  Widget build(BuildContext context) {
    Widget checkInButton = RaisedButton(
      child: Text('Check In'),
      color: Colors.blue,
      textColor: Colors.white,
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CheckInScreen()),
        );
      }
    );
    return MaterialApp(
      title: 'The Check In',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
        dividerColor: Colors.grey
      ),
      home: LandingScreen(),
    );
  }
}

class LandingScreen extends StatefulWidget {
  _LandingScreenState createState() => _LandingScreenState();
}
class _LandingScreenState extends State<LandingScreen> {
  bool _first = true;
  bool _showLoading = true;
  bool _loggedIn = false;
  bool _offline = false;
  ActivityWidget activityWidget;

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(Duration(seconds: 5));
      if(result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
    return false;
  }
  void _updateUserStatus([user]) async {
    _showLoading = true;
    _first = false;
    void _setState() {
      setState(() {
        _loggedIn = fuser != null;
        _showLoading = false;
      });
    }

    if(await _isConnected()) {
      fuser = await auth.currentUser();

      if (fuser != null) {
        String token = await fuser.getIdToken();
        print(token);
        FirebaseBackend.setTimezone(token, DateTime.now().timeZoneName);

        FirebaseMessaging _firebaseMessaging = new FirebaseMessaging();
        _firebaseMessaging.configure(
          onMessage: (Map<String, dynamic> message) {
            print('on message $message');
          },
          onResume: (Map<String, dynamic> message) {
            print('on resume $message');
          },
          onLaunch: (Map<String, dynamic> message) {
            print('on launch $message');
          },
        );
        _firebaseMessaging.requestNotificationPermissions(
            const IosNotificationSettings(sound: true, badge: true, alert: true));
        _firebaseMessaging.getToken().then((fcm_token) async {
          await FirebaseBackend.updateFcmToken(
              await fuser.getIdToken(), fcm_token);
        });
      }
      else {
        void _navigate() {
          Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserScreen()));
        }
        _navigate();
        print('Not logged in');
      }

      Timer(Duration(milliseconds: 1000), () {
        _setState();
      });
    }
    else {
      setState(() {
        _offline = true;
        _first = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if(_offline) {
      return Scaffold(
        body: Container(
          padding: EdgeInsets.all(64.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('We were unable to connect to our servers. Please check your internet connection and try again', textAlign: TextAlign.center),
                RaisedButton(
                  child: Text('Try Again'),
                  onPressed: () {
                    setState(() {
                      _offline = false;
                    });
                  },
                )
              ],
            )
          )
        )
      );
    }

    if(_first) {
      //_updateUserStatus();
      auth.onAuthStateChanged.listen((FirebaseUser) => _updateUserStatus());
    }

    Widget checkInButton = Builder(
      builder: (BuildContext context) {
        return RaisedButton(
          child: Text('Check In'),
          color: Colors.blue,
          textColor: Colors.white,
          onPressed: () async {
            BackendStatusResponse res = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CheckInScreen()),
            );
            if(res != null) {
              if(res.type == 'success') {
                Scaffold.of(context).showSnackBar(
                    SnackBar(content: Text(res.message)));
              }
              else if(res.type == 'warning') {
                Scaffold.of(context).showSnackBar(
                    SnackBar(content: Text(res.message)));
              }
            }
          }
        );
      }
    );

    if(!_showLoading) {
      activityWidget = ActivityWidget(fuser);
      return Scaffold(
        appBar: AppBar(
          title: appTitle,
        ),
        body: ListView(
          padding: const EdgeInsets.all(32.0),
          children: () {
            if(_loggedIn) {
              return [
                checkInButton,
                activityWidget
              ];
            }
            else {
              return <Widget>[];
            }
          }()
        ),
        drawer: () {
          if(_loggedIn) {
            return buildDrawer(context);
          }
          else {
            return null;
          }
        }(),
      );
    }
    else {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator()
        )
      );
    }
  }
  Widget buildDrawer(BuildContext context) {
    void _drawerTap([callback]) {
      Timer(Duration(milliseconds: 200), () {
        Navigator.pop(context);
        Timer(Duration(milliseconds: 50), () {
          if(callback != null) {
            callback();
          }
        });
      });
    }

    return Drawer(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: Text(fuser.displayName),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
            ),
            ListTile(
                leading: Icon(Icons.access_time),
                title: Text('Check In'),
                onTap: () {
                  _drawerTap(() {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CheckInScreen()));
                  });
                }
            ),
            ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  _drawerTap(() {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(fuser)));
                  });
                }
            ),
            ListTile(
              leading: Icon(Icons.access_alarms),
              title: Text('History'),
              onTap: () {
                _drawerTap(() {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HistoryScreen(fuser)));
                });
              }
            ),
            ListTile(
              leading: Icon(Icons.label),
              title: Text('Log Out'),
              onTap: () {
                _drawerTap(() {
                  auth.signOut();
                });
              },
            ),
            ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                onTap: () {
                  _drawerTap(() {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsScreen(fuser)));
                  });
                }
            )
          ],
        )
    );
  }
}

class CheckInScreen extends StatefulWidget {
  _CheckInScreenState createState() => _CheckInScreenState();
}
class _CheckInScreenState extends State<CheckInScreen> {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  bool _offline = true;
  bool _loading = false;

  RatingWidget _ratingWidget = RatingWidget();
  CheckInAttachments _attachmentsWidget = CheckInAttachments();
  RecipientSelector _recipientWidget;
  bool _shareLocationValue = false;

  Location _location = Location();
  String _locationCacheKey = 'locationChecked';
  bool _locationPermission = false;
  Map<String, double> _currentLocation;
  bool _showLocationPermissionPopup = false;

  @override
  void initState() {
    super.initState();

    initPlatformState();
  }
  void initPlatformState() async {
    _updateLocationPermission();
    if(!Config.prefs.getKeys().contains(_locationCacheKey)) {
      Config.prefs.setBool(_locationCacheKey, false);
    }
    setState(() {
      _shareLocationValue = Config.prefs.getBool(_locationCacheKey);
    });
  }

  void _setLocationCacheProperty() {
    print(_shareLocationValue);
    Config.prefs.setBool(_locationCacheKey, _shareLocationValue);
  }
  void _updateLocationPermission({bool state=false}) async {
    try {
      _locationPermission = await _location.hasPermission();
    } on PlatformException catch(e) {
      _locationPermission = false;
    }
    if(state) {
      setState(() {
        _locationPermission = _locationPermission;
        _showLocationPermissionPopup = false;
      });
    }
  }

  _CheckInScreenState() {
    _recipientWidget = RecipientSelector(fuser, _handleOffline);
  }

  void _submitDetails(callback) async {
    setState(() {
      _loading = true;
    });

    //int stars = _ratingWidget.state.getValue();
    //if(stars < 0) stars = -1;
    String message = _attachmentsWidget.state.getMessage();
    String imagePath = _attachmentsWidget.state.getImagePath();
    List<int> recipients = _recipientWidget.state.getRecipients();
    Map<String, double> location;

    if(_shareLocationValue) {
      String locationError;
      try {
        _locationPermission = await _location.hasPermission();
        location = await _location.getLocation();


        locationError = null;
      } on PlatformException catch (e) {
        if (e.code == 'PERMISSION_DENIED') {
          locationError = 'Permission denied';
        } else if (e.code == 'PERMISSION_DENIED_NEVER_ASK') {
          locationError =
          'Permission denied - please ask the user to enable it from the app settings';
        }

        location = null;
      }
      if (locationError != null) {
        print(locationError);
      }
    }

    String token = await fuser.getIdToken();

    // Upload image
    BackendStatusResponse uploadResponse;
    if(imagePath != null) {
      uploadResponse = await FirebaseBackend.uploadImage(
          token, imagePath);
    }

    BackendStatusResponse response = await FirebaseBackend.checkIn(
      token,
      FirebaseBackend.constructCheckInInfo(message: message, imageId: uploadResponse == null || uploadResponse.type == 'error' ? null : uploadResponse.raw['image_id'], location: location),
      recipients);

    bool close = true;
    if(response.type == 'error') {
      scaffoldKey.currentState.showSnackBar(SnackBar(content: Text('There was an error checking in')));
      close = false;
    }

    setState(() {
      _loading = false;
      if(close) callback(response);
    });
  }

  void _handleOffline(isOffline) {
    setState(() {
      _offline = isOffline;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(_showLocationPermissionPopup && !_locationPermission) {
      _location.onLocationChanged().listen((Map<String, double> result) {
        setState(() {
          _currentLocation = result;
        });
      });
      _updateLocationPermission(state: true);
    }
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text('Check In')
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(children:[
          _recipientWidget,
          Divider(),
          ListTile(
            leading: Checkbox(
              onChanged: (value) {
                setState(() {
                  _showLocationPermissionPopup = true;
                  _shareLocationValue = value;
                  _setLocationCacheProperty();
                });
              },
              value: _shareLocationValue
            ),
            title: Text('Share current location with selected recipients'),
            onTap: () {
              setState(() {
                _showLocationPermissionPopup = true;
                _shareLocationValue = !_shareLocationValue;
                _setLocationCacheProperty();
              });
            }
          ),
          Divider(),
          _attachmentsWidget,
          Divider(),
          ButtonBar(
            children: <Widget>[
              RaisedButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              RaisedButton(
                child: () {
                  Widget _finishText = Text('Finish');
                  if(!_loading) return _finishText;
                  else {
                    return Row(
                      children: <Widget>[
                        Container(
                          child: SizedBox(
                            child: CircularProgressIndicator(
                                valueColor: new AlwaysStoppedAnimation<Color>(Colors.white)
                            ),
                            width: 22.0,
                            height: 22.0,
                          ),
                          padding: EdgeInsets.only(right: 16.0)
                        ),
                        _finishText
                      ],
                    );
                  }
                }(),
                color: Colors.blue,
                textColor: Colors.white,
                onPressed: (_offline) ? null : () {
                  _submitDetails((BackendStatusResponse r) {
                    Navigator.pop(context, r);
                  });
                },
              )
            ],
          )
        ])
      )
    );
  }
}
class CheckInAttachments extends StatefulWidget {
  _CheckInAttachmentsState state;

  _CheckInAttachmentsState createState() {
    state = _CheckInAttachmentsState();
    return state;
  }
}
class _CheckInAttachmentsState extends State<CheckInAttachments> {
  Future<File> _getLocalFile(String filename) async {
    File f = new File('$filename');
    return f;
  }

  void _animTimer(callback) {
    Timer(Duration(milliseconds: 200), callback);
  }

  bool message = false;
  bool image = false;
  String _message;
  String _imagePath;

  void _addMessage() {
    _animTimer(() {
      setState(() {
        message = true;
      });
    });
  }
  void _addImage() async {
    final imagePath = await Navigator.push(context, MaterialPageRoute(builder: (context) => CameraExampleHome()));
    _animTimer(() {
      setState(() {
        image = true;
        _imagePath = imagePath;
      });
    });
  }
  void _removeMessage() {
    _animTimer(() {
      setState(() {
        message = false;
      });
    });
  }
  void _removeImage() {
    _animTimer(() {
      setState(() {
        image = false;
      });
    });
  }

  bool hasMessage() {
    return message;
  }
  bool hasImage() {
    return image;
  }
  String getMessage() {
    if(message) {
      return _message;
    }
    return null;
  }
  String getImagePath() {
    if(image) {
      return _imagePath;
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    List<Widget> msgChildren = [];
    List<Widget> rowChildren = [];
    List<Widget> imgChildren = [];

    if(!message) {
      rowChildren.add(
        RaisedIconButton(
          icon: Icons.message,
          text: 'Add Message',
          onPressed: _addMessage,
        )
      );
      if(!image) {
        rowChildren.add(
          Spacer()
        );
      }
    }
    else {
      msgChildren.addAll([
        TextField(
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: 3,
          onChanged: (value) => _message = value,
        ),
        FlatButton(
          child: Text('Remove Message'),
          textColor: Colors.blue,
          onPressed: _removeMessage,
        )
      ]);
    }
    if(!image) {
      rowChildren.add(
        RaisedIconButton(
          icon: Icons.image,
          text: 'Add Image',
          onPressed: _addImage,
        )
      );
    }
    else {
      imgChildren.add(
        Stack(
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(15.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            new FutureBuilder(
              future: _getLocalFile(_imagePath),
              builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
                return snapshot.data != null ? new Image.file(snapshot.data) :new Container() /*new Center(child: new CircularProgressIndicator())*/;
            }),
          ],
        )
      );
      imgChildren.add(
        FlatButton(
          child: Text('Remove Image'),
          textColor: Colors.blue,
          onPressed: _removeImage,
        )
      );
    }

    return Column(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: msgChildren
        ),
        Row(
          children: rowChildren
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: imgChildren
        )
      ]
    );
  }
}
