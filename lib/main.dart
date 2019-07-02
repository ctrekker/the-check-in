library health_check.main;

import 'dart:convert';

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
import 'package:the_check_in/view/activity_widget.dart';
import 'package:the_check_in/view/history_screen.dart';
import 'package:the_check_in/view/quick_check_in_widget.dart';
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

  try {
    FirebaseBackend.getMapsApiKey().then((key) {
      Config.setMapsApiKey(key);
      Maps.MapView.setApiKey(Config.getMapsApiKey());
    }).catchError((err) {
      print('Error retrieving maps API key. Printing trace...');
      print(err.toString());
    });
  } catch(e) {
    print('Error retrieving maps API key. Printing trace...');
    print(e.toString());
  }

  runApp(new MyApp());
  cameraInit();
}

class AppStateListener with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    print(state);
    if(state == AppLifecycleState.paused && fuser != null) {
      FirebaseBackend.setActivityViewed(await fuser.getIdToken());
    }
    if(state == AppLifecycleState.resumed && fuser != null) {
      ActivityWidgetState.updateCallback();
    }
  }
}

int currentTimeMillis() {
  return new DateTime.now().millisecondsSinceEpoch;
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(AppStateListener());

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

  bool _updatedTheme = false;

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
  void _updateTheme() {
    setState(() {
      _updatedTheme = true;
    });
  }
  @override
  Widget build(BuildContext context) {
    if(_updatedTheme) _updatedTheme = false;

    double fontScale = 1.25;
    if(Config.getSettings() != null && Config.getSettings().containsKey('font_scale')) {
      fontScale = double.parse(Config.getSettings()['font_scale'].replaceAll(new RegExp(r'%'), '')) / 100.0;
    }

    dynamic textSize = {
      'headline': 72.0,
      'title': 20.0,
      'subhead': 16.0,
      'body1': 14.0,
      'body2': 14.0,
      'button': 14.0
    };
    textSize.forEach((key, value) {
      textSize[key] = value * fontScale;
    });

    return MaterialApp(
      title: 'The Check In',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
        dividerColor: Colors.grey,
        textTheme: TextTheme(
          headline: TextStyle(fontSize: textSize['headline'], fontWeight: FontWeight.bold),
          title: TextStyle(fontSize: textSize['title'], fontWeight: FontWeight.normal),
          subhead: TextStyle(fontSize: textSize['subhead']),
          body1: TextStyle(fontSize: textSize['body1']),
          body2: TextStyle(fontSize: textSize['body2'], fontWeight: FontWeight.normal),
          button: TextStyle(fontSize: textSize['button'])
        ),
      ),
      home: LandingScreen(_updateTheme),
    );
  }
}

class LandingScreen extends StatefulWidget {
  dynamic _themeUpdateCallback;
  LandingScreen(_themeUpdateCallback) {
    this._themeUpdateCallback = _themeUpdateCallback;
  }
  _LandingScreenState createState() => _LandingScreenState(_themeUpdateCallback);
}
class _LandingScreenState extends State<LandingScreen> {
  bool _first = true;
  bool _showLoading = true;
  bool _loggedIn = false;
  bool _offline = false;
  bool _blacklistedVersion = false;
  ActivityWidget activityWidget;
  QuickCheckInWidget qciWidget;
  dynamic _themeUpdateCallback;

  _LandingScreenState(_themeUpdateCallback) {
    this._themeUpdateCallback = _themeUpdateCallback;
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

    if(await FirebaseBackend.checkBackendOnline()) {
      fuser = await auth.currentUser();
      dynamic checkBlacklisted = await FirebaseBackend.checkBlacklistedVersion(Config.applicationVersion);

      if(checkBlacklisted['blacklisted']) {
        setState(() {
          _blacklistedVersion = true;
        });
      }
      else if (fuser != null) {
        String token = await fuser.getIdToken();
        print(token);
        FirebaseBackend.setTimezone(token, DateTime.now().timeZoneOffset.inHours.toString()+":"+DateTime.now().timeZoneName);
        Config.settingsListeners.add((settings) {
          _themeUpdateCallback();
        });
        await FirebaseBackend.updateSettings(token);

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

  ScrollController _landscapeScrollController;
  double _landscapeScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _landscapeScrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _landscapeScrollOffset = _landscapeScrollController.offset;
        });
      });
  }
  @override
  void dispose() {
    _landscapeScrollController.dispose();
    super.dispose();
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
    else if(_blacklistedVersion) {
      return Scaffold(
        body: Container(
          padding: EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('You are using a version of this app we no longer support. Please upgrade to continue', textAlign: TextAlign.center),
                Container(padding: EdgeInsets.only(top: 24.0)),
                Text('Current version: ' + Config.applicationVersion)
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

    double padding = 30.0;
    Widget checkInButton = Builder(
      builder: (BuildContext context) {
        return Container(
          child: GestureDetector(
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.all(Radius.circular(90.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    offset: Offset(5.0, 5.0),
                    blurRadius: 10.0
                  )
                ]
              ),
              child: Center(
                child: Text('Check In',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.button.merge(TextStyle(color: Colors.white))
                )
              )
            ),
            onTap: () async {
              BackendStatusResponse res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CheckInScreen()),
              );
              if(res != null) {
                if(res.type == 'success') {
                  Scaffold.of(context).showSnackBar(
                      SnackBar(content: Text(res.message,
                          style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
                        duration: Duration(seconds: 2),
                      )
                  );
                }
                else if(res.type == 'warning' || res.type == 'error') {
                  Scaffold.of(context).showSnackBar(
                      SnackBar(content: Text(res.message,
                          style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
                        duration: Duration(seconds: 2),
                      )
                  );
                }
              }
            }
          )
        );
      }
    );
    Widget checkInRequestButton = Builder(
      builder: (BuildContext context) {
        return Container(
          child: GestureDetector(
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.all(Radius.circular(90.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    offset: Offset(5.0, 5.0),
                    blurRadius: 10.0
                  )
                ],
              ),
              child: Center(
                child: Text('Request Check In',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.button.merge(TextStyle(color: Colors.white))
                )
              )
            ),
            onTap: () async {
              BackendStatusResponse res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CheckInRequestScreen()),
              );
              if(res != null) {
                if(res.type == 'success') {
                  Scaffold.of(context).showSnackBar(
                    SnackBar(content: Text(res.message,
                        style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
                      duration: Duration(seconds: 2),
                    )
                  );
                }
                else if(res.type == 'warning' || res.type == 'error') {
                  Scaffold.of(context).showSnackBar(
                    SnackBar(content: Text(res.message,
                        style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
                      duration: Duration(seconds: 2),
                    )
                  );
                }
              }
            }
          )
        );
      }
    );

    if(!_showLoading) {
      activityWidget = ActivityWidget(fuser);
      qciWidget = QuickCheckInWidget(fuser, 3);
      return Scaffold(
        appBar: AppBar(
          title: appTitle,
        ),
        body: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.portrait) {
              qciWidget = QuickCheckInWidget(fuser, 3);
              return ListView(
                padding: const EdgeInsets.only(
                  left: 32.0,
                  right: 32.0,
                  bottom: 32.0
                ),
                children: () {
                  if (_loggedIn) {
                    double spacing = 0.04;
                    return [
                      qciWidget,
                      Wrap(
                        children: <Widget>[
                          FractionallySizedBox(
                            widthFactor: 0.4 - spacing / 2,
                            child: checkInButton
                          ),
                          FractionallySizedBox(
                            widthFactor: spacing,
                            child: Container()
                          ),
                          FractionallySizedBox(
                            widthFactor: 0.6 - spacing / 2,
                            child: checkInRequestButton
                          )
                        ],
                      ),
                      activityWidget
                    ];
                  }
                  else {
                    return <Widget>[];
                  }
                }()
              );
            }
            // Landscape orientation
            else {
              qciWidget = QuickCheckInWidget(fuser, 2);
              double ratio = 0.55;
              const double buttonsPadding = 32.0;
              return SingleChildScrollView(
                controller: _landscapeScrollController,
                child: Container(
//                  padding: EdgeInsets.all(32.0),
                  child: Wrap(
                    children: [
                      FractionallySizedBox(
                        widthFactor: 1.0 - ratio,
                        child: Container(
                          child: Container(
                            padding: EdgeInsets.only(
                              left: buttonsPadding,
                              right: buttonsPadding,
                              top:  _landscapeScrollOffset,
                              bottom: buttonsPadding
                            ),
                            child: Column(
                              children: <Widget>[
                                qciWidget,
                                checkInButton,
                                Container(
                                  padding: EdgeInsets.only(top: 20.0)
                                ),
                                checkInRequestButton,
                              ],
                            )
                          )
                        )
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          padding: EdgeInsets.only(right: 15.0),
                          child: activityWidget
                        )
                      )
                    ]
                  )
                )
              );
            }
          }
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
                leading: Icon(Icons.check),
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
              leading: Icon(Icons.history),
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
  dynamic activity;
  CheckInScreen([dynamic activity]) {
    this.activity = activity;
  }
  _CheckInScreenState createState() => _CheckInScreenState(activity);
}
class _CheckInScreenState extends State<CheckInScreen> {
  FirebaseUser fuser;

  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  bool _offline = true;
  bool _loading = false;
  bool _init = true;

  RatingWidget _ratingWidget = RatingWidget();
  CheckInAttachments _attachmentsWidget = CheckInAttachments();
  RecipientSelector _recipientWidget;
  bool _shareLocationValue = false;

  Location _location = Location();
  String _locationCacheKey = 'locationChecked';
  bool _locationPermission = false;
  Map<String, double> _currentLocation;
  bool _showLocationPermissionPopup = false;

  dynamic activity;

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

  _CheckInScreenState([dynamic activity]) {
    this.activity = activity;
    _initAsync();
  }
  void _initAsync() async {
    fuser = await auth.currentUser();
    if(this.activity != null) {
      dynamic checkedOverride = {};

      dynamic userDetails;
      dynamic message = json.decode(activity['message']);
      for (int i = 0; i < message.length; i++) {
        if (message[i]['title'] == 'user') {
          userDetails = message[i]['value'];
          break;
        }
      }

      String token = await fuser.getIdToken();

      List<dynamic> res = await FirebaseBackend.getAllRecipients(token);
      for (int i = 0; i < res.length; i++) {
        checkedOverride[res[i]['id'].toString()] =
            res[i]['email'] == userDetails['email'];
      }

      _recipientWidget = RecipientSelector(fuser, _handleOffline, checkedOverride);
    }
    else {
      _recipientWidget = RecipientSelector(fuser, _handleOffline);
    }

    setState(() {
      _init = false;
    });
  }

  int _lastSnackBarShow = currentTimeMillis();

  void _submitDetails(callback) async {
    String message = _attachmentsWidget.state.getMessage();
    String imagePath = _attachmentsWidget.state.getImagePath();
    List<int> recipients = _recipientWidget.state.getRecipients();
    if(recipients.length <= 0) {
      if(currentTimeMillis() - _lastSnackBarShow > 1500) {
        scaffoldKey.currentState.showSnackBar(
          SnackBar(
            content: Text('Please select at least 1 recipient',
                style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
            duration: Duration(milliseconds: 1500)
          )
        );
        _lastSnackBarShow = currentTimeMillis();
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    //int stars = _ratingWidget.state.getValue();
    //if(stars < 0) stars = -1;

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
      File img = File(imagePath);
      await img.delete();
    }

    int associatedWith = -1;
    if(this.activity != null) {
      dynamic activityMessage = json.decode(activity['message']);
      for (int i = 0; i < activityMessage.length; i++) {
        if (activityMessage[i]['title'] == 'checkinId') {
          associatedWith = activityMessage[i]['value'];
          break;
        }
      }
    }
    BackendStatusResponse response = await FirebaseBackend.checkIn(
      token,
      FirebaseBackend.constructCheckInInfo(message: message, imageId: uploadResponse == null || uploadResponse.type == 'error' ? null : uploadResponse.raw['image_id'], location: location),
      recipients,
      associatedWith,
      {});

    bool close = true;
    if(response.type == 'error') {
      scaffoldKey.currentState.showSnackBar(
        SnackBar(content: Text('There was an error checking in',
            style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white)))
        )
      );
      close = false;
    }

    setState(() {
      _loading = false;
      if(close) {
        Timer(Duration(milliseconds: 500), () => ActivityWidgetState.updateCallback());
        callback(response);
      }
    });
  }

  void _handleOffline(isOffline) {
    setState(() {
      _offline = isOffline;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(_init) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Check In')
        ),
        body: Center(
          child: CircularProgressIndicator(),
        )
      );
    }
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
                  Widget _finishText = Text('Check In');
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
class CheckInRequestScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CheckInRequestScreenState();
}
class CheckInRequestScreenState extends State<CheckInRequestScreen> {
  bool _offline = true;
  bool _loading = false;
  RecipientSelector _recipientSelector;
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();
  int _lastSnackBarShow = currentTimeMillis();

  void _handleOffline(isOffline) {
    setState(() {
      _offline = isOffline;
    });
  }

  CheckInRequestScreenState() {
    _recipientSelector = RecipientSelector(fuser, _handleOffline);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text('Request a Check In')
      ),
      body: Container(
        padding: EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              _recipientSelector,
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
                      Widget _finishText = Text('Request Check In');
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
            ],
          )
        )
      )
    );
  }

  void _submitDetails(callback) async {
    List<int> recipients = _recipientSelector.state.getRecipients();
    if(recipients.length <= 0) {
      if(currentTimeMillis() - _lastSnackBarShow > 1500) {
        scaffoldKey.currentState.showSnackBar(
          SnackBar(
            content: Text('Please select at least 1 recipient',
                style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white))),
            duration: Duration(milliseconds: 1500)
          )
        );
        _lastSnackBarShow = currentTimeMillis();
      }
      return;
    }

    setState(() {
      _loading = true;
    });

    String token = await fuser.getIdToken();

    BackendStatusResponse response = await FirebaseBackend.checkIn(
        token,
        FirebaseBackend.constructCheckInInfo(),
        recipients,
        -1,
        { "REQUEST_CHECKIN": true });

    bool close = true;
    if(response.type == 'error') {
      scaffoldKey.currentState.showSnackBar(
        SnackBar(content: Text('There was an error checking in',
            style: Theme.of(context).textTheme.body1.merge(TextStyle(color: Colors.white)))
        )
      );
      print(response);
      close = false;
    }

    setState(() {
      _loading = false;
      if(close) {
        Timer(Duration(milliseconds: 500), () => ActivityWidgetState.updateCallback());
        callback(response);
      }
    });
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
