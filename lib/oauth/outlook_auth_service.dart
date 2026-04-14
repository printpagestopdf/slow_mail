import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/utils/utils.dart';

class OutlookAuthService {
  static const _clientId = '07951e3d-b130-4c60-b232-697024ac0cb9';
  static const _redirectUri = 'com.theripper.slowmail://auth';
  // static const _tenantId = 'common'; // persönliche + Geschäftskonten
  static const _tenantId = 'consumers'; // persönliche Konten

  // static const _tenantId = 'consumers'; // persönliche + Geschäftskonten

  static const _scopes = [
    'openid',
    // 'email',
    // 'profile',
    'offline_access',
    'https://outlook.office.com/IMAP.AccessAsUser.All',
    'https://outlook.office.com/SMTP.Send',
  ];

  final _appAuth = FlutterAppAuth();

  Future<OauthToken?> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUri,
          promptValues: ['select_account'],
          // issuer: 'https://login.microsoftonline.com/$_tenantId/v2.0',
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize',
            tokenEndpoint: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token',
          ),
          scopes: _scopes,
          // additionalParameters: {
          //   'resource': 'https://outlook.office.com',
          // },
        ),
      );

      if (result == null) return null;
      return _toOauthToken(result);
    } catch (e, stackTrace) {
      AppLogger.log('Auth error: $e');
      AppLogger.log('Stack: $stackTrace');
      rethrow; // oder return null, aber zumindest printen
    }
  }

  // Token-Refresh mit Refresh Token – funktioniert bei Outlook vollständig
  Future<OauthToken?> refresh(OauthToken expiredToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          serviceConfiguration: AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize',
            tokenEndpoint: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token',
          ),
          refreshToken: expiredToken.refreshToken,
          scopes: _scopes,
        ),
      );

      if (result == null) return null;
      return _toOauthTokenRefresh(result);
    } catch (e) {
      return null;
    }
  }

  OauthToken _toOauthToken(AuthorizationTokenResponse result) {
    final before = DateTime.now().toUtc();
    return OauthToken(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? '',
      expiresIn: result.accessTokenExpirationDateTime?.difference(before).inSeconds ?? 3600,
      tokenType: 'Bearer',
      scope: _scopes.join(' '),
      created: before,
      provider: 'outlook',
    );
  }

  OauthToken _toOauthTokenRefresh(TokenResponse result) {
    final before = DateTime.now().toUtc();
    return OauthToken(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? '',
      expiresIn: result.accessTokenExpirationDateTime?.difference(before).inSeconds ?? 3600,
      tokenType: 'Bearer',
      scope: _scopes.join(' '),
      created: before,
      provider: 'outlook',
    );
  }
}
