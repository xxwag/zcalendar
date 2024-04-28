import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

class NotificationHandler {
  static final _winNotifyPlugin = WindowsNotification(
    applicationId: "yesssssirwahatatata",
  );

  static void showNotification(String title, String message) {
    print("Current platform: ${Platform.operatingSystem}");

    if (Platform.isAndroid) {
      // No need to show toast for Android
    } else if (Platform.isIOS) {
      // No need to show toast for iOS
    } else if (Platform.isWindows) {
      _showWindowsNotification(title, message);
    }
  }

  static void _showWindowsNotification(String title, String message) {
    final notificationMessage = NotificationMessage.fromPluginTemplate(
      title,
      message,
      message,
    );

    _winNotifyPlugin.showNotificationPluginTemplate(notificationMessage);
  }

  static void showPlatformDialog(
      BuildContext context, String title, String message) {
    late Widget dialog;

    if (Platform.isAndroid || Platform.isWindows) {
      dialog = AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      );
    } else if (Platform.isIOS) {
      dialog = CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (BuildContext context) => dialog,
    );
  }
}
