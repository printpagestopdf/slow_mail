import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/utils/common_import.dart';
import 'package:slow_mail/oauth/oauth_service.dart';

class GoogleAuthService implements OauthService {
  final String _clientId = '442571260809-mj9ib858v03ovtdvgsmcffrfuijpsiqq.apps.googleusercontent.com'; // Android client
  final _redirectUri = 'com.theripper.slowmail:/oauth2redirect';
  final _discoveryUrl = 'https://accounts.google.com/.well-known/openid-configuration';
  final _scopes = [
    'https://mail.google.com/',
    'email',
    'profile',
  ];
  final _appAuth = FlutterAppAuth();

  final _serviceConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://oauth2.googleapis.com/token',
  );
// Singleton init
  static final GoogleAuthService _singleton = GoogleAuthService._internal();
  factory GoogleAuthService() {
    return _singleton;
  }
  GoogleAuthService._internal();
  // Singleton init End

  Future<OauthToken?> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          discoveryUrl: _discoveryUrl,
          serviceConfiguration: _serviceConfig,
          scopes: _scopes,
        ),
      );
      // currentEmail = _extractEmailFromIdToken(result.idToken!);
      return _toOauthToken(result);
    } catch (e) {
      AppLogger.log('Google Login fehlgeschlagen: $e');
    }

    return null;
  }

  @override
  Future<OauthToken?> getOauthToken(OauthToken? expiredToken) async {
    if (expiredToken == null || expiredToken.refreshToken.isNullOrEmpty()) {
      return await signIn();
    }
    if (expiredToken.isValid) return expiredToken;
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          // kein clientSecret
          // clientSecret: _clientSecret,
          discoveryUrl: _discoveryUrl,
          serviceConfiguration: _serviceConfig,
          refreshToken: expiredToken.refreshToken,
          scopes: _scopes,
        ),
      );
      return _toOauthToken(result);
    } catch (_) {
      // throw Exception('Google Refresh fehlgeschlagen: $e');
    }
    return null;
  }

  OauthToken _toOauthToken(TokenResponse result) {
    final before = DateTime.now().toUtc();
    return OauthToken(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? '',
      expiresIn: result.accessTokenExpirationDateTime?.difference(before).inSeconds ?? 3600,
      tokenType: 'Bearer',
      scope: _scopes.join(' '),
      created: before,
      provider: 'google',
    );
  }

  /// Extrahiert die E-Mail aus dem JWT ID Token (ohne externe Lib).
  String? _extractEmailFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;

      // Base64Url → Base64 (Padding ergänzen)
      var payload = parts[1];
      payload = payload.replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64.decode(payload));
      final Map<String, dynamic> claims = json.decode(decoded);
      return claims['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}
