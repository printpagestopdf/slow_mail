import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:slow_mail/oauth/google_auth_service.dart';
import 'package:slow_mail/utils/common_import.dart';

const googleId = '1076430255982-llforq2bbrehsei5ainbfac98ivsr6a2';
const googleClientId = '$googleId.apps.googleusercontent.com';
const googleRedirectUri = 'com.googleusercontent.apps.$googleId:/oauth2redirect';
const googleWebId = '1076430255982-hhi400hce6hcsvsgipmh5o7kr2mn0g8l.apps.googleusercontent.com';
const googleServerClientId = '$googleId.apps.googleusercontent.com';
// const googleRedirectUri = 'com.theripper.slow_mail://';

class Oauth2Handler {
  final _googleSignIn = GoogleSignIn.instance;
  static GoogleAuthService? gas;
  static const _scopes = [
    'email',
    'profile',
    'https://mail.google.com/',
  ];

  Future<String?> initGmailAuth() async {
    /*
    await _googleSignIn.initialize(
      // Nur nötig wenn du keinen Web-Client in google-services.json hast
      serverClientId: googleWebId,
    );
    // Schritt 1: Authentifizieren
    final account = await _googleSignIn.authenticate();

    // Schritt 2: Autorisierung über authorizationClient des Users
    final authClient = account.authorizationClient;

    // Erst prüfen ob Scopes bereits vorhanden
    var authorization = await authClient.authorizationForScopes(_scopes);

    // Falls nicht → explizit anfordern
    authorization ??= await authClient.authorizeScopes(_scopes);

    //return authorization.accessToken;
    final oauthToken = OauthToken(
      accessToken: authorization.accessToken,
      expiresIn: 3600,
      tokenType: 'Bearer',
      scope: _scopes.join(' '),
      // Kein echter refreshToken verfügbar –
      // enough_mail nutzt stattdessen den refresh-Callback oben
      refreshToken: '',
      created: DateTime.now().toUtc(),
      provider: 'google',
    );
*/
/*
    if (gas == null) {
      gas = GoogleAuthService();
      await gas!.initialize();
    }
    await gas!.signIn();
    OauthToken? token = await gas!.buildFreshOauthToken();
    if (token == null) return null;
    final auth = OauthAuthentication("schweigerkarl00@gmail.com", token);

    final mailAccount = MailAccount.fromManualSettingsWithAuth(
      name: 'gmail.com',
      email: "schweigerkarl00@gmail.com",
      userName: "schweigerkarl00",
      incomingHost: 'imap.gmail.com',
      outgoingHost: 'smtp.gmail.com',
      auth: auth,
      incomingType: ServerType.imap,
      outgoingType: ServerType.smtp,
      outgoingClientDomain: "slowmail.com",
      incomingPort: 993,
      outgoingPort: 465,
      incomingSocketType: SocketType.ssl,
      outgoingSocketType: SocketType.ssl,
    );

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/singleShot.json');
    await file.writeAsString(encoder.convert(mailAccount.toJson()), mode: FileMode.write);

    // const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    // final jsonString = encoder.convert(mailAccount.toJson());
    // AppLogger.log(jsonString);

    final client = MailClient(mailAccount);
    await client.connect();

//     final client = ImapClient();
//     await client.connectToServer('imap.gmail.com', 993, isSecure: true);

// // XOAUTH2 direkt übergeben
//     await client.authenticateWithOAuth2("schweigerkarl00@gmail.com", authorization.accessToken);

// Posteingang lesen
    await client.selectInbox();
    // final messages = await client.fetchRecentMessages(messageCount: 20);
    // AppLogger.log(messages);

    for (Mailbox mb in (await client.listMailboxes(/* recursive: true */))) {
      AppLogger.log(mb);
    }
    await client.disconnect();
    //await signOut();
    */
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<void> initGmailAuthOld() async {
    FlutterAppAuth appAuth = FlutterAppAuth();

    final result = await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        googleClientId,
        googleRedirectUri,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: [
          'email',
          'profile',
          'https://mail.google.com/',
        ],
      ),
    );
  }
}
