import 'package:slow_mail/utils/common_import.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:slow_mail/webview_inapp.dart';
import 'package:slow_mail/email_edit.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/mail/html_email_transformer.dart';

class MimeEmailViewer extends StatefulWidget {
  final MimeMessage mimeMessage;
  final MailClient mailClient;
  final int idxEmail;

  const MimeEmailViewer(this.mimeMessage, this.mailClient, this.idxEmail, {super.key});

  @override
  State<MimeEmailViewer> createState() => _MimeEmailViewerState();
}

class _MimeEmailViewerState extends State<MimeEmailViewer> {
  final _attachExpandController = ExpansibleController();
  bool _hasAttachments = false;
  late Future<String> _loadedMimeMessageHTML;
  late MimeMessage mimeMessage;
  bool _isExternalBlocked = true;
  final HtmlEmailTransformer _htmlEmailTransformer = HtmlEmailTransformer();

  @override
  void initState() {
    mimeMessage = widget.mimeMessage;
    _hasAttachments = mimeMessage.hasAllAttachments;
    _loadedMimeMessageHTML = getEmailHTML(context);
    _attachExpandController.collapse();
    super.initState();
    if (context.read<SettingsProvider>().generalPrefs["markAsReadOnOpen"] ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await context.read<EmailProvider>().setMessagesSeen(isSeen: true, items: <int>[widget.idxEmail]);
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          elevation: 1,
          actionsPadding: EdgeInsets.only(right: 40),
          shadowColor: context.watch<ConnectionProvider>().netAvailable ? null : Theme.of(context).colorScheme.error,
          title: Badge(
            isLabelVisible: !context.watch<ConnectionProvider>().netAvailable,
            offset: Offset(20, -4),
            label: SizedBox(
              height: 26,
              child: Padding(
                padding: EdgeInsetsGeometry.directional(start: 5, end: 5),
                child: InkWell(
                  onTap: () => context.read<ConnectionProvider>().enableNetIfConnected(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.msg_no_network.tr(),
                        style: TextStyle(fontSize: 14),
                      ),
                      Padding(
                        padding: EdgeInsetsGeometry.directional(start: 4, end: 4),
                        child: Icon(
                          Icons.refresh,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: Text(mimeMessage.decodeSubject() ?? ""),
          ),
          actions: [
            AbsorbPointer(
              absorbing: !context.watch<ConnectionProvider>().netAvailable,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.forward),
                    tooltip: LocaleKeys.tt_forward.tr(),
                    onPressed: () async {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => EmailEditor(
                              MailComposerType.forward,
                              context.read<EmailProvider>().currentMailClient!,
                              baseMsg: mimeMessage,
                              isExternalBlocked: _isExternalBlocked,
                              // key: UniqueKey(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.reply),
                    tooltip: LocaleKeys.tt_reply_to.tr(),
                    onPressed: () async {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => EmailEditor(
                              MailComposerType.reply,
                              context.read<EmailProvider>().currentMailClient!,
                              baseMsg: mimeMessage,
                              isExternalBlocked: _isExternalBlocked,
                              // key: UniqueKey(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.reply_all),
                    tooltip: LocaleKeys.tt_reply_all.tr(),
                    onPressed: () async {
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (context) => EmailEditor(
                              MailComposerType.replyall,
                              context.read<EmailProvider>().currentMailClient!,
                              baseMsg: mimeMessage,
                              isExternalBlocked: _isExternalBlocked,
                              // key: UniqueKey(),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(
                    height: 20,
                    child: VerticalDivider(),
                  ),
                  if (!widget.mimeMessage.isSeen)
                    IconButton(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      tooltip: LocaleKeys.tt_mark_read.tr(),
                      onPressed: () async {
                        await context
                            .read<EmailProvider>()
                            .setMessagesSeen(isSeen: true, items: <int>[widget.idxEmail]);
                        setState(() {});
                      },
                    ),
                  if (widget.mimeMessage.isSeen)
                    IconButton(
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      tooltip: LocaleKeys.tt_mark_unread.tr(),
                      onPressed: () async {
                        await context
                            .read<EmailProvider>()
                            .setMessagesSeen(isSeen: false, items: <int>[widget.idxEmail]);
                        setState(() {});
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: LocaleKeys.tt_delete_emails.tr(),
                    onPressed: () async {
                      if (!context.mounted) return;
                      Map<String, Object?>? res = await yesNoDialog<dynamic>(
                          title: "${LocaleKeys.txt_delete.tr()}?",
                          checkboxTitle: "${LocaleKeys.lbl_delete_permanent.tr()}!",
                          content: "${LocaleKeys.txt_really_delete.tr()}?",
                          strNo: LocaleKeys.cancel.tr(),
                          strYes: LocaleKeys.ok.tr(),
                          retYes: true,
                          retNo: false);
                      if (res == null || res["button"] == false) return;

                      String? error = (res["checkbox"] == false)
                          // ignore: use_build_context_synchronously
                          ? await context.read<EmailProvider>().deleteMessages(items: <int>[widget.idxEmail])
                          // ignore: use_build_context_synchronously
                          : await context
                              .read<EmailProvider>()
                              .deleteMessages(items: <int>[widget.idxEmail], deletePermanent: true);
                      if (error != null) {
                        errorMessage(error);
                      } else {
                        if (context.mounted) Navigator.pop(context);
                      }

                      EasyLoading.dismiss();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _hasAttachments //(mimeMessage.hasAttachments())
            ? Card(
                child: Padding(
                  padding: EdgeInsetsGeometry.symmetric(vertical: 5, horizontal: 10),
                  child: Expansible(
                    controller: _attachExpandController,
                    headerBuilder: (context, animation) => InkWell(
                      onTap: () => _attachExpandController.isExpanded
                          ? _attachExpandController.collapse()
                          : _attachExpandController.expand(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _attachExpandController.isExpanded ? Icon(Icons.expand_less) : Icon(Icons.expand_more),
                          Text(
                            // LocaleKeys.attachments.plural(mimeMessage.findContentInfo(complete: false).length),
                            LocaleKeys.attachments.plural(mimeMessage.allAttachmentContentInfos.length),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Icon(
                            Icons.attach_file,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                    expansibleBuilder: (context, header, body, animation) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [header, body],
                    ),
                    bodyBuilder: (context, animation) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                      child: Align(
                          alignment: AlignmentGeometry.topLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              // ...mimeMessage.findContentInfo(complete: false).map<Widget>((ContentInfo ci) {
                              ...mimeMessage.allAttachmentContentInfos.map<Widget>((ContentInfo ci) {
                                return Container(
                                  padding: EdgeInsets.only(left: 10),
                                  color: Theme.of(context).canvasColor, // Colors.white,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          await openAttachmentWith(ci);
                                        },
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          spacing: 4,
                                          children: [
                                            Image.asset(attachmentIcon(ci), width: 20),
                                            Text(ci.fileName ?? LocaleKeys.file_unnamed.tr()),
                                          ],
                                        ),
                                      ),
                                      MenuAnchor(
                                        builder: (BuildContext context, MenuController controller, Widget? child) {
                                          return IconButton(
                                            onPressed: () {
                                              controller.isOpen ? controller.close() : controller.open();
                                            },
                                            icon: const Icon(Icons.more_vert),
                                            tooltip: LocaleKeys.tt_open_menu.tr(),
                                          );
                                        },
                                        menuChildren: [
                                          MenuItemButton(
                                            onPressed: () async {
                                              await openAttachmentWith(ci);
                                            },
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                spacing: 8,
                                                children: [
                                                  Icon(Icons.open_with),
                                                  Text(
                                                    LocaleKeys.open_with.tr(),
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                ]),
                                          ),
                                          MenuItemButton(
                                            onPressed: () async {
                                              await saveAttachment(ci);
                                            },
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                spacing: 8,
                                                children: [
                                                  Icon(Icons.save_alt),
                                                  Text('Save as ...'),
                                                ]),
                                          ),
                                          MenuItemButton(
                                            onPressed: () {
                                              shareAttachment(ci);
                                            },
                                            child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                spacing: 8,
                                                children: [
                                                  Icon(Icons.share),
                                                  Text('Share'),
                                                ]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          )),
                    ),
                  ),
                ),
              )
            : null,
        body: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
          child: Padding(
            padding: EdgeInsetsGeometry.directional(start: 20, end: 20, top: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 5, children: [
              SelectionArea(
                child: Card(
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      spacing: 4,
                      children: [
                        Expanded(
                          child: Column(
                            spacing: 4,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              headerLine("${LocaleKeys.from.tr()}: ", "${mimeMessage.from?.join(', ')}"),
                              if (mimeMessage.to != null && mimeMessage.to!.isNotEmpty)
                                headerLine("${LocaleKeys.to.tr()}: ", "${mimeMessage.to?.join(', ')}"),
                              if (mimeMessage.cc != null && mimeMessage.cc!.isNotEmpty)
                                headerLine("${LocaleKeys.cc.tr()}: ", "${mimeMessage.cc?.join(', ')}"),
                              if (mimeMessage.bcc != null && mimeMessage.bcc!.isNotEmpty)
                                headerLine("${LocaleKeys.bcc.tr()}: ", "${mimeMessage.bcc?.join(', ')}"),
                              if (mimeMessage.replyTo != null && !mimeMessage.from.containsAll(mimeMessage.replyTo))
                                headerLine("${LocaleKeys.tt_reply_to.tr()}: ", "${mimeMessage.replyTo?.join(', ')}"),
                              headerLine("${LocaleKeys.subject.tr()}: ", mimeMessage.decodeSubject() ?? '(no Subject)'),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mimeMessage.emailDisplayDate()),
                            Row(
                              spacing: 5,
                              children: [
                                if (mimeMessage.getHeaderValue("X-EncryptedBase") == "true")
                                  Tooltip(
                                    message: LocaleKeys.tt_is_encrypted.tr(),
                                    child: Image.asset(
                                      "assets/email_encrypted.png",
                                      width: 24,
                                      color: context.isDarkMode ? Colors.white : null,
                                    ),
                                  ),
                                if (mimeMessage.getHeaderValue("X-SignedBy") != null)
                                  Tooltip(
                                    message: LocaleKeys.tt_is_signed.tr(),
                                    child: Image.asset(
                                      "assets/signed_pen.png",
                                      width: 20,
                                      color: context.isDarkMode ? Colors.white : null,
                                    ),
                                  ),
                                if (mimeMessage.getHeaderValue("X-SignatureVerified") == "true")
                                  Tooltip(
                                    message: LocaleKeys.tt_signed_verified.tr(),
                                    child: Icon(Icons.check),
                                  ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder(
                    future: _loadedMimeMessageHTML,
                    builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}',
                                  style: TextTheme.of(context).titleMedium?.copyWith(color: Colors.red)));
                        } else if (snapshot.hasData) {
                          return WebViewInApp(
                            initialContent: _htmlEmailTransformer.sanitizeHtml(snapshot.data ?? ''),
                            //initialContent: snapshot.data!,
                            isHtml: true,
                            isExternalBlocked: _isExternalBlocked,
                            supports: [WebViewFeature.blockExternal],
                            callback: (arg) {
                              _isExternalBlocked = arg.isExternalBlocked;
                            },
                          );
                        } else {
                          return Center(child: Text(LocaleKeys.missing_data.tr()));
                        }
                      }
                      return Center(child: Text(LocaleKeys.missing_data.tr()));
                    }),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String attachmentIcon(ContentInfo ci) {
    if (ci.isImage) return "assets/image.png";
    if (ci.isApplication && ci.mediaType?.sub == MediaSubtype.applicationPdf) return "assets/pdf.png";
    if (ci.isApplication) return "assets/application.png";
    if (ci.isAudio) return "assets/audio.png";
    if (ci.isMessage) return "assets/email_sent.png";
    if (ci.isText) return "assets/text.png";
    return "assets/attachment.png";
  }

  Future<void> openAttachmentWith(ContentInfo ci) async {
    try {
      EasyLoading.show();
      Uint8List? content = await mimeMessage.getBinaryPart(widget.mailClient, ci.fetchId);
      if (content == null) throw Exception(LocaleKeys.err_load_attachment.tr());

      Directory tmp = await getTemporaryDirectory();
      String localPath = p.join(tmp.path, ci.fileName ?? LocaleKeys.file_unnamed.tr());
      File f = File(localPath);
      await f.writeAsBytes(content, flush: true);

      OpenResult res = await OpenAppFile.open(localPath);
      if (res.type != ResultType.done) {
        f.delete();
        throw Exception(res.message);
      }
    } catch (ex) {
      errorMessage("Could not open Attachment: ${ex.toString()}");
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> saveAttachment(ContentInfo ci) async {
    try {
      EasyLoading.show();
      Uint8List? content = await mimeMessage.getBinaryPart(widget.mailClient, ci.fetchId);
      if (content == null) throw Exception(LocaleKeys.err_load_attachment.tr());

      await FlutterFileDialog.saveFile(
          params: SaveFileDialogParams(
        data: content,
        fileName: ci.fileName ?? LocaleKeys.file_unnamed.tr(),
        mimeTypesFilter: [ci.mediaType?.text ?? 'application/octet-stream'],
      ));
    } catch (ex) {
      errorMessage("Could not save Attachment: ${ex.toString()}");
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<void> shareAttachment(ContentInfo ci) async {
    try {
      EasyLoading.show();
      Uint8List? content = await mimeMessage.getBinaryPart(widget.mailClient, ci.fetchId);
      if (content == null) throw Exception(LocaleKeys.err_load_attachment.tr());

      final params = ShareParams(
          files: [XFile.fromData(content, mimeType: ci.mediaType?.text ?? 'application/octet-stream')],
          fileNameOverrides: ci.fileName == null ? null : [ci.fileName!]);

      await SharePlus.instance.share(params);
    } catch (ex) {
      errorMessage("Could not share Attachment: ${ex.toString()}");
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<String> getEmailHTML(BuildContext context) async {
    // _loadedMimeMessage = await widget.mailClient.fetchMessageContents(mimeMessage);
    //return _loadedMimeMessage!.getMimeHTML();
    MimeMessage? encMsg = await mimeMessage.fetchTextHtml(widget.mailClient);
    if (encMsg != null) {
      if (context.mounted) {
        context.read<EmailProvider>().updateMessage(widget.idxEmail, encMsg);
      }
      mimeMessage = encMsg;
      setState(() {
        _hasAttachments = mimeMessage.hasAllAttachments;
      });
    }
    return mimeMessage.getMimeHTML();
  }

  Text headerLine(String prefix, String content) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: prefix, style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold)),
          TextSpan(text: content)
        ],
      ),
    );
  }
}
