// ignore_for_file: dead_code

import 'package:slow_mail/utils/common_import.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cryptography/cryptography.dart';
import 'package:convert/convert.dart';
import 'package:slow_mail/oauth/google_auth_service.dart';
import 'package:slow_mail/oauth/yahoo_auth_service.dart';
import 'package:slow_mail/oauth/outlook_auth_service.dart';

class MailAccountController {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AndroidOptions _getAndroidOptions() =>
      const AndroidOptions(sharedPreferencesName: 'slow_mail', preferencesKeyPrefix: 'slow_mail');

  LinkedHashMap<String, MailAccountModel> _rawAccounts = LinkedHashMap<String, MailAccountModel>();
  // final Map<String, MailAccountModel> _rawAccounts = {};

  // Singleton init
  static final MailAccountController _singleton = MailAccountController._internal();
  factory MailAccountController() {
    return _singleton;
  }
  MailAccountController._internal();
  // Singleton init End

  Future<void> initAccounts(Map<String, dynamic> json,
      {bool removeCurrent = false, bool storeAccounts = true, bool overlayAccounts = false}) async {
    if (removeCurrent) {
      for (MailAccountModel mam in _rawAccounts.values) {
        deleteMailAccountModel(mam, isBulk: true);
      }
      for (MapEntry<String, String> secKey in (await _storage.readAll(aOptions: _getAndroidOptions())).entries) {
        if (secKey.key.startsWith("pw_incoming") || secKey.key.startsWith("pw_outgoing")) {
          await _storage.delete(key: secKey.key, aOptions: _getAndroidOptions());
        }
      }
    }

    if (overlayAccounts || removeCurrent) {
      _rawAccounts.clear();
    }

    for (MapEntry<String, dynamic> entry in json.entries) {
      // addAccount(MailAccountModel.fromJson(entry.value)..storeAccount = storeAccounts, isBulk: true);
      addAccount(MailAccountModel.fromJson(entry.value)..storeAccount = true, isBulk: true);
    }

    if (storeAccounts) {
      await storeAllAccounts();
    }

    NavService.navKey.currentContext!.read<SettingsProvider>().onMailAccounts();
  }

  Future<void> storeAllAccounts() async {
    if (NavService.navKey.currentContext!.read<SettingsProvider>().isOverlayMode) return;

    Map<String, dynamic> raw = {};
    for (MapEntry<String, MailAccountModel> item in _rawAccounts.entries) {
      if (!item.value.storeAccount) continue;
      raw[item.key] = {...item.value.baseMap()};
      raw[item.key]["incoming"]["authentication"]["password"] = '';
      raw[item.key]["outgoing"]["authentication"]["password"] = '';
    }
    await NavService.navKey.currentContext!.read<SettingsProvider>().prefs!.setString('ACCOUNTS', jsonEncode(raw));
  }

  Future<Map<String, dynamic>> getAccountsAsJson(List<String> emails, [bool includePassword = false]) async {
    Map<String, dynamic> raw = {};
    for (MapEntry<String, MailAccountModel> item in _rawAccounts.entries) {
      if (!emails.contains(item.key)) continue;

      raw[item.key] = item.value.baseMap();

      if (includePassword) {
        if (item.value.outgoingPassword.isEmpty && !item.value.outgoingAskForPassword) {
          raw[item.key]["outgoing"]["authentication"]["password"] =
              (await _storage.read(key: "pw_outgoing_${item.key}", aOptions: _getAndroidOptions())) ?? '';
        }

        if (item.value.incomingPassword.isEmpty && !item.value.incomingAskForPassword) {
          raw[item.key]["incoming"]["authentication"]["password"] =
              (await _storage.read(key: "pw_incoming_${item.key}", aOptions: _getAndroidOptions())) ?? '';
        }
      } else {
        raw[item.key]["incoming"]["authentication"]["password"] = '';
        raw[item.key]["outgoing"]["authentication"]["password"] = '';
      }
    }

    return raw;
  }

  Map<String, MailAccountModel> getMailAccountModels() {
    return _rawAccounts;
  }

  bool mailAccountModelExists(String email) {
    return _rawAccounts.containsKey(email);
  }

  Future<MailAccountModel?> mailAccountModelByEmail(String email) async {
    if (!_rawAccounts.containsKey(email)) return null;

    if (_rawAccounts[email]!.outgoingPassword.isEmpty && !_rawAccounts[email]!.outgoingAskForPassword) {
      _rawAccounts[email]!.outgoingPassword =
          (await _storage.read(key: "pw_outgoing_$email", aOptions: _getAndroidOptions())) ?? '';
    }

    if (_rawAccounts[email]!.incomingPassword.isEmpty && !_rawAccounts[email]!.incomingAskForPassword) {
      _rawAccounts[email]!.incomingPassword =
          (await _storage.read(key: "pw_incoming_$email", aOptions: _getAndroidOptions())) ?? '';
    }

    return _rawAccounts[email];
  }

  MailAccountModel? mailAccountModelById(String id) {
    try {
      return _rawAccounts.values.firstWhere((MailAccountModel mam) => mam.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<MailAccount?> mailAccountByEmail(String email) async {
    MailAccountModel? m = await mailAccountModelByEmail(email);
    if (m == null) throw MessageException("Unable to find Mailaccount");
    return await m.mailAccountWithSecrets;
  }

  void resetTemporaryPassword(String? email) {
    if (email == null || !_rawAccounts.containsKey(email)) return;
    if (_rawAccounts[email]!.outgoingAskForPassword) _rawAccounts[email]!.outgoingPassword = '';
    if (_rawAccounts[email]!.incomingAskForPassword) _rawAccounts[email]!.incomingPassword = '';
  }

  Future<void> addAccount(MailAccountModel acc, {bool isBulk = false}) async {
    await _addAccountByMap(acc.email ?? "unknown@unknown.com", acc.baseMap());
  }

  Future<void> _addAccountByMap(String key, Map<String, dynamic> mAcc, {bool isBulk = false}) async {
    MailAccountModel mAccConfig = MailAccountModel.fromJson(mAcc);

    if (!NavService.navKey.currentContext!.read<SettingsProvider>().isOverlayMode) {
      if (mAccConfig.outgoingPassword.isNotEmpty && !mAccConfig.outgoingAskForPassword) {
        await _storage.write(
            key: "pw_outgoing_$key", value: mAccConfig.outgoingPassword, aOptions: _getAndroidOptions());
      }

      if (mAccConfig.incomingPassword.isNotEmpty && !mAccConfig.incomingAskForPassword) {
        await _storage.write(
            key: "pw_incoming_$key", value: mAccConfig.incomingPassword, aOptions: _getAndroidOptions());
      }
    }

    _rawAccounts[key] = mAccConfig;
    // _rawAccounts = sortMapByValue<String, MailAccountModel>(_rawAccounts, accountModelSorting);

    if (!isBulk) {
      await storeAllAccounts();
      NavService.navKey.currentContext!.read<SettingsProvider>().onMailAccounts();
    }
  }

  Future<void> moveAccount(String emailToMove, String emailBefore) async {
    if (!_rawAccounts.containsKey(emailToMove) || !_rawAccounts.containsKey(emailBefore)) return;
    LinkedHashMap<String, MailAccountModel> temp = LinkedHashMap<String, MailAccountModel>();
    for (MapEntry<String, MailAccountModel> item in _rawAccounts.entries) {
      if (item.key == emailToMove) continue;
      if (item.key == emailBefore) {
        temp[emailToMove] = _rawAccounts[emailToMove]!;
      }
      temp.addEntries([item]);
    }
    _rawAccounts = temp;

    await storeAllAccounts();

    NavService.navKey.currentContext!.read<SettingsProvider>().onMailAccounts();
  }

  Future<void> deleteMailAccountModel(MailAccountModel mam, {bool isBulk = false}) async {
    if (mam.email == null) return;
    if (await _storage.containsKey(key: "pw_outgoing_${mam.email}", aOptions: _getAndroidOptions())) {
      await _storage.delete(key: "pw_outgoing_${mam.email}", aOptions: _getAndroidOptions());
    }
    if (await _storage.containsKey(key: "pw_incoming_${mam.email}", aOptions: _getAndroidOptions())) {
      await _storage.delete(key: "pw_incoming_${mam.email}", aOptions: _getAndroidOptions());
    }
    if (!isBulk) {
      _rawAccounts.remove(mam.email);
      storeAllAccounts();
      if (NavService.navKey.currentContext?.read<EmailProvider>().currentEmail == mam.email) {
        NavService.navKey.currentContext?.read<EmailProvider>().closeCurrentMailAccount(withNotify: true);
      }
      NavService.navKey.currentContext?.read<SettingsProvider>().onMailAccounts();
    }
  }

  Future<OauthToken?> refreshOauthToken(MailClient mc, OauthToken oldToken) async {
    switch (oldToken.provider) {
      case "google":
        return await GoogleAuthService().buildFreshOauthToken();
        break;
      case "yahoo":
        return await YahooAuthService().refresh(oldToken);
        break;
      case "outlook":
        return await OutlookAuthService().refresh(oldToken);
        break;

      default:
        return null;
        break;
    }
  }

  Map<String, MailAddress> get mailAddresses {
    return _rawAccounts.map<String, MailAddress>((key, value) {
      return MapEntry(key, MailAddress(value.name, value.email!));
      // return MapEntry(key, MailAddress((value['name'] as String).isEmpty ? null : value['name'], value['email']));
    });
  }
}

class MailAccountModel {
  final Map<String, dynamic> _baseMap = <String, dynamic>{
    "incoming": <String, dynamic>{
      "serverConfig": <String, dynamic>{"type": "imap", "authenticationAlternative": null, "usernameType": "unknown"},
      "authentication": <String, dynamic>{
        "password": "",
      },
      "serverCapabilities": [],
      "pathSeparator": "/"
    },
    "outgoing": <String, dynamic>{
      "serverConfig": <String, dynamic>{"type": "smtp", "authenticationAlternative": null, "usernameType": "unknown"},
      "authentication": <String, dynamic>{
        "password": "",
      },
      "serverCapabilities": [],
      "pathSeparator": "/"
    },
    "outgoingClientDomain": "enough.de",
    "aliases": [],
    "supportsPlusAliases": false,
    "attributes": <String, dynamic>{},
    "account_settings": <String, dynamic>{
      "outgoingAuthEqualIncoming": false,
      "incomingAskForPassword": false,
      "outgoingAskForPassword": false,
      "storeAccount": true,
    },
    "name": "",
    "userName": "",
    "email": "",
    "timeout": 20,
    "order": null,
    "id": null
  };

  MailAccountModel();
  MailAccountModel.fromSettings({
    required String name,
    required String email,
    required String incomingHost,
    required String outgoingHost,
    required String incomingPassword,
    required String incomingUserName,
    required Authentication incomingAuthType,
    String outgoingPassword = '',
    String outgoingUserName = '',
    Authentication outgoingAuthType = Authentication.plain,
    ServerType incomingType = ServerType.imap,
    ServerType outgoingType = ServerType.smtp,
    String outgoingClientDomain = 'slow_mail.de',
    int incomingPort = 993,
    int outgoingPort = 465,
    int timeout = 20,
    SocketType incomingSocketType = SocketType.ssl,
    SocketType outgoingSocketType = SocketType.ssl,
    bool supportsPlusAliases = false,
    List<MailAddress> aliases = const [],
    bool outgoingAuthEqualIncoming = false,
    bool incomingAskForPassword = false,
    bool outgoingAskForPassword = false,
  }) {
    this.userName = incomingUserName;
    this.name = name;
    this.email = email;
    this.timeout = timeout;

    this.incomingAuthentication = incomingAuthType;
    this.incomingHostname = incomingHost;
    this.incomingPort = incomingPort;
    this.incomingSocketType = incomingSocketType;
    this.incomingPassword = incomingPassword;
    this.incomingUserName = incomingUserName;

    if (outgoingAuthEqualIncoming) {
      outgoingPassword = incomingPassword;
      outgoingUserName = incomingUserName;
      outgoingAuthType = incomingAuthType;
      outgoingAskForPassword = incomingAskForPassword;
    }
    this.outgoingAuthentication = outgoingAuthType;
    this.outgoingHostname = outgoingHost;
    this.outgoingPort = outgoingPort;
    this.outgoingSocketType = outgoingSocketType;
    this.outgoingPassword = outgoingPassword;
    this.outgoingUserName = outgoingUserName;

    _baseMap['outgoingClientDomain'] = outgoingClientDomain;

    this.outgoingAuthEqualIncoming = outgoingAuthEqualIncoming;
    this.incomingAskForPassword = incomingAskForPassword;
    this.outgoingAskForPassword = outgoingAskForPassword;

    postCreate();
    generateId();
  }

  MailAccountModel.fromJson(Map<String, dynamic> json) {
    _baseMap.addAll(json);

    //prevent name equals email => higher spam level on email send
    if (name == email && email != null) {
      name = email!.replaceAll("@", " ");
    }

    if (!json.containsKey("account_settings") ||
        !(json["account_settings"] as Map<String, dynamic>).containsKey("outgoingAuthEqualIncoming")) {
      outgoingAuthEqualIncoming = (outgoingPassword == incomingPassword &&
          outgoingUserName == incomingUserName &&
          outgoingAuthentication == incomingAuthentication &&
          outgoingAskForPassword == incomingAskForPassword);
    }
    postCreate();
    generateId();
  }

  void postCreate() {
    if (incomingUserName.isNullOrEmpty()) incomingUserName = email;
    if (outgoingUserName.isNullOrEmpty()) outgoingUserName = email;

    if (incomingAuthentication == Authentication.oauth2) {
      if (_baseMap["incoming"]["authentication"]["password"] != null) {
        (_baseMap["incoming"]["authentication"] as Map).remove("password");
      }
    }

    if (outgoingAuthentication == Authentication.oauth2) {
      if (_baseMap["outgoing"]["authentication"]["password"] != null) {
        (_baseMap["outgoing"]["authentication"] as Map).remove("password");
      }
    }
  }

  void delete() {
    _baseMap.clear();
  }

  Map<String, dynamic> baseMap() {
    return {..._baseMap};
  }

  void generateId() {
    if (id == null) {
      final bytes = utf8.encode(jsonEncode(<String, dynamic>{
        "email": email,
        "incomingHostname": incomingHostname,
        "incomingPort": incomingPort,
      }));
      final digest = Sha256().toSync().hashSync(bytes);
      id = hex.encode(digest.bytes);
    }
  }

  String? get id => _baseMap["id"];
  set id(String? arg) => _baseMap["id"] = arg;

  String? get email => _baseMap["email"];
  set email(String? arg) => _baseMap["email"] = arg;

  int? get timeout => _baseMap["timeout"] ?? 20;
  set timeout(int? arg) => _baseMap["timeout"] = arg;

  int? get order => _baseMap["order"];
  set order(int? arg) => _baseMap["order"] = arg;

  String? get name => _baseMap["name"];
  set name(String? arg) => _baseMap["name"] = arg;

  String? get incomingHostname => _baseMap["incoming"]["serverConfig"]["hostname"];
  set incomingHostname(String? arg) => _baseMap["incoming"]["serverConfig"]["hostname"] = arg;

  String? get outgoingHostname => _baseMap["outgoing"]["serverConfig"]["hostname"];
  set outgoingHostname(String? arg) => _baseMap["outgoing"]["serverConfig"]["hostname"] = arg;

  int? get incomingPort => _baseMap["incoming"]["serverConfig"]["port"];
  set incomingPort(int? arg) {
    _baseMap["incoming"]["serverConfig"]["port"] = arg;
  }

  int? get outgoingPort => _baseMap["outgoing"]["serverConfig"]["port"];
  set outgoingPort(int? arg) {
    _baseMap["outgoing"]["serverConfig"]["port"] = arg;
  }

  SocketType? get incomingSocketType => SocketType.values.byName(_baseMap["incoming"]["serverConfig"]["socketType"]);
  set incomingSocketType(SocketType? arg) => _baseMap["incoming"]["serverConfig"]["socketType"] = arg?.name ?? '';

  SocketType? get outgoingSocketType => SocketType.values.byName(_baseMap["outgoing"]["serverConfig"]["socketType"]);
  set outgoingSocketType(SocketType? arg) => _baseMap["outgoing"]["serverConfig"]["socketType"] = arg?.name ?? '';

  set incomingServer(Map<String, dynamic> conf) =>
      (_baseMap["incoming"]["serverConfig"] as Map<String, dynamic>).addAll(conf);
  set outgoingServer(Map<String, dynamic> conf) =>
      (_baseMap["outgoing"]["serverConfig"] as Map<String, dynamic>).addAll(conf);

  String get incomingPassword => _baseMap["incoming"]["authentication"]["password"] ?? '';
  set incomingPassword(String arg) => _baseMap["incoming"]["authentication"]["password"] = arg;

  String get outgoingPassword => _baseMap["outgoing"]["authentication"]["password"] ?? '';
  set outgoingPassword(String arg) => _baseMap["outgoing"]["authentication"]["password"] = arg;

  String? get incomingUserName => _baseMap["incoming"]["authentication"]["userName"];
  set incomingUserName(String? arg) {
    _baseMap["incoming"]["authentication"]["userName"] = arg;
    if (_baseMap.containsKey("userName") || _baseMap["userName"] == null || (_baseMap["userName"] as String).isEmpty) {
      _baseMap["userName"] = arg;
    }
  }

  String? get outgoingUserName => _baseMap["outgoing"]["authentication"]["userName"];
  set outgoingUserName(String? arg) => _baseMap["outgoing"]["authentication"]["userName"] = arg;

  Authentication? get incomingAuthentication =>
      Authentication.values.byName(_baseMap["incoming"]["serverConfig"]["authentication"]);
  set incomingAuthentication(Authentication? arg) {
    _baseMap["incoming"]["serverConfig"]["authentication"] = arg?.name ?? '';
    _baseMap["incoming"]["authentication"]["typeName"] = (arg == Authentication.oauth2) ? 'oauth2' : 'plain';
  }

  Map<String, dynamic>? get incomingAuthenticationToken => _baseMap["incoming"]["authentication"]["token"];
  set incomingAuthenticationToken(Map<String, dynamic>? token) =>
      _baseMap["incoming"]["authentication"]["token"] = token;

  Authentication? get outgoingAuthentication =>
      Authentication.values.byName(_baseMap["outgoing"]["serverConfig"]["authentication"]);
  set outgoingAuthentication(Authentication? arg) {
    _baseMap["outgoing"]["serverConfig"]["authentication"] = arg?.name ?? '';
    _baseMap["outgoing"]["authentication"]["typeName"] = (arg == Authentication.oauth2) ? 'oauth2' : 'plain';
  }

  Map<String, dynamic>? get outgoingAuthenticationToken => _baseMap["outgoing"]["authentication"]["token"];
  set outgoingAuthenticationToken(Map<String, dynamic>? token) =>
      _baseMap["outgoing"]["authentication"]["token"] = token;

  String get userName => _baseMap["userName"];
  set userName(String? arg) {
    _baseMap["userName"] = arg;
    // baseMap["incoming"]["authentication"]["userName"] = arg;
    // baseMap["outgoing"]["authentication"]["userName"] = arg;
  }

  bool get outgoingAuthEqualIncoming => _baseMap["account_settings"]["outgoingAuthEqualIncoming"];
  set outgoingAuthEqualIncoming(bool arg) => _baseMap["account_settings"]["outgoingAuthEqualIncoming"] = arg;

  bool get incomingAskForPassword => _baseMap["account_settings"]["incomingAskForPassword"];
  set incomingAskForPassword(bool arg) => _baseMap["account_settings"]["incomingAskForPassword"] = arg;

  bool get outgoingAskForPassword => _baseMap["account_settings"]["outgoingAskForPassword"];
  set outgoingAskForPassword(bool arg) => _baseMap["account_settings"]["outgoingAskForPassword"] = arg;

  bool get storeAccount => _baseMap["account_settings"]["storeAccount"];
  set storeAccount(bool arg) => _baseMap["account_settings"]["storeAccount"] = arg;

  MailAccount get mailAccount {
    return MailAccount.fromJson(_baseMap);
  }

  Future<MailAccount> get mailAccountWithSecrets async {
    bool incomingTokenRetrieved = false;
    if (incomingAuthentication == Authentication.oauth2) {
      incomingAuthenticationToken = await getOauthToken();
      incomingTokenRetrieved = true;
    }
    if (outgoingAuthentication == Authentication.oauth2) {
      outgoingAuthenticationToken = (incomingTokenRetrieved) ? incomingAuthenticationToken : await getOauthToken();
    }

    bool askIncoming = ((incomingAuthentication == Authentication.passwordClearText ||
            incomingAuthentication == Authentication.passwordEncrypted) &&
        (incomingAskForPassword && incomingPassword.isEmpty));
    bool askOutgoing = ((outgoingAuthentication == Authentication.passwordClearText ||
            outgoingAuthentication == Authentication.passwordEncrypted) &&
        (outgoingAskForPassword && outgoingPassword.isEmpty));
    (outgoingAskForPassword && outgoingPassword.isEmpty);
    if (askIncoming || askOutgoing) {
      Map<String, String>? askPasswords;

      askPasswords = await passwordDialog(
          mainTitle: LocaleKeys.title_ask_account_password.tr(), askIncoming: askIncoming, askOutgoing: askOutgoing);

      if (askPasswords == null) throw MessageException(LocaleKeys.err_import_cancelled.tr());

      if (outgoingAskForPassword) outgoingPassword = askPasswords["outgoing"]!;
      if (incomingAskForPassword) incomingPassword = askPasswords["incoming"]!;
    }

    return MailAccount.fromJson(_baseMap);
  }

  Future<Map<String, dynamic>?> getOauthToken() async {
    if (incomingHostname?.endsWith("gmail.com") ?? false) {
      return await getGmailToken();
    }
    if (incomingHostname?.contains("yahoo") ?? false) {
      return await getYahooToken();
    }
    if ((incomingHostname?.contains("outlook") ?? false) || (incomingHostname?.contains("hotmail") ?? false)) {
      return await getOutlookToken();
    }

    return await getGmailToken();
  }

  Future<Map<String, dynamic>?> getOutlookToken() async {
    return (await OutlookAuthService().signIn())?.toJson();
  }

  Future<Map<String, dynamic>?> getYahooToken() async {
    return (await YahooAuthService().signIn())?.toJson();
  }

  Future<Map<String, dynamic>?> getGmailToken() async {
    if (GoogleAuthService().isInitialized &&
        GoogleAuthService().account != null &&
        GoogleAuthService().account!.email != email) {
      await GoogleAuthService().signOut();
    }
    return (await GoogleAuthService().buildFreshOauthToken())?.toJson();
  }

  @override
  String toString() {
    return _baseMap.toString();
  }
}
