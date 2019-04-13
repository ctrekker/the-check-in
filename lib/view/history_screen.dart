import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_check_in/util/firebase_custom.dart';
import 'package:the_check_in/view/activity_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  FirebaseUser _user;
  HistoryScreen(FirebaseUser user) {
    _user = user;
  }
  @override
  State<StatefulWidget> createState() => HistoryScreenState(_user);
}

class HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  bool _error = false;
  FirebaseUser _user;

  List<String> _dropdownOptions = ['Your Check-Ins', 'Other\'s Check-Ins', 'Your Check-In Requests', 'Other\'s Check-In Requests'];
  List<String> _queryString = ['your_checkins', 'others_checkins', 'your_checkin_requests', 'others_checkin_requests'];
  String _selectedOption;
  dynamic _listItems = [];

  int _page = 0;
  int _quantity = 20;
  int _maxPage = 0;
  int _buttonCount = 3;

  HistoryScreenState(FirebaseUser user) {
    _user = user;

    _selectedOption = _dropdownOptions[0];
  }

  void _handleItemTap(int index) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailsScreen(json.encode(_listItems[index]['message']))));
  }

  void _loadItems() async {
    try {
      String token = await _user.getIdToken();
      String queryString = _queryString[_dropdownOptions.indexOf(
          _selectedOption)];
      _listItems =
      await FirebaseBackend.getCheckIns(token, _quantity, _page, queryString)
          .timeout(Duration(seconds: 7));
      if (!(_listItems is List) && _listItems.type != 'success') {
        _error = true;
      }
      BackendStatusResponse maxPageRes = await FirebaseBackend
          .getCheckInsResultCount(token, queryString);
      if (maxPageRes.type == 'success') {
        double _doubleMaxPage = (maxPageRes.raw['resultCount'] / _quantity);
        _maxPage = _doubleMaxPage.floor();
        if (_doubleMaxPage.floor() == _doubleMaxPage.ceil()) _maxPage--;
      }
      else {
        _error = true;
      }
      setState(() {
        _loading = false;
      });
    } on TimeoutException catch(_) {
      setState(() {
        _loading = false;
        _listItems = null;
      });
    }
  }

  void _nextPage() {
    _page++;
    setState(() {
      _loading = true;
    });
  }
  void _prevPage() {
    _page--;
    setState(() {
      _loading = true;
    });
  }
  void _lastPage() {
    _page = _maxPage;
    setState(() {
      _loading = true;
    });
  }
  void _firstPage() {
    _page = 0;
    setState(() {
      _loading = true;
    });
  }
  bool _hasPrevPage() {
    return _page > 0;
  }
  bool _hasNextPage() {
    return _page < _maxPage;
  }

  List<Widget> _buildPaginatorButtons() {
    List<Widget> out = [];

    out.add(MaterialButton(
      child: Row(
          children: [
            Icon(Icons.arrow_back),
            Text('Back')
          ]
      ),
      onPressed: _hasPrevPage()?_prevPage:null,
    ));
    out.add(Text('Page '+(_page+1).toString()+' of '+(_maxPage+1).toString()));
    out.add(MaterialButton(
      child: Row(
          children: [
            Text('Next'),
            Icon(Icons.arrow_forward)
          ]
      ),
      onPressed: _hasNextPage()?_nextPage:null,
    ));

//    int offset = (_buttonCount/2).floor();
//    for(int i=_page-offset; i < _page+offset+1; i++) {
//      if(i<0&&i<=_maxPage) {
//        continue;
//      }
//      out.add(ButtonTheme(
//        minWidth: 0.0,
//        height: 10.0,
//        child: RaisedButton(
//          child: Text((i+1).toString()),
//          onPressed: () {
//
//          }
//        )
//      ));
//    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if(_loading) {
      Timer(Duration(milliseconds: 250), _loadItems);
    }

    int _itemCount = (20*2)+2;

    ListView activityList = new ListView.builder(
      itemCount: _itemCount,
      padding: EdgeInsets.all(32.0),
      itemBuilder: (BuildContext context, int index) {
        int listIndex = (index/2).floor()-1;
        if(index==0) {
          return Row(
            children: [
              DropdownButton<String>(
                items: _dropdownOptions.map((String value) {
                  return new DropdownMenuItem<String>(
                    value: value,
                    child: new Text(value)
                  );
                }).toList(),
                hint: Text(_selectedOption, style: TextStyle(color: Colors.black)),
                onChanged: (value) {
                  _selectedOption = value;
                  _page = 0;
                  this.setState(() {
                    _loading = true;
                  });
                }
              )
            ]
          );
        }
        else if(_loading && index == 1) {
          return Container(
            child: Center(child: CircularProgressIndicator()),
            padding: EdgeInsets.all(32.0),
          );
        }
        else if(!_loading && index == 1 && _listItems == null) {
          return Container(
            child: Column(
              children: [
                Text('We were unable to contact our servers. Please check your internet connection'),
                RaisedButton(
                  child: Text('Try Again'),
                  onPressed: () {
                    setState(() {
                      _loading = true;
                    });
                  }
                )
              ]
            )
          );
        }
        else if(!_loading && index > 1 && _listItems == null) {
          return Container();
        }
        else if(!_loading && (index == 1 || index == _itemCount - 1) && _maxPage == -1) {
          if(index == 1) {
            String text = '';
            if(_dropdownOptions.indexOf(_selectedOption) == 0) {
              text = 'History for when you check in will show up here';
            }
            else if(_dropdownOptions.indexOf(_selectedOption) == 1) {
              text = 'History for when other people check in with you will show up here';
            }
            else if(_dropdownOptions.indexOf(_selectedOption) == 2) {
              text = 'History for when you send check in requests will show up here';
            }
            else if(_dropdownOptions.indexOf(_selectedOption) == 3) {
              text = 'History for when others send you check in requests will show up here';
            }
            return Container(
                padding: EdgeInsets.all(12.0),
                child: Text(
                    text,
                    style: TextStyle(fontStyle: FontStyle.italic))
            );
          }
          else {
            return Container();
          }
        }
        else if(!_loading && (index == 1 || index == _itemCount - 1)) {
          return Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildPaginatorButtons(),
            )
          );
        }
        else if(!_loading && index % 2 == 0) {
          if(listIndex >= _listItems.length) {
            return Container();
          }

          void _tapHandler() {
            _handleItemTap(listIndex);
          }
          Widget _goButton = IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: _tapHandler
          );
          if(_dropdownOptions.indexOf(_selectedOption) == 0) {
            return ListTile(
              title: Text('You checked in'),
              subtitle: Text(_listItems[listIndex]['checkin_time_parsed']),
              trailing: _goButton,
              onTap: _tapHandler,
            );
          }
          else if(_dropdownOptions.indexOf(_selectedOption) == 1) {
            return ListTile(
              title: Text(_listItems[listIndex]['name']+' checked in'),
              subtitle: Text(_listItems[listIndex]['checkin_time_parsed']),
              trailing: _goButton,
              onTap: _tapHandler
            );
          }
          else if(_dropdownOptions.indexOf(_selectedOption) == 2) {
            return ListTile(
              title: Text('You requested a check in'),
              subtitle: Text(_listItems[listIndex]['checkin_time_parsed'])
            );
          }
          else if(_dropdownOptions.indexOf(_selectedOption) == 3) {
            return ListTile(
                title: Text(_listItems[listIndex]['name']+' requested a check in'),
                subtitle: Text(_listItems[listIndex]['checkin_time_parsed'])
            );
          }
        }
        else if(!_loading && listIndex < _listItems.length) {
          return Divider();
        }
        else {
          return Container();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('History')
      ),
      body: activityList
    );
  }
}
