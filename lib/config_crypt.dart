import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class ConfigCrypt {
  ConfigCrypt();

  final _secureRandom = Random.secure(); // sichere Zufallsquelle

  List<int> _randomBytes(int length) => List<int>.generate(length, (_) => _secureRandom.nextInt(256));

  /// Password -> Key ableiten (PBKDF2)
  Future<SecretKey> deriveKeyFromPassword(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 150000, // moderne Empfehlung (kann je nach Zielplattform angepasst werden)
      bits: 256, // AES-256
    );

    return await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt, // Salt als "nonce" Parameter
    );
  }

  /// Verschlüsseln (AES-GCM)
  Future<Map<String, dynamic>> encryptText({
    required String password,
    required String plaintext,
  }) async {
    final algorithm = AesGcm.with256bits();

    // 16-Byte Salt für PBKDF2
    final salt = _randomBytes(16);

    // Key aus Passwort ableiten
    final key = await deriveKeyFromPassword(password, salt);

    // Option A: Cryptography generiert automatisch ein robustes Nonce/IV, wenn du keines angibst.
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );

    // Oder Option B: Du erzeugst selber ein 12-Byte-Nonce (GCM standardmäßig 12 Bytes)
    // final nonce = _randomBytes(12);
    // final secretBox = await algorithm.encrypt(
    //   utf8.encode(plaintext),
    //   secretKey: key,
    //   nonce: nonce,
    // );

    return {
      "ciphertext": base64Encode(secretBox.cipherText),
      "nonce": base64Encode(secretBox.nonce),
      "mac": base64Encode(secretBox.mac.bytes),
      "salt": base64Encode(salt),
    };
  }

  /// Entschlüsseln (AES-GCM)
  Future<String> decryptText({
    required String password,
    required Map<String, dynamic> encryptedData,
  }) async {
    final algorithm = AesGcm.with256bits();

    final salt = base64Decode(encryptedData["salt"] as String);
    final nonce = base64Decode(encryptedData["nonce"] as String);
    final ciphertext = base64Decode(encryptedData["ciphertext"] as String);
    final mac = Mac(base64Decode(encryptedData["mac"] as String));

    // Key erneut aus Passwort + Salt ableiten
    final key = await deriveKeyFromPassword(password, salt);

    // Entschlüsseln
    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: mac,
    );

    final clearBytes = await algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(clearBytes);
  }

  void main() async {
    const password = "meinSicheresPasswort123!";
    const message = "Das ist ein geheimer Text.";

    final encrypted = await encryptText(
      password: password,
      plaintext: message,
    );

    print("Encrypted:");
    print(encrypted);

    final decrypted = await decryptText(
      password: password,
      encryptedData: encrypted,
    );

    print("\nDecrypted:");
    print(decrypted);
  }
}
