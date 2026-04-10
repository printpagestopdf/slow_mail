import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui';
import 'package:enough_mail/enough_mail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

const String _channelId = "slowmail_new_message";
const String _channelName = "New Message (Background)";
const String _channelDescription = "Notification of new emails via slowmail";

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

extension MimeMessageExt on MimeMessage {
  String emailFullFrom() {
    if (envelope?.sender != null) return envelope!.sender.toString();
    if (sender != null) return sender.toString();
    if (decodeSender().isNotEmpty) return decodeSender().first.toString();
    if (from != null && from!.isNotEmpty) return from!.first.toString();

    return "UnknownFrom <unknown@noreply.com";
  }
}

Future<void> initNotifications() async {
  InitializationSettings initializationSettings =
      InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_notify'));
  try {
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: null,
      onDidReceiveBackgroundNotificationResponse: null,
    );
  } catch (_) {}
}

// 2. Die eigentliche Task (MUST BE TOP-LEVEL)
@pragma('vm:entry-point')
void callbackDispatcher() {
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/workmanager_log.txt');
    await file.writeAsString('===================================================\nTask started: ${DateTime.now()}\n',
        mode: FileMode.append);
    if (inputData == null || !inputData.containsKey("mailAccount") || !inputData.containsKey("accountHash")) {
      // await file.writeAsString('Exiting missing inputData\n', mode: FileMode.append);
      return Future.value(false);
    }

    MailClient? currentMailClient;
    try {
      final asyncPrefs = SharedPreferencesAsync();
      if (!await asyncPrefs.containsKey("recent_${inputData['accountHash']}")) {
        await asyncPrefs.setInt("recent_${inputData['accountHash']}", DateTime.now().millisecondsSinceEpoch);
        // await file.writeAsString('Exiting could not find PrefKey recent_${inputData['accountHash']}\n',
        //     mode: FileMode.append);
        return Future.value(true);
      }

      int? millisec = await asyncPrefs.getInt("recent_${inputData['accountHash']}");
      if (millisec == null) {
        // await file.writeAsString('Exiting null on millise of Prefs\n', mode: FileMode.append);
        return Future.value(true);
      }

      DateTime recent = DateTime.fromMillisecondsSinceEpoch(millisec);
      currentMailClient = MailClient(MailAccount.fromJson(jsonDecode(inputData["mailAccount"])), isLogEnabled: false);
      await currentMailClient.connect();
      await currentMailClient.selectInbox();
      // await file.writeAsString(
      //     'Connection: ${currentMailClient.isConnected} Mailbox: ${currentMailClient.selectedMailbox?.encodedName}\n',
      //     mode: FileMode.append);

      String dateSince = DateCodec.encodeSearchDate(recent);
      // await file.writeAsString('dateSince $dateSince\n', mode: FileMode.append);

      SearchImapResult res = await (currentMailClient.lowLevelIncomingMailClient as ImapClient)
          .uidSearchMessages(searchCriteria: "SINCE $dateSince UNDELETED");
      if (res.matchingSequence == null || (res.matchingSequence?.isEmpty ?? true)) {
        return Future.value(true);
      }
      FetchImapResult msgs = await (currentMailClient.lowLevelIncomingMailClient as ImapClient).uidFetchMessages(
        res.matchingSequence!,
        '(RFC822.HEADER)',
      );

      MimeMessage lastMsg = msgs.messages.reduce((msg1, msg2) {
        return msg1.decodeDate()!.millisecondsSinceEpoch > msg2.decodeDate()!.millisecondsSinceEpoch ? msg1 : msg2;
      });

      if (lastMsg.decodeDate()!.millisecondsSinceEpoch > recent.millisecondsSinceEpoch) {
        StringBuffer body = StringBuffer();
        List<String> notificationAttributes = List<String>.from(inputData["notificationAttributes"] ?? []);
        if (notificationAttributes.isNotEmpty) {
          for (MimeMessage msg in msgs.messages) {
            if ((msg.decodeDate()?.microsecondsSinceEpoch ?? 0) > recent.microsecondsSinceEpoch) {
              if (notificationAttributes.contains("subject")) {
                body.writeln(msg.decodeSubject());
              }
              if (notificationAttributes.contains("from")) {
                body.writeln(msg.emailFullFrom());
              }
            }
          }
        }

        await initNotifications();

        Map<String, dynamic> payload = {
          "accountHash": inputData["accountHash"],
          "mailbox": currentMailClient.selectedMailbox?.encodedName,
        };
        try {
          await showSimpleNotification(
              title: inputData.containsKey('title') ? inputData["title"] : "New Email Message",
              body: body.toString(),
              payload: jsonEncode(payload));
        } catch (_) {}
        await asyncPrefs.setInt("recent_${inputData['accountHash']}", lastMsg.decodeDate()!.millisecondsSinceEpoch);
      }
    } catch (e) {
      await file.writeAsString('Exception: $e\n', mode: FileMode.append);
      return Future.value(false);
    } finally {
      await file.writeAsString('Finished background task\n', mode: FileMode.append);
      currentMailClient?.disconnect();
    }

    return Future.value(true); // Return true = Erfolg, false = Retry
  });
}

Future<void> showSimpleNotification({String? body, String? title, String? payload}) async {
  AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(_channelId, _channelName,
      channelDescription: _channelDescription,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker');
  NotificationDetails notificationDetails = NotificationDetails(android: androidNotificationDetails);
  await flutterLocalNotificationsPlugin.show(
      id: Random().nextInt(2147483647), // DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload);
}
