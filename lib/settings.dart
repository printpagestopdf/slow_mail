import 'package:flutter/foundation.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'dart:core';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:share_handler/share_handler.dart';
import 'package:slow_mail/config_crypt.dart';
import 'package:slow_mail/pgp/pgp_email.dart';
import 'package:slow_mail/utils/android_notifyer.dart';
import 'package:openpgp/openpgp.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/utils/common_import.dart';
import 'package:workmanager/workmanager.dart';

int mobileWidth = 600;

//late AppSettings prefs;

class SettingsProvider extends ChangeNotifier {
  final Set<String> allowedPrefs = {'isPrefsInit', 'GENERAL', 'ACCOUNTS', 'PGP'};
  String? startupAccount;
  SharedPreferencesWithCache? prefs;
  bool _isOverlayMode = false;

  Map<String, dynamic> sessionpMap = {};

  Set<String> emailSuggestions = <String>{};

  //AppSettings? appSettings;
  bool settingsInitialized = false;

  Map<String, dynamic> generalPrefs = {};

  SharedMedia? media;

  final handler = ShareHandlerPlatform.instance;
  Map<String, dynamic>? notifyerArgs;

  SettingsProvider(this.notifyerArgs) {
    initAppSettings().then((_) => notifyListeners());
  }

  bool get isOverlayMode {
    return _isOverlayMode;
  }

  set isOverlayMode(bool isOverlay) {
    if (isOverlay == _isOverlayMode) return;
    _isOverlayMode = isOverlay;
    notifyListeners();
  }

  double _fontScale = 1.0;
  double get fontScale {
    return _fontScale.clamp(1.0, 2.5);
  }

  set fontScale(double value) {
    if (value != _fontScale) {
      _fontScale = value.clamp(1.0, 2.5);
      generalPrefs["tableFontScale"] = value;
      notifyListeners();
    }
  }

  Future<void> initAppSettings() async {
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(allowList: allowedPrefs),
    );

    await updateConfiguration(null, removeCurrent: false, storeAccounts: false, overlayAccounts: false);

    _fontScale = generalPrefs["tableFontScale"] ?? 1.0;

    if (generalPrefs["permanentNotificationAccount"] != null || (generalPrefs["currentNotificationEnabled"] ?? false)) {
      await AndroidNotifyer().initialize();
    }

    //await MailAccountController().initAccounts(null);

    emailSuggestions
        .addAll([...PgpEmail.getInstance().publicEmailKeyMap.keys, ...PgpEmail.getInstance().privateEmailKeyMap.keys]);

    // await initializeDateFormatting('de', null);

    settingsInitialized = true;

    await initSharing();

    if (notifyerArgs?.containsKey("accountHash") ?? false) {
      await openAccountOnInit(notifyerArgs!["accountHash"]);
    }

    await initWorkmanager();
  }

  Future<void> updateConfiguration(String? jsonStr,
      {required bool? removeCurrent, required bool? storeAccounts, required bool? overlayAccounts}) async {
    Map<String, dynamic> jConfiguration;

    if (jsonStr == null) {
      jConfiguration = await loadConfiguartionFromStorage();
    } else {
      (
        jConfiguration: jConfiguration,
        removeCurrent: removeCurrent,
        storeAccounts: storeAccounts,
        overlayAccounts: overlayAccounts,
      ) = await unpackJsonConfiguration(jsonStr,
          removeCurrent: removeCurrent, storeAccounts: storeAccounts, overlayAccounts: overlayAccounts);
    }

    isOverlayMode = overlayAccounts ?? false;

    if (jConfiguration.containsKey("GENERAL")) {
      setupGeneralConfiguration(jConfiguration["GENERAL"],
          removeCurrent: removeCurrent, storeAccounts: storeAccounts, overlayAccounts: overlayAccounts);
    }

    if (jConfiguration.containsKey("ACCOUNTS")) {
      await MailAccountController().initAccounts(jConfiguration["ACCOUNTS"],
          storeAccounts: storeAccounts ?? false,
          removeCurrent: removeCurrent ?? false,
          overlayAccounts: overlayAccounts ?? false);
    }

    if (jConfiguration.containsKey("PGP")) {
      await PgpEmail.getInstance().initKeysFromJson(jConfiguration["PGP"],
          removeCurrent: removeCurrent ?? false,
          storeAccounts: storeAccounts ?? false,
          overlayAccounts: overlayAccounts ?? false);
    }

    isOverlayMode = overlayAccounts ?? false;
  }

  void setupGeneralConfiguration(Map<String, dynamic> json,
      {required bool? removeCurrent, required bool? storeAccounts, required bool? overlayAccounts}) {
    generalPrefs = json;
    if (storeAccounts ?? false) {
      prefs!.setString("GENERAL", jsonEncode(json));
    }
  }

  Future<Map<String, dynamic>> exportConfiguration(List<String> emails,
      {bool encrypted = true, String password = "", bool includePGP = true}) async {
    Map<String, dynamic> payload = <String, dynamic>{};

    if (includePGP && PgpEmail.getInstance().hasPGP) {
      payload["PGP"] = PgpEmail.getInstance().getKeysAsJson();
    }

    payload["ACCOUNTS"] = await MailAccountController().getAccountsAsJson(emails, true);

    payload["GENERAL"] = generalPrefs;

    if (encrypted) {
      ConfigCrypt crypt = ConfigCrypt();
      payload = await crypt.encryptText(
        password: password,
        plaintext: jsonEncode(payload),
      );
    }

    return <String, dynamic>{
      "encrypted": encrypted,
      "type": SlowMailVersion.exportFileType,
      "version": SlowMailVersion.exporFileVersion,
      "payload": payload,
    };
  }

  Future<({Map<String, dynamic> jConfiguration, bool? removeCurrent, bool? storeAccounts, bool? overlayAccounts})>
      unpackJsonConfiguration(String jsonStr,
          {required bool? removeCurrent, required bool? storeAccounts, required bool? overlayAccounts}) async {
    Map<String, dynamic> rawFile = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (!rawFile.containsKey("type") ||
        rawFile["type"] != SlowMailVersion.exportFileType ||
        !rawFile.containsKey("version") ||
        !rawFile.containsKey("payload") ||
        !rawFile.containsKey("encrypted")) {
      throw Exception("Wrong Filetype");
    }

    bool askImportType = removeCurrent == null || storeAccounts == null || overlayAccounts == null;
    Map<String, String>? askPasswords;
    if (rawFile["encrypted"] || askImportType) {
      askPasswords = await passwordDialog(
          askIncoming: rawFile["encrypted"],
          askOutgoing: false,
          askImportType: askImportType,
          mainTitle: LocaleKeys.title_encrypted_file.tr(),
          incomingTitle: LocaleKeys.password.tr());
      if (askPasswords == null) {
        throw Exception(LocaleKeys.err_import_cancelled.tr());
      }
    }

    if (askImportType) {
      switch (askPasswords?["importType"]) {
        case "optImportOverwrite":
          removeCurrent = true;
          storeAccounts = true;
          overlayAccounts = false;
          break;
        case "optImportMerge":
          removeCurrent = false;
          storeAccounts = true;
          overlayAccounts = false;
          break;
        case "optImportOverlay":
          removeCurrent = false;
          storeAccounts = false;
          overlayAccounts = true;
          break;
        default:
          throw Exception("Importtype not supported");
          break;
      }
    }

    Map<String, dynamic> jConfiguration;
    if (rawFile["encrypted"]) {
      ConfigCrypt crypt = ConfigCrypt();
      try {
        String? jsonStr =
            await crypt.decryptText(password: askPasswords!["incoming"]!, encryptedData: rawFile["payload"]);
        jConfiguration = jsonDecode(jsonStr) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(LocaleKeys.err_unable_to_decrypt.tr());
      }
    } else {
      jConfiguration = rawFile["payload"];
    }

    return (
      jConfiguration: jConfiguration,
      removeCurrent: removeCurrent,
      storeAccounts: storeAccounts,
      overlayAccounts: overlayAccounts,
    );
  }

  Future<Map<String, dynamic>> loadConfiguartionFromStorage() async {
    if (prefs == null) throw Exception("Preferences not initialized!");
    Map<String, dynamic> retVal = {};
    String? jStr;
    if (prefs!.containsKey('ACCOUNTS') && ((jStr = prefs!.getString('ACCOUNTS')) != null)) {
      retVal["ACCOUNTS"] = jsonDecode(jStr!);
    }

    if (prefs!.containsKey('GENERAL') && ((jStr = prefs!.getString('GENERAL')) != null)) {
      retVal["GENERAL"] = jsonDecode(jStr!);
    }

    if (prefs!.containsKey('PGP') && ((jStr = prefs!.getString('PGP')) != null)) {
      retVal["PGP"] = <String, dynamic>{
        "PublicKeys": jsonDecode(jStr!),
      };
    }
    return retVal;
  }

  Future<void> clearConfigurationOnStorage(List<String> sections) async {
    if (prefs == null) throw Exception("Preferences not initialized!");

    for (String section in sections) {
      if (prefs!.containsKey(section)) {
        prefs!.remove(section);
      }
    }
  }

  Future<void> initWorkmanager() async {
    await Workmanager().cancelAll();

    if (generalPrefs["permanentNotificationAccount"] != null &&
        MailAccountController().mailAccountModelExists(generalPrefs["permanentNotificationAccount"])) {
      MailAccountModel mam =
          (await MailAccountController().mailAccountModelByEmail(generalPrefs["permanentNotificationAccount"]))!;
      if (mam.incomingAskForPassword || mam.incomingAuthentication == Authentication.oauth2) return;
      await Workmanager().registerPeriodicTask(
        "slowmail-check-task", // Unique Name
        "newEmailCheck", // Task Type
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected, // Nur wenn Internet da ist
        ),
        inputData: {
          "mailAccount": jsonEncode(mam.mailAccount.toJson()),
          "accountHash": mam.id,
          "title": LocaleKeys.title_new_message.tr(),
          "notificationAttributes": generalPrefs["notificationAttributes"] ?? [],
        },
      );
    }
  }

  void saveGeneralPrefs() {
    if (prefs != null) {
      prefs!.setString("GENERAL", jsonEncode(generalPrefs));
    }
  }

  Future<void> openAccountOnInit(String accountId) async {
    MailAccountModel? mam = MailAccountController().mailAccountModelById(accountId);
    if (mam == null || mam.email == null) return;
    await NavService.navKey.currentContext!.read<EmailProvider>().initMailAccount(mam.email!, openInbox: true);

    //Workaround for not recognizing network after external init
    if (!NavService.navKey.currentContext!.read<ConnectionProvider>().netAvailable) {
      NavService.navKey.currentContext!.read<ConnectionProvider>().enableNetIfConnected();
    }
  }

  Future<void> initSharing() async {
    // final handler = ShareHandlerPlatform.instance;
    media = await handler.getInitialSharedMedia();
    if (media != null) await accountsFromSharing(media!);

    handler.sharedMediaStream.listen((SharedMedia media) async {
      await accountsFromSharing(media);
    });
  }

  Future<void> accountsFromSharing(SharedMedia media) async {
    if (media.attachments != null && media.attachments!.isNotEmpty) {
      try {
        settingsInitialized = false;
        notifyListeners();

        File f = File(media.attachments![0]!.path);
        String json = await f.readAsString();
        // await MailAccountController()
        //     .importAccounts(json, removeCurrent: null, storeAccounts: null, overlayAccounts: null);
        await updateConfiguration(json, removeCurrent: null, storeAccounts: null, overlayAccounts: null);

        settingsInitialized = true;
        notifyListeners();
        succesMessage(LocaleKeys.success_import.tr());
      } catch (e) {
        errorMessage(e.toString());
      }
    }
  }

  void onMailAccounts() {
    notifyListeners();
  }
}
