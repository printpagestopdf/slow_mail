import 'package:google_sign_in/google_sign_in.dart';
import 'package:enough_mail/enough_mail.dart';
import 'dart:convert';

class GoogleAuthService {
  // final googleServerClientId = '1076430255982-hhi400hce6hcsvsgipmh5o7kr2mn0g8l.apps.googleusercontent.com';
  // final googleServerClientId = '442571260809-mj9ib858v03ovtdvgsmcffrfuijpsiqq.apps.googleusercontent.com'; //Android client
  final googleServerClientId = '442571260809-p3qvokigctfm82evjj9m3p898b1a5hee.apps.googleusercontent.com'; //Web client
  static const _scopes = ['email', 'profile', 'https://mail.google.com/'];
  GoogleSignInAccount? account;
  bool isInitialized = false;

// Singleton init
  static final GoogleAuthService _singleton = GoogleAuthService._internal();
  factory GoogleAuthService() {
    return _singleton;
  }
  GoogleAuthService._internal();
  // Singleton init End

  Future<void> initialize() async {
    if (isInitialized) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: googleServerClientId,
    );

    // Event Stream abhören
    GoogleSignIn.instance.authenticationEvents.listen(_onAuthEvent).onError(_onAuthError);

    // Lautlose Wiederherstellung versuchen – kein Dialog!
    account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) await signIn();

    isInitialized = true;
  }

  void _onAuthEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      account = event.user; // Session wiederhergestellt
    } else if (event is GoogleSignInAuthenticationEventSignOut) {
      account = null;
    }
  }

  void _onAuthError(Object error) {
    // Lightweight auth fehlgeschlagen → interaktiver Login nötig
    account = null;
  }

  // Nur aufrufen wenn attemptLightweightAuthentication fehlschlug
  Future<void> signIn() async {
    try {
      await initialize();
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await initialize();
      await GoogleSignIn.instance.signOut();
      isInitialized = false;
      account = null;
    } catch (e) {
      rethrow;
    }
  }

  Future<OauthToken?> buildFreshOauthToken() async {
    await initialize();
    if (account == null) return null;
    final before = DateTime.now().toUtc();
    var auth = await account!.authorizationClient.authorizationForScopes(_scopes);
    auth ??= await account!.authorizationClient.authorizeScopes(_scopes);
    return OauthToken(
      accessToken: auth.accessToken,
      expiresIn: 3600,
      tokenType: 'Bearer',
      scope: _scopes.join(' '),
      refreshToken: '',
      created: before,
      provider: 'google',
    );
  }
}
