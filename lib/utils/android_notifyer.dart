import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/main.dart';
import 'package:slow_mail/settings.dart';
import 'package:slow_mail/utils/connection_provider.dart';
import 'package:slow_mail/utils/globals.dart';
import 'package:slow_mail/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/generated/locale_keys.g.dart';

// FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class AndroidNotifyer {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  final InitializationSettings initializationSettings;
  NotificationResponse? queuedNotificationTask;
  late NotificationDetails notificationDetails;
  int msgId = 0;
  bool isInitialized = false;
  bool isPermitted = false;

  final String _channelId = "slowmail_new_message";
  final String _channelName = "New Message";
  final String _channelDescription = "Notification of new emails via slowmail";

  // Singleton init
  static final AndroidNotifyer _singleton = AndroidNotifyer._internal();
  factory AndroidNotifyer() {
    return _singleton;
  }
  AndroidNotifyer._internal()
      : flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin(),
        initializationSettings = InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notify')) {
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(_channelId, _channelName,
        channelDescription: _channelDescription,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker');
    notificationDetails = NotificationDetails(android: androidNotificationDetails);
  }

  // Singleton init End
  Future<Map<String, dynamic>?> getLaunchArgs() async {
    try {
      final details = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

      final bool launchedFromNotification = details?.didNotificationLaunchApp ?? false;
      if (!launchedFromNotification) return null;
      final String? payload = details?.notificationResponse?.payload;
      if (payload != null) {
        return jsonDecode(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize({bool directRequestPermission = true}) async {
    await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          await onNotificationResponse(response);
        });
    if (directRequestPermission && !(await hasPermission())) {
      await requestPermission();
    }

    isInitialized = true;
  }

  Future<void> runQueuedNotificationTask() async {
    if (queuedNotificationTask != null) {
      NotificationResponse task = queuedNotificationTask!;
      queuedNotificationTask = null;
      await onNotificationResponse(task);
    }
  }

  Future<void> onNotificationResponse(NotificationResponse response) async {
    if (response.payload == null) return;
    if (!(NavService.navKey.currentContext?.read<ConnectionProvider>().netAvailable ?? false)) {
      queuedNotificationTask = response;
      return;
    }
    EmailProvider? p = NavService.navKey.currentContext?.read<EmailProvider>();
    if (p == null) return;
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(response.payload!);
    } catch (_) {}
    MailAccountModel? mam;
    if (payload.containsKey("accountHash")) {
      mam = MailAccountController().mailAccountModelById(payload["accountHash"]);
    }
    if (mam == null) return;
    if (p.currentMailClient != null &&
        p.currentMailClient!.isConnected &&
        (p.currentMailClient!.account.email != mam.email ||
            p.currentMailClient!.selectedMailbox?.encodedName != payload["mailbox"])) {
      if (await yesNoDialog<bool>(
              title: LocaleKeys.title_ask_switch_current.tr(),
              content: LocaleKeys.msg_aks_switch_current.tr(namedArgs: {
                'newaccount': mam.email ?? '',
                'newmailbox': payload['mailbox'] ?? '',
              }),
              retYes: false,
              retNo: true) ??
          false) {
        return;
      } else {
        NavService.navKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (context) => SlowMailApp(
              startupAccountEmail: mam!.id, // mam!.email,
            ),
          ),
          (Route<dynamic> route) => false, // ModalRoute.withName('/'),
        );
      }
    } else {
      NavService.navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => SlowMailApp(
            startupAccountEmail: mam!.id,
          ),
        ),
      );
    }
  }

  Future<bool> hasPermission() async {
    bool res = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled() ??
        false;

    isPermitted = res;

    return res;
  }

  Future<bool> requestPermission() async {
    bool res = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    isPermitted = res;

    return res;
  }

  Future<void> showMessageNotification(MimeMessage? msg, {String? title, String? payload}) async {
    StringBuffer body = StringBuffer();
    List<String> notificationAttributes = List<String>.from(
        NavService.navKey.currentContext!.read<SettingsProvider>().generalPrefs["notificationAttributes"] ?? []);
    if (notificationAttributes.isNotEmpty && msg != null) {
      if (notificationAttributes.contains("subject")) {
        body.writeln(msg.decodeSubject());
      }
      if (notificationAttributes.contains("from")) {
        body.writeln(msg.emailFullFrom());
      }
    }

    await showSimpleNotification(body.toString(), title: title, payload: payload);
  }

  Future<void> showSimpleNotification(String body, {String? title, String? payload}) async {
    await flutterLocalNotificationsPlugin.show(
        id: msgId++,
        title: title ?? LocaleKeys.title_new_message.tr(),
        body: body,
        notificationDetails: notificationDetails,
        payload: payload);
  }
}
