import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:slow_mail/utils/globals.dart';
import 'package:slow_mail/settings.dart';
import 'package:slow_mail/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as secstore;

import 'dart:convert';

class PgpEmail {
  static PgpEmail? _instance;
  String? html;
  String? jsResult;
  final secstore.FlutterSecureStorage _storage;
  final secstore.AndroidOptions _androidOptions;

  Map<String, Map<String, dynamic>> privateKeyList = {};
  Map<String, String> privateKeyMap = {};
  Map<String, String> privateEmailKeyMap = {};

  Map<String, Map<String, dynamic>> publicKeyList = {};
  Map<String, String> publicEmailKeyMap = {};

  InAppWebViewController? wvController;
  bool _isWebViewRunning = false;

  final InAppWebViewSettings settings = InAppWebViewSettings(
    javaScriptEnabled: true,
    transparentBackground: true,
    disableContextMenu: true,
    safeBrowsingEnabled: true,
    saveFormData: false,
    thirdPartyCookiesEnabled: false,
    cacheEnabled: false,
    databaseEnabled: false,
    domStorageEnabled: false,
    geolocationEnabled: false,
    isElementFullscreenEnabled: false,
    isFindInteractionEnabled: false,
    incognito: true,
    javaScriptCanOpenWindowsAutomatically: false,
    supportZoom: false,
  );

  bool get hasPGP {
    return (publicKeyList.isNotEmpty || privateKeyList.isNotEmpty);
  }

  void clearPGP() {
    privateKeyList.clear();
    privateKeyMap.clear();
    privateEmailKeyMap.clear();
    publicKeyList.clear();
    publicEmailKeyMap.clear();
    NavService.navKey.currentContext!.read<SettingsProvider>().sessionpMap.clear();
  }

  Future<bool> initKeysFromJson(Map<String, dynamic> pgpMap,
      {bool removeCurrent = false, bool storeAccounts = true, bool overlayAccounts = false}) async {
    if (removeCurrent) {
      clearPGP();
      await NavService.navKey.currentContext!.read<SettingsProvider>().prefs?.remove('PGP');
      await _storage.delete(key: "PGP", aOptions: _androidOptions);
    }

    if (overlayAccounts) {
      clearPGP();
    }

    publicKeyList.clear();
    for (MapEntry<String, dynamic> key in pgpMap["PublicKeys"].entries) {
      publicKeyList[key.key] = key.value;
    }

    publicEmailKeyMap.clear();
    for (MapEntry<String, Map<String, dynamic>> key in publicKeyList.entries) {
      if (publicKeyList[key.key] == null) continue;
      if (publicKeyList[key.key]!.containsKey('identities') && (publicKeyList[key.key]?['identities'] is List)) {
        for (dynamic identity in publicKeyList[key.key]?['identities']) {
          if (identity.containsKey("email")) {
            publicEmailKeyMap[identity["email"]!] = key.key;
          }
        }
      }
    }

    if (!pgpMap.containsKey("PrivateKeys") && (await _storage.containsKey(key: "PGP", aOptions: _androidOptions))) {
      String? jStr = await _storage.read(key: "PGP", aOptions: _androidOptions);
      if (jStr != null) {
        pgpMap["PrivateKeys"] = jsonDecode(jStr);
      } else {
        pgpMap["PrivateKeys"] = <String, dynamic>{};
      }
    }
    privateKeyList.clear();
    for (MapEntry<String, dynamic> key in pgpMap["PrivateKeys"].entries) {
      privateKeyList[key.key] = key.value;
    }

    privateKeyMap.clear();
    privateEmailKeyMap.clear();
    for (MapEntry<String, Map<String, dynamic>> key in PgpEmail.getInstance().privateKeyList.entries) {
      if (privateKeyList[key.key] == null) continue;
      if (privateKeyList[key.key]!.containsKey('keyIds') && (privateKeyList[key.key]?['keyIds'] is List)) {
        for (String? subKey in privateKeyList[key.key]?['keyIds']) {
          if (subKey != null) {
            privateKeyMap[subKey] = key.key;
          }
        }
      } else {
        privateKeyMap[key.key] = key.key;
      }

      if (privateKeyList[key.key]!.containsKey('identities') && (privateKeyList[key.key]?['identities'] is List)) {
        for (dynamic identity in privateKeyList[key.key]?['identities']) {
          if (identity.containsKey("email")) {
            privateEmailKeyMap[identity["email"]!] = key.key;
          }
        }
      }
    }

    if (storeAccounts && !overlayAccounts) {
      await storeKeys();
    }
    return true;
  }

  Map<String, dynamic> getKeysAsJson() {
    return <String, dynamic>{
      "PublicKeys": publicKeyList,
      "PrivateKeys": privateKeyList,
    };
  }

  Future<void> storeKeys({bool privateKeys = true, bool publicKeys = true}) async {
    if (NavService.navKey.currentContext?.read<SettingsProvider>().isOverlayMode ?? false) return;
    Map<String, dynamic> allKeys = getKeysAsJson();
    if (publicKeys) {
      await NavService.navKey.currentContext!
          .read<SettingsProvider>()
          .prefs!
          .setString('PGP', jsonEncode(allKeys["PublicKeys"]));
    }
    if (privateKeys) {
      await _storage.write(key: "PGP", value: jsonEncode(allKeys["PrivateKeys"]), aOptions: _androidOptions);
    }
  }

  Future<void> addPrivateKey(String privateKeyData, String privateKeyPassword) async {
    if (privateKeyData.isEmpty) throw MessageException("Key must not be empty");
    if (privateKeyPassword.isNotEmpty) {
      isPassphraseOk(privateKeyData, privateKeyPassword);
    }

    Map<String, dynamic>? keyMetaJS = await getPrivateKeyMetadataJS(privateKeyData);
    if (keyMetaJS == null || keyMetaJS["keyId"] == null) throw MessageException("Unable to get Key Metadata");

    List<Map<dynamic, dynamic>> identities = [];
    for (String userId in keyMetaJS["userIds"]) {
      try {
        MailAddress adr = MailAddress.parse(userId);
        identities.add({"id": userId, "name": adr.personalName ?? "", "comment": "", "email": adr.email});
      } catch (_) {}
    }

    String mainKey = keyMetaJS["keyId"];
    publicKeyList[mainKey] = {
      "keyIds": keyMetaJS["keyIds"],
      "identities": identities,
      "creationTime": keyMetaJS["creationTime"],
      "fingerprint": hexStringToByteString(keyMetaJS["fingerprint"]),
      "keyId": mainKey,
      "canSign": keyMetaJS["canSign"],
      "canEncrypt": keyMetaJS["canEncrypt"],
      "armoredKey": privateKeyData,
      "privateKeyPassword": privateKeyPassword,
    };

    // PrivateKeyMetadata keyMeta = await getPrivateKeyMetadata(privateKeyData);
    // List<String>? keyIds = await getKeyId(privateKeyData);
    // List<Map<dynamic, dynamic>> identities = [];
    // for (Identity id in keyMeta.identities) {
    //   identities.add(id.toJson());
    // }

    // String mainKey = keyMeta.keyId.toLowerCase();
    // privateKeyList[mainKey] = {
    //   "keyIds": keyIds,
    //   "identities": identities,
    //   "creationTime": keyMeta.creationTime,
    //   "fingerprint": keyMeta.fingerprint,
    //   "keyId": keyMeta.keyId.toLowerCase(),
    //   "canSign": keyMeta.canSign,
    //   "encrypted": keyMeta.encrypted,
    //   "armoredKey": privateKeyData,
    //   "privateKeyPassword": privateKeyPassword,
    // };

    if (privateKeyList[mainKey]!.containsKey('keyIds') && (privateKeyList[mainKey]?['keyIds'] is List)) {
      for (String? subKey in privateKeyList[mainKey]?['keyIds']) {
        if (subKey != null) {
          privateKeyMap[subKey] = mainKey;
        }
      }
    } else {
      privateKeyMap[mainKey] = mainKey;
    }

    if (privateKeyList[mainKey]!.containsKey('identities') && (privateKeyList[mainKey]?['identities'] is List)) {
      for (dynamic identity in privateKeyList[mainKey]?['identities']) {
        if (identity.containsKey("email")) {
          privateEmailKeyMap[identity["email"]!] = mainKey;
        }
      }
    }

    await storeKeys(publicKeys: false);
  }

  Future<void> deletePrivateKey(String keyId) async {
    privateKeyList.remove(keyId);
    privateKeyMap.removeWhere((String subkey, String key) => key == keyId);
    privateEmailKeyMap.removeWhere((String email, String key) => key == keyId);

    await storeKeys(publicKeys: false);
  }

  Future<void> deletePublicKey(String keyId) async {
    publicKeyList.remove(keyId);
    publicEmailKeyMap.removeWhere((String email, String key) => key == keyId);

    await storeKeys(privateKeys: false);
  }

  Future<void> addPublicKey(String publicKeyData) async {
    if (publicKeyData.isEmpty) throw MessageException("Key must not be empty");
    Map<String, dynamic>? keyMetaJS = await getPublicKeyMetadataJS(publicKeyData);
    if (keyMetaJS == null || keyMetaJS["keyId"] == null) throw MessageException("Unable to get Key Metadata");

    List<Map<dynamic, dynamic>> identities = [];
    for (String userId in keyMetaJS["userIds"]) {
      try {
        MailAddress adr = MailAddress.parse(userId);
        identities.add({"id": userId, "name": adr.personalName ?? "", "comment": "", "email": adr.email});
      } catch (_) {}
    }

    String mainKey = keyMetaJS["keyId"];
    publicKeyList[mainKey] = {
      "keyIds": keyMetaJS["keyIds"],
      "identities": identities,
      "creationTime": keyMetaJS["creationTime"],
      "fingerprint": hexStringToByteString(keyMetaJS["fingerprint"]),
      "keyId": mainKey,
      "canSign": keyMetaJS["canSign"],
      "canEncrypt": keyMetaJS["canEncrypt"],
      "armoredKey": publicKeyData,
    };

    // List<String>? keyIds = await getPublicKeyId(publicKeyData);
    // if (keyIds == null || keyIds.isEmpty) throw MessageException("Unable to get Key Id (error in key data?)");
    // AppLogger.log(keyIds);

    // PublicKeyMetadata keyMeta = await getPublicKeyMetadata(publicKeyData);
    // // List<Map<dynamic, dynamic>> identities = [];
    // for (Identity id in keyMeta.identities) {
    //   identities.add(id.toJson());
    // }
    // AppLogger.log(keyMeta);

    // String mainKey = keyMeta.keyId.toLowerCase();

    // publicKeyList[mainKey] = {
    //   "keyIds": keyIds,
    //   "identities": identities,
    //   "creationTime": keyMeta.creationTime,
    //   "fingerprint": keyMeta.fingerprint,
    //   "keyId": keyMeta.keyId.toLowerCase(),
    //   "canSign": keyMeta.canSign,
    //   "canEncrypt": keyMeta.canEncrypt,
    //   "armoredKey": publicKeyData,
    // };

    if (publicKeyList[mainKey]!.containsKey('identities') && (publicKeyList[mainKey]?['identities'] is List)) {
      for (dynamic identity in publicKeyList[mainKey]?['identities']) {
        if (identity.containsKey("email")) {
          publicEmailKeyMap[identity["email"]!] = mainKey;
        }
      }
    }

    await storeKeys(privateKeys: false);
  }

  // Future<PrivateKeyMetadata> getPrivateKeyMetadata(String privateKeyData) async {
  //   return await OpenPGP.getPrivateKeyMetadata(privateKeyData);
  // }

  // Future<PublicKeyMetadata> getPublicKeyMetadata(String publicKeyData) async {
  //   return await OpenPGP.getPublicKeyMetadata(publicKeyData);
  // }

  Future<Map<String, dynamic>?> decryptSearchKey(String encData, {List<MailAddress>? from}) async {
    String? privKey;
    String? password;
    bool hasHiddenRecipient = false;

    List<Map<String, dynamic>>? packets = await listPgpPackets(encData);

    if (packets != null) {
      for (Map<String, dynamic> packet in packets) {
        if (privateKeyMap.containsKey(packet["keyID"])) {
          privKey = privateKeyList[privateKeyMap[packet["keyID"]]]!["armoredKey"];
          password = await getPrivateKeyPassword(privateKeyList[privateKeyMap[packet["keyID"]]]!);
        }
        if (packet["keyID"] == "0000000000000000" || packet["keyID"] == null) hasHiddenRecipient = true;
      }
    }

    if (privKey != null) {
      return await decryptString(encData, privKey, password, from: from);
    } else if (hasHiddenRecipient) {
      return await tryPrivateKeys(encData, from: from);
    } else {
      return null;
    }
  }

  Future<String?> getPrivateKeyPassword(Map<String, dynamic> privateKeyMap) async {
    String? password;
    if (privateKeyMap["encrypted"]) {
      if ((privateKeyMap["privateKeyPassword"] as String?).isNullOrEmpty()) {
        String? tempPw = NavService.navKey.currentContext!
            .read<SettingsProvider>()
            .sessionpMap["pkey_password_${privateKeyMap['keyId']}"];
        if (tempPw != null) return tempPw;

        String email = privateKeyMap["identities"]?[0]?["email"] ?? '';

        Map<String, String>? result = await passwordDialog(
          askOutgoing: false,
          mainTitle: "Private key password",
          incomingTitle: "($email)",
          incomingValidator: (pw) async {
            bool isPassOK = await (await PgpEmail.getInstance()).isPassphraseOk(privateKeyMap["armoredKey"], pw);
            if (!isPassOK) {
              return "Wrong password";
            }
            return null;
          },
        );
        if (result == null) throw Exception("Cancelled by User");
        password = result["incoming"];
        NavService.navKey.currentContext!
            .read<SettingsProvider>()
            .sessionpMap["pkey_password_${privateKeyMap['keyId']}"] = password;
      } else {
        password = privateKeyMap["privateKeyPassword"];
      }
    }

    return password;
  }

  Future<Map<String, dynamic>?> decryptString(String encData, String privateKey, String? password,
      {List<MailAddress>? from}) async {
    jsResult = null;
    await ensureWebViewRunning();
    List<String> pubKeys = [];
    if (from != null) {
      for (MailAddress adr in from) {
        if (publicEmailKeyMap.containsKey(adr.email)) {
          pubKeys.add(publicKeyList[publicEmailKeyMap[adr.email]]!["armoredKey"]);
        }
      }
    }

    wvController!.evaluateJavascript(
      source: pubKeys.isEmpty
          ? "decryptAndVerify(${jsonEncode(encData)},${jsonEncode(privateKey)},${jsonEncode(password)});"
          : "decryptAndVerify(${jsonEncode(encData)},${jsonEncode(privateKey)},${jsonEncode(password)},${jsonEncode(pubKeys)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      dynamic decoded = jsonDecode(jsResult!);
      return decoded;
    }
    return null;
  }

  Future<Map<String, dynamic>?> tryPrivateKeys(String encData, {List<MailAddress>? from}) async {
    Map<String, dynamic>? result;
    for (MapEntry<String, Map<String, dynamic>> privateKey in privateKeyList.entries) {
      String? password = await getPrivateKeyPassword(privateKey.value);
      result = await decryptString(encData, privateKey.value["armoredKey"], password, from: from);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> listPgpPackets(String armoredPgp) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "listPackets(${jsonEncode(armoredPgp)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      dynamic decoded = jsonDecode(jsResult!);
      return decoded.cast<Map<String, dynamic>>();
    }

    return null;
  }

  Future<List<String>?> getKeyId(String armoredKey) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "getKeyId(${jsonEncode(armoredKey)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      dynamic decoded = jsonDecode(jsResult!);
      return decoded.cast<String>();
    }
    return null;
  }

  Future<List<String>?> getPublicKeyId(String armoredKey) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "getPublicKeyId(${jsonEncode(armoredKey)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      dynamic decoded = jsonDecode(jsResult!);
      return decoded.cast<String>();
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPublicKeyMetadataJS(String armoredKey) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "getPublicKeyMetadata(${jsonEncode(armoredKey)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      return jsonDecode(jsResult!);
    }
    return null;
  }

  Future<Map<String, dynamic>?> getPrivateKeyMetadataJS(String armoredKey) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "getPrivateKeyMetadata(${jsonEncode(armoredKey)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      return jsonDecode(jsResult!);
    }
    return null;
  }

  Future<bool> isPassphraseOk(String armoredKey, String? password) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source: "isPassphraseCorrect(${jsonEncode(armoredKey)},${jsonEncode(password)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) throw WrongPasswordException("Wrong password");
      dynamic decoded = jsonDecode(jsResult!);
      return decoded;
    }
    throw WrongPasswordException("Timeout checking Password");
  }

  Future<String?> encryptText(
      String message, List<String> publicKeys, String? signingKey, String? passphrase, bool hasBcc) async {
    jsResult = null;
    await ensureWebViewRunning();

    wvController!.evaluateJavascript(
      source:
          "encryptMessage(${jsonEncode(message)},${jsonEncode(publicKeys)},${jsonEncode(signingKey)},${jsonEncode(passphrase)},${jsonEncode(hasBcc)});",
    );

    if (await waitForResult()) {
      if (jsResult == null) return null;
      dynamic decoded = jsonDecode(jsResult!);
      return decoded;
    }
    return null;
  }

  PgpEmail._()
      : _storage = const secstore.FlutterSecureStorage(),
        _androidOptions =
            secstore.AndroidOptions(sharedPreferencesName: 'slow_mail', preferencesKeyPrefix: 'privatepgp');

  static PgpEmail getInstance() {
    if (_instance != null) return _instance!;
    _instance = PgpEmail._();
    //await _instance!.initWebView();
    return _instance!;
  }

  Future<void> ensureWebViewRunning() async {
    if (_isWebViewRunning) return;
    await initWebView();
    _isWebViewRunning = true;
  }

  Future<void> initWebView() async {
    html = await rootBundle.loadString('assets/pgp_parser.html');

    HeadlessInAppWebView headlessWebView = HeadlessInAppWebView(
      initialSettings: settings,
      initialData: InAppWebViewInitialData(
        data: html!,
      ),
      onWebViewCreated: (controller) {
        wvController = controller;
        controller.addJavaScriptHandler(
          handlerName: 'jsResult',
          callback: (args) {
            jsResult = args.first as String;
          },
        );
      },
    );

    jsResult = null;
    await headlessWebView.run();

    if (await waitForResult()) {
      dynamic result = jsonDecode(jsResult ?? '');
      if (!(result["platformReady"] ?? false) || !(result["openpgp"] ?? false)) {}
    } else {
      throw TimeoutException("Unable to start Headless WebView");
    }
    jsResult = null;
  }

  Future<bool> waitForResult() async {
    for (int i = 0; i < 100; i++) {
      if (jsResult == null) {
        await Future.delayed(const Duration(milliseconds: 50));
      } else {
        return true;
      }
    }
    return false;
  }

  void free() {
    if (wvController != null) {
      wvController!.dispose();
      wvController = null;
    }
    _instance = null;
  }
}

class PublicKeyMetadataJS {
  String? keyId;
  String? fingerprint;
  List<String>? userIds;
  String? creationTime;
  Algorithm? algorithm;
  List<SubKeys>? subKeys;

  PublicKeyMetadataJS({this.keyId, this.fingerprint, this.userIds, this.creationTime, this.algorithm, this.subKeys});

  PublicKeyMetadataJS.fromJson(Map<String, dynamic> json) {
    keyId = json['keyId'];
    fingerprint = json['fingerprint'];
    userIds = json['userIds'].cast<String>();
    creationTime = json['creationTime'];
    algorithm = json['algorithm'] != null ? new Algorithm.fromJson(json['algorithm']) : null;
    if (json['subKeys'] != null) {
      subKeys = <SubKeys>[];
      json['subKeys'].forEach((v) {
        subKeys!.add(new SubKeys.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['keyId'] = this.keyId;
    data['fingerprint'] = this.fingerprint;
    data['userIds'] = this.userIds;
    data['creationTime'] = this.creationTime;
    if (this.algorithm != null) {
      data['algorithm'] = this.algorithm!.toJson();
    }
    if (this.subKeys != null) {
      data['subKeys'] = this.subKeys!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Algorithm {
  String? algorithm;
  String? curve;

  Algorithm({this.algorithm, this.curve});

  Algorithm.fromJson(Map<String, dynamic> json) {
    algorithm = json['algorithm'];
    curve = json['curve'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['algorithm'] = this.algorithm;
    data['curve'] = this.curve;
    return data;
  }
}

class SubKeys {
  String? keyId;
  Algorithm? algorithm;
  String? creationTime;

  SubKeys({this.keyId, this.algorithm, this.creationTime});

  SubKeys.fromJson(Map<String, dynamic> json) {
    keyId = json['keyId'];
    algorithm = json['algorithm'] != null ? new Algorithm.fromJson(json['algorithm']) : null;
    creationTime = json['creationTime'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['keyId'] = this.keyId;
    if (this.algorithm != null) {
      data['algorithm'] = this.algorithm!.toJson();
    }
    data['creationTime'] = this.creationTime;
    return data;
  }
}
