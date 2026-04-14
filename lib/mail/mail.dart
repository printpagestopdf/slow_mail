import 'dart:collection';
import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/utils/common_import.dart';
import 'package:flutter/foundation.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/utils/android_notifyer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/pgp/pgp_email.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

extension SupportedAuthentication on Authentication {
  static List<Authentication> get supported {
    return const [
      Authentication.passwordClearText,
      Authentication.passwordEncrypted,
      Authentication.oauth2,
      Authentication.none,
      Authentication.unknown,
    ];
  }

  Authentication mapSupported() {
    if (this == Authentication.plain) return Authentication.passwordClearText;
    return supported.contains(this) ? this : Authentication.unknown;
  }
}

extension MailAdressListExt on List<MailAddress>? {
  List<MailAddress>? get unique {
    if (this == null) return null;
    Map<String, MailAddress> m = {for (var i in this!) i.email: i};
    return m.values.toList();
  }

  bool containsAll(List<MailAddress>? adrs) {
    if (this == null) return false;
    if (adrs == null) return true;
    for (MailAddress adr in adrs) {
      try {
        this!.firstWhere((MailAddress m) => m.email == adr.email);
      } catch (_) {
        return false;
      }
    }
    return true;
  }
}

extension MailAddressExtension on MailAddress {
  //prevent name equals email => higher spam level on email send
  MailAddress normalized() {
    return (email == personalName) ? MailAddress("", email) : this;
  }

  String shortDisplay() {
    return hasPersonalName ? personalName! : email;
  }
}

extension MimeMessageExt on MimeMessage {
  String emailSubject() {
    //AppLogger.log(decodeSubject());
    return decodeSubject() ?? "Empty Subject";
  }

  String emailFrom() {
    return envelope?.sender?.email ?? "Unknown Sender";
  }

  String emailFullFrom() {
    if (envelope?.sender != null) return envelope!.sender.toString();
    if (sender != null) return sender.toString();
    if (decodeSender().isNotEmpty) return decodeSender().first.toString();
    if (from != null && from!.isNotEmpty) return from!.first.toString();

    return "UnknownFrom <unknown@noreply.com";
  }

  String emailDisplayDate() {
    DateTime dt;
    if (envelope?.date != null) {
      dt = envelope!.date!;
    } else if (decodeHeaderValue("Date") case String hDate) {
      dt = DateTime.parse(hDate).toUtc();
    } else if (internalDate != null) {
      dt = DateTime.parse(internalDate!).toUtc();
    } else {
      return "";
    }
    return DateFormat().yMdHm(tz.TZDateTime.from(dt, tz.local));
  }

  String getMimeHTML() {
    if (mediaType.text == 'multipart/encrypted') {
      return "<pre>${LocaleKeys.msg_encrypt_error.tr()}</pre>";
    }

    String? html;

    try {
      html = decodeTextHtmlPart();
    } on FormatException catch (_) {
      // QP-Decoder schlägt fehl — rohen Body holen und manuell säubern
      final htmlPart = getAlternativePart(MediaSubtype.textHtml) ?? getPartWithMediaSubtype(MediaSubtype.textHtml);
      if (htmlPart != null) {
        // Rohen encoded Text holen
        StringBuffer raw = StringBuffer();
        htmlPart.mimeData?.render(raw, renderHeader: false);
        html = _manualQpDecode(raw.toString());
      }
    }

    return html ?? getTextPartsAsHtml();
  }

  String getTextPartsAsHtml() {
    return "<pre>${getTextParts()}</pre>";
  }

  String getTextParts() {
    String res = "";
    String txt = "";
    for (MimePart mp in allPartsFlat!) {
      if (mp.isTextMediaType()) {
        txt = "";
        try {
          txt = mp.decodeTextPlainPart() ?? "";
        } on FormatException catch (_) {
          // QP-Decoder schlägt fehl — rohen Body holen und manuell säubern
          // Rohen encoded Text holen
          StringBuffer raw = StringBuffer();
          mp.mimeData?.render(raw, renderHeader: false);
          txt = _manualQpDecode(raw.toString());
        }
        res = res + txt;
      }
    }
    return res;
  }

  String _manualQpDecode(String input) {
    // Soft line breaks entfernen (= am Zeilenende)
    var result = input.replaceAll('=\r\n', '').replaceAll('=\n', '');

    // =XX dekodieren, ungültige Sequenzen tolerant überspringen
    final buffer = StringBuffer();
    int i = 0;
    final bytes = <int>[];

    while (i < result.length) {
      if (result[i] == '=' && i + 2 < result.length) {
        final hex = result.substring(i + 1, i + 3);
        final value = int.tryParse(hex, radix: 16);
        if (value != null) {
          bytes.add(value);
          i += 3;
          continue;
        }
      }
      // Pending bytes als UTF-8 flushen
      if (bytes.isNotEmpty) {
        buffer.write(utf8.decode(bytes, allowMalformed: true));
        bytes.clear();
      }
      buffer.write(result[i]);
      i++;
    }
    if (bytes.isNotEmpty) {
      buffer.write(utf8.decode(bytes, allowMalformed: true));
    }
    return buffer.toString();
  }

  Future<String?> getContentPart(MailClient mc, String fetchId) async {
    MimePart? p = getPart(fetchId);
    if (p != null && p.mimeData is BinaryMimeData) {
      return p.decodeContentText();
    }
    MimePart part = await mc.fetchMessagePart(
      this,
      fetchId,
    );
    return utf8.decode(part.decodeContentBinary()!);
    // part.decodeContentText();
  }

  Future<Uint8List?> getBinaryPart(MailClient mc, String? fetchId) async {
    if (fetchId.isNullOrEmpty()) {
      //main Messag is attachment
      MimeMessage mm = await mc.fetchMessageContents(this);
      return mm.decodeContentBinary();
    }
    MimePart? p = getPart(fetchId!);
    if (p != null) {
      return p.decodeContentBinary();
    }
    MimePart part = await mc.fetchMessagePart(
      this,
      fetchId!,
    );
    return part.decodeContentBinary();
  }

  Future<MimeMessage?> fetchTextHtml(MailClient mc) async {
    if (mediaType.text == 'multipart/encrypted') {
      BodyPart? encBp = body?.findFirst(MediaSubtype.applicationOctetStream);
      Map<String, dynamic>? decResult;
      if (encBp?.fetchId != null) {
        Uint8List? encBytes = await getBinaryPart(mc, encBp!.fetchId!);
        if (encBytes != null) {
          decResult = await PgpEmail.getInstance().decryptSearchKey(utf8.decode(encBytes), from: from);
        }
      }
      if (decResult != null) {
        MimeMessage newMsg = MimeMessage.parseFromText(decResult["text"]);
        newMsg.sequenceId = sequenceId;
        newMsg.uid = uid;
        newMsg.sender ?? sender;
        newMsg.envelope = envelope;
        newMsg.flags = flags;
        newMsg.parse();
        newMsg.addHeader("X-EncryptedBase", "true");
        if ((decResult["signingKeys"] as List<dynamic>).isNotEmpty) {
          newMsg.addHeader("X-SignedBy", decResult["signingKeys"][0]["key"]);
          newMsg.addHeader("X-SignatureVerified", decResult["signingKeys"][0]["verified"].toString());
        }
        return newMsg;
      } else {
        throw Exception("Unable to decrypt message");
      }
    }
    if (isTextPlainMessage() || isTextMessage()) {
      FetchImapResult imapRes = (uid != null)
          ? await (mc.lowLevelIncomingMailClient as ImapClient)
              .uidFetchMessage(uid!, "(RFC822.HEADER FLAGS BODYSTRUCTURE BODY.PEEK[TEXT])")
          : await (mc.lowLevelIncomingMailClient as ImapClient)
              .fetchMessage(sequenceId!, "(RFC822.HEADER FLAGS BODYSTRUCTURE BODY.PEEK[TEXT])");
      mimeData = imapRes.messages.first.mimeData;
      parse();
      return null;
    }

    if (body != null) {
      BodyPart? bodyHtml = body!.findFirst(MediaSubtype.textHtml);
      if (bodyHtml != null) {
        if (bodyHtml.bodyRaw == null) {
          FetchImapResult imapRes = (uid != null)
              ? await (mc.lowLevelIncomingMailClient as ImapClient)
                  .uidFetchMessage(uid!, "(BODY.PEEK[${bodyHtml.fetchId}])")
              : await (mc.lowLevelIncomingMailClient as ImapClient)
                  .fetchMessage(sequenceId!, "(BODY.PEEK[${bodyHtml.fetchId}])");
          MimePart htmlPart = imapRes.messages.first.getPart(bodyHtml.fetchId!)!;
          setPart(bodyHtml.fetchId!, htmlPart);
        }
      }
      BodyPart? bodyTxt = body!.findFirst(MediaSubtype.textPlain);
      if (bodyTxt != null) {
        if (bodyTxt.bodyRaw == null) {
          FetchImapResult imapRes = (uid != null)
              ? await (mc.lowLevelIncomingMailClient as ImapClient)
                  .uidFetchMessage(uid!, "(BODY.PEEK[${bodyTxt.fetchId}])")
              : await (mc.lowLevelIncomingMailClient as ImapClient)
                  .fetchMessage(sequenceId!, "(BODY.PEEK[${bodyTxt.fetchId}])");
          MimePart htmlPart = imapRes.messages.first.getPart(bodyTxt.fetchId!)!;
          setPart(bodyTxt.fetchId!, htmlPart);
        }
      }
    }

    return null;
  }

  Future<MimePart?> fetchAttachmentPart(MailClient mc, ContentInfo ci) async {
    MimePart? p;
    if (ci.cid != null) {
      p = getPartWithContentId(ci.cid!);
      if (p != null && p.mimeData is BinaryMimeData) {
        return p;
      }
    }
    if (ci.fetchId.isNullOrEmpty()) {
      return await mc.fetchMessageContents(this);
    }
    p = getPart(ci.fetchId);
    if (p != null /* && p.mimeData is BinaryMimeData */) {
      return p;
    }
    MimePart part = await mc.fetchMessagePart(
      this,
      ci.fetchId,
    );

    return part;
  }

  bool get hasAllAttachments {
    if (hasAttachments()) return true;

    final disposition = getHeaderContentDisposition();
    if (disposition?.disposition == ContentDisposition.attachment) {
      return true;
    }

    return allPartsFlat.any((part) => part.getHeaderContentDisposition()?.disposition == ContentDisposition.attachment);
  }

  List<MimePart> get allAttachmentParts {
    final attachments = allPartsFlat
        .where((part) => part.getHeaderContentDisposition()?.disposition == ContentDisposition.attachment)
        .toList();

    final rootDisp = getHeaderContentDisposition();
    if (rootDisp?.disposition == ContentDisposition.attachment && !attachments.contains(this)) {
      attachments.add(this);
    }

    return attachments;
  }

  List<ContentInfo> get allAttachmentContentInfos {
    // Normale Attachments über den bekannten enough_mail-Weg
    final result = findContentInfo(
      disposition: ContentDisposition.attachment,
      complete: false,
    );

    //If main Message is attachment add it
    if (getHeaderContentDisposition()?.disposition == ContentDisposition.attachment) {
      collectContentInfo(ContentDisposition.attachment, result, null, complete: false);
    }

    return result;
  }

  List<MailAddress> replyToAddresses() {
    List<MailAddress> ret = [];
    if (replyTo != null) {
      ret.addAll(replyTo!);
    } else if (from != null && from!.isNotEmpty) {
      ret.add(from![0]);
    } else if (sender != null) {
      ret.add(sender!);
    }
    return ret.unique!;
  }

  List<MailAddress> replyToAllAddresses() {
    List<MailAddress> ret = replyToAddresses();

    if (to != null) {
      ret.addAll(to!);
    }
    return ret.unique!;
  }

  List<MailAddress> replyToAllCCAddresses() {
    if (cc != null) {
      return cc!.unique!;
    } else {
      return <MailAddress>[];
    }
  }
}

class MailValidator extends Object {
  static final RegExp _rsplitString = RegExp(r'\s*,\s*');
  static String? _lastError;

  static List<MailAddress> mailAddressesFromString(String? str) {
    List<MailAddress> ret = <MailAddress>[];
    if (str == null) return ret;

    MailAddress adr;
    for (String s in MailValidator.listFromString(str!)) {
      try {
        adr = MailAddress.parse(s);
        ret.add(adr);
      } catch (_) {}
    }
    return ret;
  }

  static String? validateEmailsString(String? strEmails) {
    return strEmails == null
        ? null
        : MailValidator.isStringListValid(strEmails)
            ? null
            : _lastError;
  }

  static bool isStringListValid(String strEmails) {
    for (String strEmail in MailValidator.listFromString(strEmails)) {
      if (!MailValidator.isStringValidEmail(strEmail)) return false;
    }
    return true;
  }

  static List<String> listFromString(String strEmails) {
    return strEmails.split(_rsplitString).where((s) => s.isNotEmpty).toList();
  }

  static bool isStringValidEmail(String strEmail) {
    try {
      MailAddress.parse(strEmail);
      return true;
    } catch (e) {
      _lastError = "$strEmail (${e.toString()})";
      return false;
    }
  }
}

enum MailProcessingState { busy, error, done, message, uninitialized }

class EmailProvider extends ChangeNotifier {
  // final List<int> _selectedEmails = [];
  final SplayTreeSet<int> _selectedEmails = SplayTreeSet<int>((a, b) => a.compareTo(b));
  final int pageSize = 25;
  final List<MimeMessage> _emailMessages = <MimeMessage>[];
  final Map<int, MimeMessage> _emailMessagesMap = <int, MimeMessage>{};
  int _lastEmailMessageIndex = 0;
  MailProcessingState processingState = MailProcessingState.uninitialized;
  String lastErrorMessage = '';
  Map<String, dynamic>? backgroundCheckInfo;
  String? currentEmail;
  MailAccount? currentMailAccount;
  MailAccountModel? currentMailAccountModel;
  MailClient? currentMailClient;
  MailClient? currentPollingClient;
  Tree<Mailbox?>? mailboxTree;
  String? mbEmail;
  PagedMessageSequence? _currentMessageSequence;
  int? _unreadMessages;
  StreamSubscription<MailConnectionLostEvent>? _currentConnectionLostEventSubscription;
  StreamSubscription<MailLoadEvent>? _pollingLoadEventSubscription;
  StreamSubscription<MailConnectionLostEvent>? _pollingConnectionLostEventSubscription;
  bool _isSilent = false;
  int? totalMessageCount;
  bool pollingEnabled = false;
  SharedPreferencesAsync? _sharedPreferencesAsync;

  EmailProvider() {
    pollingEnabled =
        NavService.navKey.currentContext?.read<SettingsProvider>().generalPrefs["currentNotificationEnabled"] ?? false;
  }

  @override
  void notifyListeners() {
    if (_isSilent) {
      return;
    }
    super.notifyListeners();
  }

  SharedPreferencesAsync get sharedPreferencesAsync {
    _sharedPreferencesAsync ??= SharedPreferencesAsync();
    return _sharedPreferencesAsync!;
  }

  set unreadMessages(int? num) {
    if (num != _unreadMessages) {
      _unreadMessages = num;
      notifyListeners();
    }
  }

  int? get unreadMessages {
    return _unreadMessages;
  }

  int get countSelectedEmails {
    return _selectedEmails.length;
  }

  void selectEmail(int idx) {
    _selectedEmails.add(idx);
    notifyListeners();
  }

  void unselectEmail(int? idx) {
    if (idx == null) {
      _selectedEmails.clear();
    } else {
      _selectedEmails.remove(idx);
    }
    notifyListeners();
  }

  void selectEmailRange(int? idx) {
    if (idx == null) return;
    int from = _selectedEmails.lastWhere(
      (int i) => idx > i,
      orElse: () => -1,
    );
    if (from > -1) {
      _selectedEmails.addAll(List.generate(idx - from + 1, (i) => from + i));
    } else {
      int? to = _selectedEmails.firstWhereOrNull((int i) => idx < i);
      if (to != null) {
        _selectedEmails.addAll(List.generate(to - idx + 1, (i) => to - i));
      } else {
        _selectedEmails.add(idx);
      }
    }
    notifyListeners();
  }

  bool isEmailSelected(int idx) {
    return _selectedEmails.contains(idx);
  }

  Future<bool> setMessagesSeen({bool isSeen = true, List<int>? items}) async {
    if (!(currentMailClient?.isConnected ?? true)) return false;

    // ignore: prefer_if_null_operators
    List<int> lst = items == null ? _selectedEmails.toList() : items;
    try {
      List<MimeMessage> msgs =
          _emailMessages.whereIndexed((int idx, MimeMessage mm) => lst.contains(idx) && mm.isSeen != isSeen).toList();
      if (msgs.isEmpty) return false;

      if (isSeen) {
        await currentMailClient!.markSeen(MessageSequence.fromMessages(msgs));
      } else {
        await currentMailClient!.markUnseen(MessageSequence.fromMessages(msgs));
      }

      for (MimeMessage msg in msgs) {
        msg.isSeen = isSeen;
      }

      if ((currentMailClient!.selectedMailbox?.isInbox ?? false) && unreadMessages != null) {
        unreadMessages = unreadMessages! + (isSeen ? -msgs.length : msgs.length);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  Future<String?> moveMessages(Mailbox target, {List<int>? items}) async {
    if (!(currentMailClient?.isConnected ?? true)) return "No Mailbox connected";
    String? errMsg;
    // ignore: prefer_if_null_operators
    List<int> lst = items == null ? List<int>.from(_selectedEmails) : items;
    int unseen = 0;

    try {
      List<MimeMessage> msgs = _emailMessages.whereIndexed((int idx, MimeMessage mm) => lst.contains(idx)).toList();
      if (msgs.isEmpty) return "List is Empty";

      await currentMailClient!.moveMessages(MessageSequence.fromMessages(msgs), target);
      for (MimeMessage msg in msgs) {
        if (msg.guid != null) _emailMessagesMap.remove(msg.guid!);
      }
      lst.sort((int a, int b) => b.compareTo(a)); //sort reverse
      for (int i in lst) {
        if (!_emailMessages[i].isSeen) unseen++;
        _emailMessages.removeAt(i);
      }
      unselectEmail(null);
      if (totalMessageCount != null) totalMessageCount = _emailMessages.length;
      notifyListeners();

      if (unseen > 0 && (currentMailClient!.selectedMailbox?.isInbox ?? false) && unreadMessages != null) {
        unreadMessages = unreadMessages! - unseen;
      }
    } catch (e) {
      errMsg = e.toString();
    }
    return errMsg;
  }

  Future<String?> copyMessages(Mailbox target, {List<int>? items}) async {
    if (!(currentMailClient?.isConnected ?? true)) return "No Mailbox connected";
    String? errMsg;
    // ignore: prefer_if_null_operators
    List<int> lst = items == null ? List<int>.from(_selectedEmails) : items;
    int unseen = 0;

    try {
      List<MimeMessage> msgs = _emailMessages.whereIndexed((int idx, MimeMessage mm) => lst.contains(idx)).toList();
      if (msgs.isEmpty) return "List is Empty";
      await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
          .uidCopy(MessageSequence.fromMessages(msgs), targetMailbox: target);
    } catch (e) {
      errMsg = e.toString();
    }
    return errMsg;
  }

  Future<String?> deleteMessages({List<int>? items, bool deletePermanent = false}) async {
    if (!(currentMailClient?.isConnected ?? true)) return "No Mailbox connected";
    String? errMsg;
    // ignore: prefer_if_null_operators
    List<int> lst = items == null ? List<int>.from(_selectedEmails) : items;
    int unseen = 0;

    try {
      List<MimeMessage> msgs = _emailMessages.whereIndexed((int idx, MimeMessage mm) => lst.contains(idx)).toList();
      if (msgs.isEmpty) return "List is Empty";

      if (currentMailClient!.selectedMailbox?.isTrash ?? false) {
        await currentMailClient!.markDeleted(MessageSequence.fromMessages(msgs));
      } else {
        if (deletePermanent) {
          await currentMailClient!.markDeleted(MessageSequence.fromMessages(msgs));
        }
        await currentMailClient!.deleteMessages(MessageSequence.fromMessages(msgs));
      }
      for (MimeMessage msg in msgs) {
        if (msg.guid != null) _emailMessagesMap.remove(msg.guid!);
      }
      lst.sort((int a, int b) => b.compareTo(a)); //sort reverse
      for (int i in lst) {
        if (!_emailMessages[i].isSeen) unseen++;
        _emailMessages.removeAt(i);
      }
      unselectEmail(null);
      if (totalMessageCount != null) totalMessageCount = _emailMessages.length;
      notifyListeners();

      if (unseen > 0 && (currentMailClient!.selectedMailbox?.isInbox ?? false) && unreadMessages != null) {
        unreadMessages = unreadMessages! - unseen;
      }
    } catch (e) {
      errMsg = e.toString();
    }
    return errMsg;
  }

  Future<void> createMailbox(Mailbox? parentMb, String mailboxName) async {
    await currentMailClient?.createMailbox(mailboxName, parentMailbox: parentMb);
    mailboxTree = await currentMailClient?.listMailboxesAsTree(createIntermediate: false, order: []);

    notifyListeners();
  }

  Future<void> renameMailbox(Mailbox? mb, String mailboxName) async {
    if (mb == null) return;
    await (currentMailClient?.lowLevelIncomingMailClient as ImapClient?)?.renameMailbox(mb, mailboxName);
    await currentMailClient?.listMailboxes(order: []); //necessary to reload mailbox cache
    mailboxTree = await currentMailClient?.listMailboxesAsTree(createIntermediate: false, order: []);
    notifyListeners();
  }

  Future<void> deleteMailbox(Mailbox mb) async {
    await currentMailClient?.deleteMailbox(mb);
    mailboxTree = await currentMailClient?.listMailboxesAsTree(createIntermediate: false, order: []);

    notifyListeners();
  }

  Future<void> emptyMailbox(Mailbox mb) async {
    await currentMailClient?.deleteAllMessages(mb, expunge: true); //always delete finally
    // mailboxTree = await currentMailClient?.listMailboxesAsTree(createIntermediate: false, order: []);

    notifyListeners();
  }

  Future<void> refreshMessages({bool inboxOnly = false}) async {
    if (currentMailClient?.selectedMailbox == null) {
      return;
    }

    if (inboxOnly && !(currentMailClient?.selectedMailbox?.isInbox ?? false)) {
      return;
    }
    _isSilent = true;
    try {
      _emailMessages.clear();
      await currentMailClient!.selectMailbox(currentMailClient!.selectedMailbox!);
      await listMailboxMessages(currentMailClient!.selectedMailbox);
      while (_emailMessages.length < _lastEmailMessageIndex) {
        await getNextPage(_lastEmailMessageIndex);
      }
    } finally {
      _isSilent = false;
      notifyListeners();
    }
  }

  MimeMessage getMessage(int index) {
    if (index > (_lastEmailMessageIndex ?? 0)) _lastEmailMessageIndex = index;

    if (index >= _emailMessages.length) {
      if (_currentMessageSequence!.hasNext && processingState != MailProcessingState.busy) getNextPage(index);
      // return MimeMessage.fromEnvelope(Envelope(date: null, subject: "", sender: MailAddress("", "")));
      return MimeMessage()
        ..sequenceId = -42
        ..uid = -42;
    }

    return _emailMessages[index];
  }

  void updateMessage(int index, MimeMessage msg) {
    if (index >= _emailMessages.length) return;
    _emailMessages[index] = msg;
    notifyListeners();
  }

  Future<void> getNextPage(int minIdx) async {
    if (!_currentMessageSequence!.hasNext) return;
    processingState = MailProcessingState.busy;

    // List<MimeMessage> msgPage = await currentMailClient!.fetchMessagesNextPage(
    //   _currentMessageSequence!,
    //   fetchPreference: FetchPreference.envelope,
    // );

    //Workaround for missing emails on envelope econding errors
    MessageSequence seqPage = _currentMessageSequence!.next();
    // FetchImapResult imapRes = await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
    //     .fetchMessages(seqPage, "(RFC822.HEADER FLAGS BODYSTRUCTURE)");
    FetchImapResult imapRes = await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
        .uidFetchMessages(seqPage, "(RFC822.HEADER FLAGS BODYSTRUCTURE)");

    for (MimeMessage mm in imapRes.messages) {
      if (mm.isDeleted || mm.headers == null) continue;
      _setMimeMessageEnvelope(mm);
      if (!_emailMessagesMap.containsKey(mm.guid)) {
        _emailMessages.insertSorted(
          mm,
          (a, b) => (b.envelope?.date?.compareTo(a.envelope?.date ?? DateTime.now()) ?? 0),
        );
        if (mm.guid != null) {
          _emailMessagesMap[mm.guid!] = mm;
        }
      }
    }
    if (backgroundCheckInfo != null && currentMailClient!.selectedMailbox!.isInbox) {
      await setBackgroundNotificationInfo(_emailMessages[0].decodeDate()?.millisecondsSinceEpoch, backgroundCheckInfo!);
    }

    if (!_currentMessageSequence!.hasNext) totalMessageCount = _emailMessages.length;

    // isBusy = false;
    processingState = MailProcessingState.done;
    notifyListeners();
  }

  Future<void> setBackgroundNotificationInfo(int? timestamp, Map<String, dynamic> bgInfo) async {
    if (timestamp == null || bgInfo["newestKnownTimestamp"] >= timestamp) return;
    int? bgTimestamp = await sharedPreferencesAsync.getInt(bgInfo["accountHashSettingsKey"]);
    if (bgTimestamp != null && bgTimestamp > timestamp) {
      bgInfo["newestKnownTimestamp"] = bgTimestamp;
    } else {
      await sharedPreferencesAsync.setInt(bgInfo["accountHashSettingsKey"], timestamp);
      bgInfo["newestKnownTimestamp"] = timestamp;
    }
  }

  void _setMimeMessageEnvelope(MimeMessage mm) {
    try {
      mm.envelope = Envelope(
        date: mm.decodeDate(),
        subject: mm.decodeSubject(),
        from: mm.from,
        // sender: mm.sender ?? (mm.from?.isEmpty ?? true ? null : mm.from?.first),
        sender: mm.sender ?? mm.from?.first,
        replyTo: (mm.replyTo == null || mm.replyTo!.isEmpty) ? mm.from : mm.replyTo,
        to: mm.to,
        cc: mm.cc,
        bcc: mm.bcc,
        messageId: mm.getHeaderValue("Message-ID"),
      );

      if (mm.guid == null && mm.uid != null) mm.guid = getGuid(mm.uid!);

      NavService.navKey.currentContext
          ?.read<SettingsProvider>()
          .emailSuggestions
          .addAll([...mm.to ?? [], ...mm.cc ?? [], ...mm.bcc ?? [], ...mm.from ?? []].map<String>((m) => m.toString()));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> addMimeMessageByUid(int? uid, {bool inboxOnly = true}) async {
    if (uid == null || (inboxOnly && !(currentMailClient?.selectedMailbox?.isInbox ?? false))) return;
    try {
      // await currentMailClient!.selectInbox(); //refresh
      await (currentMailClient!.lowLevelIncomingMailClient as ImapClient).noop(); //Status refresh
      FetchImapResult imapRes = await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
          .uidFetchMessage(uid, "(RFC822.HEADER FLAGS BODYSTRUCTURE)");

      if (imapRes.messages.isNotEmpty) {
        _setMimeMessageEnvelope(imapRes.messages.first);
        if (!_emailMessagesMap.containsKey(imapRes.messages.first.guid)) {
          _emailMessages.insertSorted(
            imapRes.messages.first,
            (a, b) => (b.envelope?.date?.compareTo(a.envelope?.date ?? DateTime.now()) ?? 0),
          );
          if (imapRes.messages.first.guid != null) {
            _emailMessagesMap[imapRes.messages.first.guid!] = imapRes.messages.first;
          }
        }
        if (totalMessageCount != null) totalMessageCount = _emailMessages.length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  MimeMessage? findMessageFromListByUid(int? uid) {
    if (uid == null) return null;
    return _emailMessages.singleWhereOrNull((MimeMessage mm) => mm.uid == uid);
  }

  int getGuid(int uid, {MailClient? mailClient}) {
    mailClient ??= currentMailClient;
    return MimeMessage.calculateGuid(
        email: mailClient?.account.email ?? '',
        encodedMailboxName: mailClient?.selectedMailbox?.encodedName ?? '',
        mailboxUidValidity: mailClient?.selectedMailbox?.uidValidity ?? 0,
        messageUid: uid);
  }

  Future<void> closeCurrentMailAccount({bool withNotify = false}) async {
    if (currentMailClient != null && currentMailClient!.isConnected) {
      await currentMailClient!.disconnect();
    }
    await _currentConnectionLostEventSubscription?.cancel();

    await cancelPolling();

    _selectedEmails.clear();
    _emailMessages.clear();
    _emailMessagesMap.clear();
    totalMessageCount = null;
    lastErrorMessage = '';
    currentEmail = null;
    currentMailClient = null;
    currentPollingClient = null;
    currentMailAccount = null;
    currentMailAccountModel = null;
    _unreadMessages = null;
    mailboxTree = null;
    _currentMessageSequence = null;
    _pollingLoadEventSubscription = null;
    backgroundCheckInfo = null;
    processingState = MailProcessingState.uninitialized;
    if (withNotify) {
      notifyListeners();
    }
  }

  Future<int?> getUnseen(MailClient client) async {
    int? unseen;
    try {
      if (!client.isConnected || !(client.selectedMailbox?.isInbox ?? true)) return null;
      SearchImapResult? result = await (client.lowLevelIncomingMailClient as ImapClient).uidSearchMessages(
          searchCriteria: 'UNSEEN', returnOptions: [ReturnOption.count()], responseTimeout: Duration(minutes: 1));

      if (result.count != null && result.count! > 0) {
        unseen = result.count;
      } else if (result.matchingSequence != null && result.matchingSequence!.isNotEmpty) {
        unseen = result.matchingSequence!.length;
      }

      return unseen;
    } catch (e) {
      debugPrint(e.toString());
    }

    return unseen;
  }

  bool isYahoo(String host) {
    return host.contains('yahoo.com') || host.contains('ymail.com');
  }

  Future<void> initializePolling() async {
    try {
      await cancelPolling();
      if (currentMailAccount == null) return;
      currentPollingClient = MailClient(currentMailAccount!,
          isLogEnabled: false,
          refresh: currentMailAccount!.incoming.authentication.authentication == Authentication.oauth2
              ? MailAccountController().refreshOauthToken
              : null);
      await currentPollingClient?.connect(timeout: Duration(seconds: currentMailAccountModel?.timeout ?? 20));
      await currentPollingClient?.selectInbox();
      _pollingLoadEventSubscription = currentPollingClient?.eventBus.on<MailLoadEvent>().listen((e) async {
        addMimeMessageByUid(e.message.uid);
        Map<String, dynamic> payload = {
          "uid": e.message.uid,
          "accountHash":
              (await MailAccountController().mailAccountModelByEmail(currentPollingClient!.account.email))?.id,
          //"accountEmail": currentPollingClient?.account.email,
          "mailbox": currentPollingClient?.selectedMailbox?.encodedName,
          "uidValidity": currentPollingClient?.selectedMailbox?.uidValidity,
          "guid": getGuid(e.message.uid!, mailClient: currentPollingClient!),
        };
        await AndroidNotifyer().showMessageNotification(e.message, payload: jsonEncode(payload));
        if (unreadMessages == null) {
          unreadMessages = 1;
        } else {
          unreadMessages = unreadMessages! + 1;
        }

        if (backgroundCheckInfo != null) {
          await setBackgroundNotificationInfo(e.message.decodeDate()?.millisecondsSinceEpoch, backgroundCheckInfo!);
        }
      });

      _pollingConnectionLostEventSubscription =
          currentPollingClient?.eventBus.on<MailConnectionLostEvent>().listen((_) {
        cancelPolling();
      });

      if (currentPollingClient != null) {
        ImapServerInfo pollingServer = (currentPollingClient?.lowLevelIncomingMailClient as ImapClient).serverInfo;
        if (isYahoo(pollingServer.host) || !pollingServer.supportsIdle) {
          await currentPollingClient!.startPolling(
            const Duration(minutes: 2),
          );
        } else {
          await currentPollingClient!.startPolling();
        }
      }
    } catch (ex) {
      debugPrint("Failed to run Polling $ex");
      cancelPolling();
    }
  }

  Future<void> cancelPolling() async {
    if (currentPollingClient?.isPolling() ?? false) {
      await currentPollingClient?.stopPolling();
    }
    await _pollingConnectionLostEventSubscription?.cancel();
    await _pollingLoadEventSubscription?.cancel();

    await currentPollingClient?.disconnect();
  }

  Future<bool> pauseConnection() async {
    await cancelPolling();
    await _currentConnectionLostEventSubscription?.cancel();
    await currentMailClient?.disconnect();

    return !(currentMailClient?.isConnected ?? true);
  }

  Future<void> resumeConnection({bool ignoreError = false}) async {
    try {
      if (currentMailClient != null && !currentMailClient!.isConnected) {
        _currentConnectionLostEventSubscription =
            currentMailClient!.eventBus.on<MailConnectionLostEvent>().listen((_) async {
          await onCurrentConnectionLostEvent();
        });
        await currentMailClient!.connect();
        if (currentMailClient!.isConnected && currentMailClient!.selectedMailbox != null) {
          //have to use imapClient, MailClient throws exception
          await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
              .selectMailbox(currentMailClient!.selectedMailbox!);
        }
      }
      initializePolling();
    } catch (_) {
      if (!ignoreError && !(currentMailClient?.isConnected ?? true)) {
        await closeCurrentMailAccount(withNotify: true);
      }
    }
  }

  Future<void> onReconnectTimer() async {
    try {
      await resumeConnection(ignoreError: true);
      if (!currentMailClient!.isConnected) {
        Timer(const Duration(seconds: 1), onReconnectTimer);
      } else {
        NavService.navKey.currentContext?.read<ConnectionProvider>().netAvailable = true;
      }
    } catch (_) {
      Timer(const Duration(seconds: 1), onReconnectTimer);
    }
  }

  Future<void> onCurrentConnectionLostEvent() async {
    if (!(NavService.navKey.currentContext?.read<ConnectionProvider>().netAvailable ?? false)) {
      return;
    }
    await NavService.navKey.currentContext?.read<ConnectionProvider>().setNetAvailable(false);
    Timer(const Duration(seconds: 1), onReconnectTimer);
  }

  Future<void> initMailAccount(String email, {bool openInbox = true}) async {
    await closeCurrentMailAccount();
    processingState = MailProcessingState.busy;
    currentEmail = email;
    notifyListeners();

    try {
      currentMailAccountModel = await MailAccountController().mailAccountModelByEmail(email);
      if (currentMailAccountModel == null) throw Exception("Unable to find Account configuration");
      if (NavService.navKey.currentContext?.read<SettingsProvider>().generalPrefs["permanentNotificationAccount"] ==
          currentMailAccountModel!.email) {
        backgroundCheckInfo = {
          "accountHashSettingsKey": "recent_${currentMailAccountModel!.id}",
          "newestKnownTimestamp": 0,
        };
      }

      currentMailAccount = await currentMailAccountModel!.mailAccountWithSecrets;

      currentMailClient = MailClient(currentMailAccount!,
          isLogEnabled: false,
          refresh: currentMailAccount!.incoming.authentication.authentication == Authentication.oauth2
              ? MailAccountController().refreshOauthToken
              : null);

      await currentMailClient!.connect(timeout: Duration(seconds: currentMailAccountModel?.timeout ?? 20));

      _currentConnectionLostEventSubscription =
          currentMailClient!.eventBus.on<MailConnectionLostEvent>().listen((_) async {
        await onCurrentConnectionLostEvent();
      });

      mailboxTree = await currentMailClient?.listMailboxesAsTree(createIntermediate: false, order: []);
      mbEmail = currentEmail;
      notifyListeners();

      if (openInbox) {
        Mailbox? inbox = currentMailClient?.getMailbox(MailboxFlag.inbox);
        if (inbox != null && currentMailClient != null) {
          await currentMailClient!.selectMailbox(inbox);
          await listMailboxMessages(inbox);
        }
      }
      if (pollingEnabled) {
        initializePolling();
      }
    } on MailException catch (e) {
      MailAccountController().resetTemporaryPassword(currentMailAccount?.email);
      currentMailClient = null;
      processingState = MailProcessingState.error;
      lastErrorMessage = 'Error connecting Mailserver:\n($e)';
      notifyListeners();
    } on MessageException catch (e) {
      processingState = MailProcessingState.message;
      currentMailClient = null;
      lastErrorMessage = e.toString();
      notifyListeners();
    } catch (ex) {
      processingState = MailProcessingState.error;
      currentMailClient = null;
      lastErrorMessage = 'Unknown error occured:\n($ex)';
      notifyListeners();
    }
  }

  Future<void> listMailboxMessages(Mailbox? mb) async {
    if (mb == null) return;
    processingState = MailProcessingState.busy;

    _emailMessages.clear();
    _emailMessagesMap.clear();
    _selectedEmails.clear();
    totalMessageCount = null;
    notifyListeners();

    try {
      // await guardMailClient();
      // if (!(currentMailClient?.isConnected ?? true)) {
      //   await currentMailClient!.connect();
      // }

      if (currentMailClient!.selectedMailbox != mb) {
        await currentMailClient!.selectMailbox(mb);
      }

      if (currentMailClient!.selectedMailbox!.messagesExists <= 0) {
        processingState = MailProcessingState.message;
        lastErrorMessage = LocaleKeys.txt_mailbox_is_empty.tr(namedArgs: {
          'mailbox': mb.encodedName,
        });
        totalMessageCount = 0;
        notifyListeners();
        return;
      }

      if (currentMailClient?.selectedMailbox?.isInbox ?? false) {
        // _unreadMessages = await getUnseen(currentMailClient!);

        getUnseen(currentMailClient!).then((int? unseen) => _unreadMessages = unseen);
      }
      // SearchImapResult res = await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
      //     .uidSearchMessages(searchCriteria: 'ALL', returnOptions: [ReturnOption.all()]);

      SearchImapResult res = await (currentMailClient!.lowLevelIncomingMailClient as ImapClient)
          .uidSearchMessages(searchCriteria: 'UNDELETED');

      _currentMessageSequence = PagedMessageSequence(
        res.matchingSequence!,
        // MessageSequence.fromRange(1, currentMailClient!.selectedMailbox!.messagesExists),
        pageSize: pageSize,
      );
      if (!_currentMessageSequence!.hasNext) totalMessageCount = _emailMessages.length;

      await getNextPage(0);
    } on MailException catch (e) {
      MailAccountController().resetTemporaryPassword(currentMailAccount?.email);
      processingState = MailProcessingState.error;
      lastErrorMessage = 'Error connecting Mailserver:\n($e)';
      notifyListeners();
    } on MessageException catch (e) {
      processingState = MailProcessingState.message;
      lastErrorMessage = e.toString();
      notifyListeners();
    } catch (ex) {
      processingState = MailProcessingState.error;
      lastErrorMessage = 'Unknown error occured:\n($ex)';
      notifyListeners();
    }
  }
}
