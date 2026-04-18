import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/oauth/generic_auth_service.dart';
import 'package:slow_mail/oauth/google_auth_service.dart';
import 'package:slow_mail/oauth/outlook_auth_service.dart';
import 'package:slow_mail/oauth/yahoo_auth_service.dart';

abstract class OauthService {
  Future<OauthToken?> getOauthToken(OauthToken? expiredToken);

  static OauthService getByDomain(String domain) {
    if (['gmail.com', 'googlemail.com', 'google.com', 'jazztel.es'].any(
      (part) => domain.endsWith(part),
    )) {
      return GoogleAuthService();
    }

    if ([
          'hotmail.com',
          'live.com',
          'msn.com',
          'windowslive.com',
          'livemail.tw',
          'olc.protection.outlook.com',
        ].any((part) => domain.endsWith(part)) ||
        [
          "outlook.office365",
          RegExp(r'outlook\...$', caseSensitive: false),
          RegExp(r'outlook\.co\...$', caseSensitive: false),
          RegExp(r'outlook\.com\...$', caseSensitive: false),
          RegExp(r'hotmail\...$', caseSensitive: false),
          RegExp(r'hotmail\.co\...$', caseSensitive: false),
          RegExp(r'hotmail\.com\...$', caseSensitive: false),
          RegExp(r'live\...$', caseSensitive: false),
          RegExp(r'live\.co\...$', caseSensitive: false),
          RegExp(r'live\.com\...$', caseSensitive: false),
        ].any(
          (part) => domain.contains(part),
        )) {
      return OutlookAuthService(); //Microsoft
    }

    if ([
      'yahoo.com',
      'yahoo.de',
      'yahoo.it',
      'yahoo.fr',
      'yahoo.es',
      'yahoo.se',
      'yahoo.co.uk',
      'yahoo.co.nz',
      'yahoo.com.au',
      'yahoo.com.ar',
      'yahoo.com.br',
      'yahoo.com.mx',
      'ymail.com',
      'rocketmail.com',
      'mail.am0.yahoodns.net',
      'am0.yahoodns.net',
      'yahoodns.net',
      'aol.com',
      'aim.com',
      'netscape.net',
      'netscape.com',
      'compuserve.com',
      'cs.com',
      'wmconnect.com',
      'aol.de',
      'aol.it',
      'aol.fr',
      'aol.es',
      'aol.se',
      'aol.co.uk',
      'aol.co.nz',
      'aol.com.au',
      'aol.com.ar',
      'aol.com.br',
      'aol.com.mx',
      'mail.gm0.yahoodns.net',
    ].any((part) => domain.endsWith(part))) {
      return YahooAuthService(); //Yahoo
    }

    if ([
      'gmx.net',
      'gmx.de',
      'gmx.at',
      'gmx.ch',
      'gmx.eu',
      'gmx.biz',
      'gmx.org',
      'gmx.info',
    ].any((part) => domain.endsWith(part))) {
      return GenericAuthService(); //Gmx
    }

    return GenericAuthService();
  }
}
