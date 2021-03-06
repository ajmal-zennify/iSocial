import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:isocial/pages/profile.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:isocial/helpers/custom_popup_menu.dart';
import 'package:isocial/helpers/zoomable.dart';

import 'package:isocial/models/user.dart';

import 'package:isocial/pages/comments.dart';
import 'package:isocial/pages/home.dart';
import 'package:isocial/pages/post_studio.dart';

import 'package:isocial/widgets/popup_menu.dart';
import 'package:isocial/widgets/progress.dart';
import 'package:isocial/widgets/custom_image.dart';
import 'package:isocial/widgets/video_player_widget.dart';

class Post extends StatefulWidget {
  final String postId;
  final String ownerId;
  final String username;
  final String displayName;
  final String location;
  final String caption;
  final String backgroundColor;
  final String postAudience;
  final dynamic feelingOrActivity;
  final dynamic taggedPeople;
  final dynamic mediaUrl;
  final Timestamp createdAt;
  final dynamic likes;
  final dynamic saves;

  Post({
    this.postId,
    this.ownerId,
    this.username,
    this.displayName,
    this.location,
    this.caption,
    this.backgroundColor,
    this.postAudience,
    this.feelingOrActivity,
    this.taggedPeople,
    this.mediaUrl,
    this.createdAt,
    this.likes,
    this.saves
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      displayName: doc['displayName'],
      location: doc['location'],
      caption: doc['caption'],
      backgroundColor: doc['backgroundColor'],
      postAudience: doc['postAudience'],
      feelingOrActivity: doc['feelingOrActivity'],
      taggedPeople: doc['taggedPeople'],
      mediaUrl: doc['mediaUrl'],
      createdAt: doc['createdAt'],
      likes: doc['likes'],
      saves: doc['saves']
    );
  }

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    displayName: this.displayName,
    location: this.location,
    caption: this.caption,
    backgroundColor: this.backgroundColor,
    postAudience: this.postAudience,
    feelingOrActivity: this.feelingOrActivity,
    taggedPeople: this.taggedPeople,
    mediaUrl: this.mediaUrl,
    createdAt: this.createdAt,
    likes: this.likes,
    saves: this.saves,
    likeCount: getLikeCount(this.likes)
  );
}

class _PostState extends State<Post> {
  static var httpClient = new HttpClient();
  final String currentUserId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String displayName;
  final String location;
  final String caption;
  final String backgroundColor;
  final String postAudience;
  final dynamic feelingOrActivity;
  final dynamic taggedPeople;
  final dynamic mediaUrl;
  final Timestamp createdAt;
  bool showHeart = false;
  int likeCount;
  Map likes;
  Map saves;
  Map downloadedVideos;
  bool isLiked;
  bool isSaved;
  int commentCount = 0;
  int currentMedia = 0;
  bool isPostDeleted = false;
  Map<String, String> mappedFeelingOrActivity = Map<String, String>();
  Map<String, String> mappedTaggedPeople = Map<String, String>();

  _PostState({
    this.postId,
    this.ownerId,
    this.username,
    this.displayName,
    this.location,
    this.caption,
    this.backgroundColor,
    this.postAudience,
    this.feelingOrActivity,
    this.taggedPeople,
    this.mediaUrl,
    this.createdAt,
    this.likes,
    this.saves,
    this.likeCount
  });

  @override
  void initState() {
    super.initState();
    getCommentCount();
    if (feelingOrActivity != null) {
      feelingOrActivity.forEach((key, value) {
        mappedFeelingOrActivity.addAll({key: value});
      });
    }
    if (taggedPeople != null) {
      taggedPeople.forEach((key, value) {
        mappedTaggedPeople.addAll({key: value});
      });
    }
  }

  List<T> map<T>(List list, Function handler) {
    List<T> result = [];
    for (var i = 0; i < list.length; i++) {
      result.add(handler(i, list[i]));
    }
    return result;
  }

  buildPostHeader() {
    List<CustomPopupMenu> choices = <CustomPopupMenu>[];
    choices = <CustomPopupMenu>[
      CustomPopupMenu(
        id: 'edit',
        title: 'Edit Post',
        icon: Icons.edit
      ),
      CustomPopupMenu(
        id: 'delete',
        title: 'Delete Post',
        icon: Icons.delete
      )
    ];
    if (ownerId != currentUser.id && !atOtherProfile) {
      choices = <CustomPopupMenu>[
        CustomPopupMenu(
          id: 'save',
          title: isSaved ? 'Unsave This Post' : 'Save This Post',
          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
        ),
        CustomPopupMenu(
          id: 'hide',
          title: 'Hide This Post',
          icon: Icons.close
        ),
        CustomPopupMenu(
          id: 'snooze',
          title: 'Snooze $username for 30 days',
          icon: Icons.volume_up
        ),
        CustomPopupMenu(
          id: 'unfollow',
          title: 'Unfollow $username',
          icon: Icons.remove_circle
        ),
        CustomPopupMenu(
          id: 'report',
          title: 'Report This Post',
          icon: Icons.report
        )
      ];
    }

    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot) {
        if(!snapshot.hasData) {
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.photoUrl),
            backgroundColor: Colors.grey,
          ),
          title: configurePostTitle(
            context,
            displayName,
            ownerId,
            feelingOrActivity,
            taggedPeople
          ),
          subtitle: Text(location),
          trailing: handleTrailingWidget(choices)
        );
      }
    );
  }

  Widget handleTrailingWidget(choices) {
    if (ownerId != currentUser.id && atOtherProfile) {
      return IconButton(
        icon: Icon(
          isSaved ? Icons.bookmark : Icons.bookmark_border,
          color: Colors.purple
        ),
        onPressed: handleSavePost,
      );
    } else if (ownerId != currentUser.id && !atOtherProfile) {
      return popupMenu(
        tooltip: 'Post Options',
        onSelect: handlePostOption,
        choices: choices,
        context: context
      );
    } else {
      return popupMenu(
        tooltip: 'Post Options',
        onSelect: handlePostOption,
        choices: choices,
        context: context
      );
    }
  }

  handlePostOption(CustomPopupMenu choice) {
    if (choice.id == 'delete') handleDeletePost(context);
    if (choice.id == 'edit') handleEditPost();
    if (choice.id == 'save') handleSavePost();
    if (choice.id == 'unfollow') unfollowUser(ownerId);
  }

  handleEditPost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PostStudio(
        state: 'edit',
        onExit: () => Navigator.pop(context),
        postToBeEditedId: postId,
        postTitle: configurePostTitle(
          context,
          displayName,
          ownerId,
          feelingOrActivity,
          taggedPeople
        ),
        manualLocation: location,
        lockPost: postAudience == 'Followers' ? false : true,
        caption: caption,
        assets: mediaUrl.length > 0 ? mediaUrl : List<dynamic>(),
        selectedFeelingOrActivity: mappedFeelingOrActivity.isNotEmpty
            ? mappedFeelingOrActivity : null,
        taggedPeople: mappedTaggedPeople.isNotEmpty ? mappedTaggedPeople : null,
        backgroundColor: backgroundColor.isNotEmpty ? backgroundColor : ''
      ))
    );
  }

  handleDeletePost(BuildContext parentContext) {
    return showDialog(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirmation Dialog'),
          content: Text('Are you sure you want to delete this post?'),
          actions: <Widget>[
            FlatButton(
              child: Text(
                'Yes',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold
                )
              ),
              onPressed: () {
                Navigator.pop(context);
                deletePost();
              },
            ),
            FlatButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            )
          ],
        );
      }
    );
  }

  deletePost() async {
    postsRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .updateData({'isDeleted': true});

    QuerySnapshot activityFeedSnapshot = await activityFeedRef
      .document(ownerId)
      .collection('feedItems')
      .where('postId', isEqualTo: postId)
      .getDocuments();
    activityFeedSnapshot.documents.forEach((doc) {
      if (doc.exists) {
        activityFeedRef
          .document(ownerId)
          .collection('feedItems')
          .document(postId)
          .updateData({'isDeleted': true});
      }
    });

    QuerySnapshot commentsSnapshot = await commentsRef
      .document(postId)
      .collection('comments')
      .getDocuments();
    commentsSnapshot.documents.forEach((doc) async {
      if (doc.exists) {
        final String commentId = doc.data['commentId'];
        final String commentOwnerId = doc.data['userId'];

        commentsRef
          .document(postId)
          .collection('comments')
          .document(commentId)
          .updateData({'isDeleted': true});

        QuerySnapshot activityFeedSnapshot2 = await activityFeedRef
          .document(commentOwnerId)
          .collection('feedItems')
          .where('commentId', isEqualTo: commentId)
          .getDocuments();
        activityFeedSnapshot2.documents.forEach((doc) {
          if (doc.exists) {
            activityFeedRef
              .document(commentOwnerId)
              .collection('feedItems')
              .document(commentId)
              .updateData({'isDeleted': true});
          }
        });
      }
    });

    setState(() { isPostDeleted = true; });
  }

  getCommentCount() async {
    int count = 0;
    QuerySnapshot commentsSnapshot = await commentsRef
      .document(postId)
      .collection('comments')
      .getDocuments();
    commentsSnapshot.documents.forEach((doc) {
      if (doc.exists) count += 1;
    });
    setState(() { commentCount = count; });
  }

  handleSavePost() {
    bool _isSaved = saves[currentUserId] == true;
    if (_isSaved) {
      savedItemsRef
        .document(ownerId)
        .collection('userItems')
        .document(postId)
        .get().then((doc) {
          if (doc.exists) doc.reference.delete();
        });

      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'saves.$currentUserId': false});
      setState(() {
        isSaved = false;
        saves[currentUserId] = false;
      });
    } else if (!_isSaved) {
      savedItemsRef
        .document(ownerId)
        .collection('userItems')
        .document(postId)
        .setData({});

      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'saves.$currentUserId': true});
      setState(() {
        isSaved = true;
        saves[currentUserId] = true;
      });
    }
  }

  handleLikePost() {
    bool _isLiked = likes[currentUserId] == true;

    if (_isLiked) {
      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId': false});
      removeLikeFromActivityFeed();
      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUserId] = false;
      });
    } else if (!_isLiked) {
      postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .updateData({'likes.$currentUserId': true});
      addLikeToActivityFeed();
      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUserId] = true;
        showHeart = true;
      });
      Timer(Duration(milliseconds: 500), () {
        setState(() { showHeart = false; });
      });
    }
  }

  addLikeToActivityFeed() {
    // add a notification to the postOwner's activity feed only if
    // comment made by OTHER user (to avoid getting notification for our
    // own like)
    bool isNotPostOwner = currentUserId != ownerId;
    if (isNotPostOwner) {
      activityFeedRef
        .document(ownerId)
        .collection('feedItems')
        .document(postId)
        .setData({
          'type': 'like',
          'username': currentUser.username,
          'userId': currentUser.id,
          'userProfileImg': currentUser.photoUrl,
          'postId': postId,
          'mediaUrl': mediaUrl,
          'timestamp': timestamp
        });
    }
  }

  removeLikeFromActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;
    if (isNotPostOwner) {
      activityFeedRef
        .document(ownerId)
        .collection('feedItems')
        .document(postId)
        .get().then((doc) {
          if (doc.exists) {
            doc.reference.delete();
          }
        });
    }
  }

  buildPostContent() {
    Color bgColor = Colors.white;
    Color color = Colors.white;
    switch (backgroundColor) {
      case 'red': bgColor = Colors.red; break;
      case 'green': bgColor = Colors.green; break;
      case 'blue': bgColor =  Colors.blue; break;
      case 'yellow': bgColor = Colors.yellow; color = Colors.black; break;
      case 'black': bgColor = Colors.black; break;
      case 'purple': bgColor = Colors.purple; break;
      default: color = Colors.black;
    }
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: EdgeInsets.all(2.0),
      color: bgColor,
      child: backgroundColor.isNotEmpty ? Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(padding: EdgeInsets.only(top: 50.0)),
          Padding(
            padding: EdgeInsets.only(left: 20.0, right: 20.0),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 30.0,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            )
          ),
          Padding(padding: EdgeInsets.only(bottom: 50.0))
        ]
      ) : Text(caption)
    );
  }

  buildPostImage() {
    return GestureDetector(
      onDoubleTap: handleLikePost,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CarouselSlider(
            items: mediaUrl.map<Widget>(
              (media) {
                if (media.runtimeType == String) {
                  if (media.contains('mp4')) {
                    return VideoPlayerWidget(videoType: 'network', video: media);
                  }
                  return Zoomable(child: cachedNetworkImage(context, media));
                } else {
                  return VideoPlayerWidget(videoType: 'file', video: media);
                }
              }
            ).toList(),
            autoPlay: false,
            viewportFraction: 1.0,
            aspectRatio: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index) {
              setState(() { currentMedia = index; });
            },
          ),
          showHeart ? Icon(
            Icons.favorite,
            size: 80.0,
            color: Colors.red
          ) : Text('')
        ],
      )
    );
  }

  buildPostFooter() {
    return Column(
      children: <Widget>[
        mediaUrl.length > 1 ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: map<Widget>(
            mediaUrl,
            (index, media) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentMedia == index
                    ? Theme.of(context).primaryColor
                    : Color.fromRGBO(0, 0, 0, 0.4)
                )
              );
            }
          )
        ) : Text(''),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 40.0, left: 15.0)),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink
              )
            ),
            Padding(padding: EdgeInsets.only(right: 5.0)),
            Text(
              '$likeCount likes',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold
              )
            ),
            Padding(padding: EdgeInsets.only(right: 20.0)),
            GestureDetector(
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl
              ),
              child: Icon(
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900]
              )
            ),
            Padding(padding: EdgeInsets.only(right: 5.0)),
            Text(
              '$commentCount comments',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold
              )
            )
          ],
        ),
        Padding(
          padding: EdgeInsets.only(
            top: mediaUrl.length > 0 && caption.isNotEmpty ? 10.0 : 0.0
          )
        ),
        mediaUrl.length > 0 && caption.isNotEmpty ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                '$username ',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold
                )
              )
            ),
            Expanded(child: Row(children: buildCaption()))
          ],
        ) : timeWidget(),
        mediaUrl.length > 0 && caption.isNotEmpty ? timeWidget() : Text('')
      ],
    );
  }

  buildCaption() {
    List<String> splittedCaption = caption.split(' ');
    List<Widget> mergedCaption = new List<Widget>();
    for (String caption in splittedCaption) {
      if (caption.contains('#')) {
        mergedCaption.add(Text(
          '$caption ',
          style: TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline
          )
        ));
      }
      mergedCaption.add(Text('$caption '));
    }
    return mergedCaption;
  }

  timeWidget() {
    return Row(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: 20.0),
          child: Text(
            createdAt.toDate().day > 1
              ? DateFormat.yMMMMd().format(createdAt.toDate())
              : timeago.format(createdAt.toDate()),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey)
          )
        ),
        SizedBox(height: 50.0)
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    isLiked = (likes[currentUserId] == true);
    isSaved = (saves[currentUserId] == true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        isPostDeleted ? Text('') : buildPostHeader(),
        isPostDeleted
            ? Text('')
            : mediaUrl.length > 0
            ? buildPostImage()
            : buildPostContent(),
        isPostDeleted ? Text('') : buildPostFooter()
      ],
    );
  }
}

showComments(BuildContext context, { String postId, String ownerId,
dynamic mediaUrl }) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) {
      return Comments(
        postId: postId,
        postOwnerId: ownerId,
        postMediaUrl: mediaUrl
      );
    })
  );
}

int getLikeCount(likes) {
  // if no likes, return 0
  if (likes == null) {
    return 0;
  }
  int count = 0;
  // if the key is explicitly set to true, add a like
  likes.values.forEach((val) {
    if (val == true) {
      count += 1;
    }
  });
  return count;
}