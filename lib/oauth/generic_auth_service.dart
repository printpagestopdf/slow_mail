import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/oauth/oauth_service.dart';

class GenericAuthService implements OauthService {
  @override
  Future<OauthToken?> getOauthToken(OauthToken? expiredToken) async {
    return null;
  }
}
