import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:enough_mail/enough_mail.dart';

class YahooAuthService {
  static const _clientId =
      'dj0yJmk9dWozOUQ3bkZzU1ZxJmQ9WVdrOWNGWTVOak5EVUcwbWNHbzlNQT09JnM9Y29uc3VtZXJzZWNyZXQmc3Y9MCZ4PTRj';
  static const _redirectUri = 'https://printpagestopdf.github.io/dns/oauth/callback/';
  static const _discoveryUrl = 'https://api.login.yahoo.com/.well-known/openid-configuration';
  static const _scopes = ['openid', 'email' /* , 'mail-r' */];
  final _appAuth = FlutterAppAuth();

  static const _serviceConfig = AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://api.login.yahoo.com/oauth2/request_auth',
    tokenEndpoint: 'https://api.login.yahoo.com/oauth2/get_token',
  );

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
      if (result == null) return null;
      return _toOauthToken(result);
    } catch (e) {
      throw Exception('Yahoo Login fehlgeschlagen: $e');
    }
  }

  Future<EndSessionResponse> signOut() async {
    return await _appAuth.endSession(EndSessionRequest(discoveryUrl: _discoveryUrl));
  }

  Future<OauthToken?> refresh(OauthToken expiredToken) async {
    try {
      final result = await _appAuth.token(
        TokenRequest(
          _clientId,
          _redirectUri,
          // kein clientSecret
          // discoveryUrl: _discoveryUrl,
          refreshToken: expiredToken.refreshToken,
          scopes: _scopes,
        ),
      );
      return _toOauthToken(result);
    } catch (e) {
      throw Exception('Yahoo Refresh fehlgeschlagen: $e');
    }
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
      provider: 'yahoo',
    );
  }
}
