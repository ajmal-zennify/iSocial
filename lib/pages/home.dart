import 'dart:io';

// External Packages
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Models
import 'package:isocial/models/user.dart';

// Pages
import 'package:isocial/pages/timeline.dart';
import 'package:isocial/pages/activity_feed.dart';
import 'package:isocial/pages/upload.dart';
import 'package:isocial/pages/search.dart';
import 'package:isocial/pages/profile.dart';
import 'package:isocial/widgets/post.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final StorageReference storageRef = FirebaseStorage.instance.ref();
final usersRef = Firestore.instance.collection('users');
final postsRef = Firestore.instance.collection('posts');
final commentsRef = Firestore.instance.collection('comments');
final repliesRef = Firestore.instance.collection('replies');
final activityFeedRef = Firestore.instance.collection('feed');
final followersRef = Firestore.instance.collection('followers');
final followingRef = Firestore.instance.collection('following');
final timelineRef = Firestore.instance.collection('timeline');
final savedItemsRef = Firestore.instance.collection('savedItems');
final DateTime timestamp = DateTime.now();
final _scaffoldKey = GlobalKey<ScaffoldState>();
bool atOtherProfile = false;
String currentUserLocation;
FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
User currentUser;

class Home extends StatefulWidget {
  final List<Post> posts;
  final List<String> followingList;

  Home({ this.posts, this.followingList });

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isAuth = false;
  PageController pageController;
  int pageIndex = 0;
  
  @override
  void initState() {
    super.initState();
    getUserLocation();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  onPageChanged(int pageIndex) {
    setState(() { this.pageIndex = pageIndex; });
  }

  onTap(int pageIndex) {
    pageController.animateToPage(
      pageIndex,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut
    );
  }

  Scaffold buildHome() {
    return Scaffold(
      key: _scaffoldKey,
      body: PageView(
        children: <Widget>[
          Timeline(
            currentUser: currentUser,
            posts: widget.posts,
            followingList: widget.followingList
          ),
          ActivityFeed(),
          Upload(currentUser: currentUser),
          Search(),
          Profile(profileId: currentUser?.id)
        ],
        controller: pageController,
        onPageChanged: onPageChanged,
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: pageIndex,
        onTap: onTap,
        activeColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.whatshot)),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active)),
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera, size: 35.0)),
          BottomNavigationBarItem(icon: Icon(Icons.search)),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle))
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildHome();
  }
}

configurePushNotifications() {
  final GoogleSignInAccount user = googleSignIn.currentUser;
  if (Platform.isIOS) getiOSPermission();

  _firebaseMessaging.getToken().then((token) {
    usersRef
        .document(user.id)
        .updateData({"androidNotificationToken": token});
  });

  _firebaseMessaging.configure(
//      onLaunch: (Map<String, dynamic> message) async {},
//      onResume: (Map<String, dynamic> message) async {},
      onMessage: (Map<String, dynamic> message) async {
        final String recipientId = message['data']['recipient'];
        final String body = message['notification']['body'];
        if (recipientId == user.id) {
          SnackBar snackbar = SnackBar(
              content: Text(
                  body,
                  overflow: TextOverflow.ellipsis
              )
          );
          _scaffoldKey.currentState.showSnackBar(snackbar);
        }
      }
  );
}

getiOSPermission() {
  _firebaseMessaging.requestNotificationPermissions(
      IosNotificationSettings(alert: true, badge: true, sound: true)
  );
  _firebaseMessaging.onIosSettingsRegistered.listen((settings) {
    print("Settings registered: $settings");
  });
}

getUserLocation() async {
  Position position = await Geolocator().getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high
  );
  List<Placemark> placemarks = await Geolocator().placemarkFromCoordinates(
      position.latitude,
      position.longitude
  );
  Placemark placemark = placemarks[0];
  String formattedAddress =
      '${placemark.administrativeArea}, ${placemark.country}';
  currentUserLocation = formattedAddress;
}