import 'package:slow_mail/utils/common_import.dart';
import 'dart:ffi';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_html/enough_mail_html.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/mail/html_email_transformer.dart';
import 'package:slow_mail/pgp/pgp_email.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/html_escape.dart' as esc;
import 'package:slow_mail/image_link_dialog.dart';
import 'package:slow_mail/webview_inapp.dart';
import 'package:slow_mail/ui/email_chip_input.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:easy_localization/easy_localization.dart';

final _sendMailFormKey = GlobalKey<FormBuilderState>();

enum MailComposerType { empty, reply, replyall, forward }

class AttachmentLocalInfo {
  bool isContentInfo = false;
  File? fi;
  ContentInfo? ci;
  String name;
  final String? _mimeType;

  AttachmentLocalInfo.fromFile(this.fi)
      : name = p.basename(fi!.path),
        _mimeType = lookupMimeType(fi!.path);

  AttachmentLocalInfo.fromContentInfo(this.ci)
      : name = ci!.fileName ?? "unknown.bin",
        _mimeType = ci.mediaType?.sub.mediaType.text,
        isContentInfo = true;

  String get mimeType => _mimeType ?? 'application/octet-stream';

  Image get image {
    String strImage = switch (mimeType) {
      "application/pdf" => "assets/pdf.png",
      _ => "assets/attachment.png",
    };

    if (mimeType.startsWith("image/")) {
      strImage = "assets/image.png";
    } else if (mimeType.startsWith("text/")) {
      strImage = "assets/text.png";
    } else if (mimeType.startsWith("audio/")) {
      strImage = "assets/audio.png";
    }

    return Image.asset(
      strImage,
      width: 20,
      color: NavService.navKey.currentContext!.isDarkMode ? Colors.white : null,
    );
  }

  Future<bool> addToBuilder(MessageBuilder msgBuilder, {MimeMessage? originalMsg, MailClient? mc}) async {
    if (fi != null) {
      await msgBuilder.addFile(fi!, MediaType.fromText(mimeType));
    } else if (ci != null) {
      if (originalMsg == null || mc == null) return false;
      //attach real copies otherwise original message could be damaged
      MimePart? mp = await originalMsg.fetchAttachmentPart(mc, ci!);
      if (mp == null || mp.mimeData == null) return false;
      if (mp.mimeData is TextMimeData) {
        MimePart mpCopy = MimePart();
        mpCopy.mimeData = TextMimeData((mp.mimeData as TextMimeData).text, containsHeader: mp.mimeData!.containsHeader);
        mpCopy.headers = mp.headers;
        mpCopy.parse();
        msgBuilder.addPart(mimePart: mpCopy, disposition: mp.getHeaderContentDisposition());
      } else {
        msgBuilder.addPart(mimePart: mp);
      }
    }
    return true;
  }

  void delete() {
    if (fi != null) fi!.deleteSync();
  }
}

class UnknownEmbedBuilder extends EmbedBuilder {
  UnknownEmbedBuilder();

  @override
  String get key => 'unknown';

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    return Text("");
  }
}

class EmailEditor extends StatefulWidget {
  final MailClient mailClient;
  final MimeMessage? baseMsg;

  final MailComposerType composerType;
  final bool isExternalBlocked;

  const EmailEditor(this.composerType, this.mailClient, {this.baseMsg, this.isExternalBlocked = true, super.key});

  @override
  State<EmailEditor> createState() => _EmailEditorState();
}

class _EmailEditorState extends State<EmailEditor> {
  bool _hasPgp = false;
  bool _canEncrypt = false;
  final outsideTapManager = OutsideTapManager();

  final _fabKey = GlobalKey<ExpandableFabState>();
  final List<AttachmentLocalInfo> _attachments = <AttachmentLocalInfo>[];
  final _attachExpandController = ExpansibleController();
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();
  final _addressExpandController = ExpansibleController();
  HtmlEmailTransformer? _htmlEmailTransformer;
  bool _isLoaded = false;
  bool _isSending = false;
  bool _isEditorExpanded = false;
  bool _isOriginViewExpanded = false;
  final double _editPadding = 15;
  final double _editMaxHeight = 80;

  MimeMessage? _baseMsg;
  String? _editPlaceholder;
  String? _prefixMsg;
  bool _isExternalBlocked = true;
  bool _isOriginIncluded = true;

  final QuillController _controller = () {
    return QuillController.basic(
        config: QuillControllerConfig(
      clipboardConfig: QuillClipboardConfig(
        enableExternalRichPaste: true,
      ),
    ));
  }();

  @override
  void initState() {
    _baseMsg = widget.baseMsg;
    _isExternalBlocked = widget.isExternalBlocked;
    _addressExpandController.expand();
    _editorFocusNode.addListener(
      () {
        if (_editorFocusNode.hasFocus) _addressExpandController.collapse();
      },
    );

    _controller.document = Document();
    _isLoaded = true;

    if (widget.composerType == MailComposerType.empty) {
      _editPlaceholder = "${LocaleKeys.hint_write_your_email.tr()} ...";
    } else {
      _htmlEmailTransformer = HtmlEmailTransformer();
      _editPlaceholder = widget.composerType == MailComposerType.forward
          ? "${LocaleKeys.hint_write_your_message.tr()} ..."
          : "${LocaleKeys.hint_write_your_reply.tr()} ...";

      // if (widget.composerType == MailComposerType.forward && (_baseMsg?.hasAttachments() ?? false)) {
      // _attachments.addAll(_baseMsg!.findContentInfo().map<AttachmentLocalInfo>((ContentInfo ci) {
      if (widget.composerType == MailComposerType.forward && (_baseMsg?.hasAllAttachments ?? false)) {
        _attachments.addAll(_baseMsg!.allAttachmentContentInfos.map<AttachmentLocalInfo>((ContentInfo ci) {
          return AttachmentLocalInfo.fromContentInfo(ci);
        }).toList());
      }
    }
    _prefixMsg = _getPrefixMsg(_baseMsg);

    super.initState();

    _hasPgp = PgpEmail.getInstance().publicEmailKeyMap.isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    _editorScrollController.dispose();
    _editorFocusNode.dispose();
    _addressExpandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //final emailState = context.watch<EmailProvider>();
    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => outsideTapManager.handle(details),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          bottomNavigationBar: (_attachments.isNotEmpty)
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
                              LocaleKeys.attachments.plural(_attachments.length),
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
                                ..._attachments.map<Widget>((AttachmentLocalInfo ci) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    color: Theme.of(context).canvasColor,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 4,
                                      children: [
                                        ci.image,
                                        Text(ci.name),
                                        InkWell(
                                            onTap: () {
                                              ci.delete();
                                              setState(() {
                                                _attachments.remove(ci);
                                              });
                                            },
                                            child: Icon(Icons.delete_outline)),
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
          appBar: AppBar(
            elevation: 1,
            shadowColor: context.watch<ConnectionProvider>().netAvailable ? null : Theme.of(context).colorScheme.error,
            title: Badge(
              isLabelVisible: !context.watch<ConnectionProvider>().netAvailable,
              offset: Offset(20, -4),
              label: Text(
                LocaleKeys.msg_no_network.tr(),
                style: TextStyle(fontSize: 14),
              ),
              child: Text(
                switch (widget.composerType) {
                  MailComposerType.reply => LocaleKeys.tt_reply_to.tr(),
                  MailComposerType.replyall => "${LocaleKeys.tt_reply_all.tr()}:",
                  MailComposerType.forward => "${LocaleKeys.tt_forward.tr()}:",
                  _ => LocaleKeys.tt_email_new.tr(),
                },
              ),
            ),
          ),
          floatingActionButtonLocation: ExpandableFab.location,
          floatingActionButton:
              (!_isEditorExpanded && !_isOriginViewExpanded && context.watch<ConnectionProvider>().netAvailable)
                  ? ExpandableFab(
                      key: _fabKey,
                      openButtonBuilder: FloatingActionButtonBuilder(
                        size: 56,
                        builder: (BuildContext context, void Function()? onPressed, Animation<double> progress) {
                          return FloatingActionButton(
                            heroTag: null,
                            onPressed: () async {
                              try {
                                if (canSendEncrypted()) {
                                  final state = _fabKey.currentState;
                                  if (state != null && !state.isOpen) {
                                    state.toggle();
                                  }
                                } else {
                                  await sendEmail(false);
                                }
                              } catch (_) {}
                            },
                            tooltip: LocaleKeys.tt_send_emal.tr(),
                            child: _isSending
                                ? CircularProgressIndicator()
                                : Image.asset(
                                    "assets/send_email.png",
                                    width: 25,
                                    color: context.isDarkMode ? Colors.white : null,
                                  ),
                          );
                        },
                      ),
                      children: [
                        FloatingActionButton.extended(
                          heroTag: null,
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          label: Text(LocaleKeys.send_encrypted.tr()),
                          icon: Image.asset(
                            "assets/email_encrypted.png",
                            width: 25,
                            color: context.isDarkMode ? Colors.white : null,
                          ),
                          onPressed: () async {
                            await sendEmail(true);
                          },
                        ),
                        FloatingActionButton.extended(
                          heroTag: null,
                          label: Text(LocaleKeys.send_unencrypted.tr()),
                          icon: Image.asset(
                            "assets/send_email.png",
                            width: 25,
                            color: context.isDarkMode ? Colors.white : null,
                          ),
                          onPressed: () async {
                            await sendEmail(false);
                          },
                        ),
                      ],
                    )
                  : null,
          body: PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
              },
              child: _isLoaded
                  ? Column(
                      children: [
                        // if (!_isEditorExpanded && !_isOriginViewExpanded) sendMailForm(),
                        Visibility(
                          maintainState: true,
                          visible: (!_isEditorExpanded && !_isOriginViewExpanded),
                          child: emailForm(),
                        ),
                        // if (!_isOriginViewExpanded)
                        Visibility(
                          visible: !_isOriginViewExpanded,
                          child: Container(
                            foregroundDecoration: BoxDecoration(color: const Color.fromARGB(31, 158, 158, 158)),
                            child: QuillSimpleToolbar(
                              controller: _controller,
                              config: QuillSimpleToolbarConfig(
                                customButtons: [
                                  QuillToolbarCustomButtonOptions(
                                    icon: Icon(_isEditorExpanded ? Icons.close_fullscreen : Icons.open_in_full),
                                    onPressed: () {
                                      setState(() {
                                        _isEditorExpanded = !_isEditorExpanded;
                                        _isOriginViewExpanded = false;
                                      });
                                    },
                                  ),
                                  QuillToolbarCustomButtonOptions(
                                    icon: const Icon(Icons.attach_file),
                                    onPressed: () async {
                                      String? filePath = await FlutterFileDialog.pickFile(
                                        params: OpenFileDialogParams(
                                          copyFileToCacheDir: true,
                                        ),
                                      );
                                      if (filePath == null) return;
                                      File f = File(filePath);

                                      setState(() {
                                        _attachments.add(AttachmentLocalInfo.fromFile(f));
                                      });
                                    },
                                  ),
                                ],

                                toolbarIconCrossAlignment: WrapCrossAlignment.start,
                                // toolbarSectionSpacing: 0.1,
                                toolbarRunSpacing: 0.1,
                                embedButtons: FlutterQuillEmbeds.toolbarButtons(
                                    videoButtonOptions: null,
                                    cameraButtonOptions: null,
                                    imageButtonOptions:
                                        QuillToolbarImageButtonOptions(imageButtonConfig: QuillToolbarImageConfig(
                                      onRequestPickImage: (context) async {
                                        return await showDialog(
                                          context: context,
                                          builder: (_) => ImageLinkDialog(),
                                        );
                                      },
                                    ))),
                                multiRowsDisplay: true,
                                showColorButton: false,
                                showBackgroundColorButton: false,
                                showSubscript: false,
                                showSuperscript: false,
                                showJustifyAlignment: true,
                                showClipboardPaste: true,
                                showAlignmentButtons: true,
                                toolbarIconAlignment: WrapAlignment.start,
                                buttonOptions: QuillSimpleToolbarButtonOptions(
                                  linkStyle: QuillToolbarLinkStyleButtonOptions(
                                    validateLink: (link) {
                                      return true;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Visibility(
                          visible: !_isOriginViewExpanded,
                          child: Expanded(
                            child: QuillEditor(
                              focusNode: _editorFocusNode,
                              scrollController: _editorScrollController,
                              controller: _controller,
                              config: QuillEditorConfig(
                                showCursor: true,
                                embedBuilders: [
                                  ...FlutterQuillEmbeds.editorBuilders(),
                                ],
                                unknownEmbedBuilder: UnknownEmbedBuilder(), // FlutterQuillEmbeds.editorBuilders()[1],
                                placeholder: _editPlaceholder,
                                padding: EdgeInsets.all(_editPadding),
                              ),
                            ),
                          ),
                        ),
                        // if (_prefixMsg != null && !_isEditorExpanded && !_isOriginViewExpanded)
                        //   Padding(
                        //     padding: EdgeInsetsGeometry.symmetric(horizontal: _editPadding),
                        //     child: Text(
                        //       _prefixMsg!,
                        //       softWrap: true,
                        //     ),
                        //   ),
                        Visibility(
                          visible: (widget.composerType != MailComposerType.empty && !_isEditorExpanded),
                          child: Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: _editPadding),
                              child: _isOriginIncluded
                                  ? WebViewInApp(
                                      initialContent: _htmlEmailTransformer?.transformHtml(
                                              _baseMsg?.getMimeHTML() ?? '',
                                              _prefixMsg ?? '',
                                              widget.composerType == MailComposerType.forward) ??
                                          '',
                                      isHtml: true,
                                      isExternalBlocked: _isExternalBlocked,
                                      supports: [
                                        WebViewFeature.blockExternal,
                                        WebViewFeature.hasFullscreen,
                                        WebViewFeature.originIncluded
                                      ],
                                      callback: (arg) {
                                        setState(() {
                                          _isOriginViewExpanded = arg.isFullScreen;
                                          _isEditorExpanded = false;
                                          _isOriginIncluded = arg.isOriginIncluded;
                                          _isExternalBlocked = arg.isExternalBlocked;
                                        });
                                      },
                                    )
                                  : SizedBox(),
                            ),
                          ),
                        ),
                        // else
                        //   Center(child: CircularProgressIndicator())
                      ],
                    )
                  : Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }

  bool canSendEncrypted() {
    if (!_hasPgp) return false;
    if (!validateEmailForm()) throw Exception("Validation Error");

    final receivers = [
      ..._sendMailFormKey.currentState!.instantValue["from"] ?? [],
      ..._sendMailFormKey.currentState!.instantValue["to"] ?? [],
      ..._sendMailFormKey.currentState!.instantValue["cc"] ?? [],
      ..._sendMailFormKey.currentState!.instantValue["bcc"] ?? [],
    ];

    for (MailAddress adr in receivers) {
      if (!PgpEmail.getInstance().publicEmailKeyMap.containsKey(adr.email)) {
        return false;
      }
    }

    return true;
  }

  bool validateEmailForm() {
    if (_isSending || _sendMailFormKey.currentState == null || !_sendMailFormKey.currentState!.validate()) {
      return false;
    }

    if ((_sendMailFormKey.currentState!.instantValue["to"] as List<MailAddress>).isEmpty &&
        (_sendMailFormKey.currentState!.instantValue["cc"] as List<MailAddress>).isEmpty &&
        (_sendMailFormKey.currentState!.instantValue["bcc"] as List<MailAddress>).isEmpty) {
      _sendMailFormKey.currentState?.fields['to']?.invalidate(LocaleKeys.err_mailaddress_missing.tr());
      return false;
    }

    return true;
  }

  Future<void> sendEmail([bool encrypted = false]) async {
    if (!validateEmailForm()) throw Exception("Validation Error");

    setState(() {
      _isSending = true;
    });
    try {
      final deltaJson = _controller.document.toDelta().toJson();
      QuillDeltaToHtmlConverter converter = QuillDeltaToHtmlConverter(
        List.castFrom(deltaJson),
        ConverterOptions.forEmail(),
      );
      String contents = converter.convert();
      MessageBuilder? msg = await buildMessageContent(contents, _controller.document.toPlainText(), encrypted);
      if (msg != null) {
        // await widget.mailClient.sendMessageBuilder(msgBuilder);
        await widget.mailClient.sendMessageBuilder(msg);
        if (widget.composerType == MailComposerType.reply || widget.composerType == MailComposerType.replyall) {
          widget.mailClient.flagMessage(_baseMsg!, isAnswered: true);
        } else if (widget.composerType == MailComposerType.forward) {
          widget.mailClient.flagMessage(_baseMsg!, isForwarded: true);
        }
        succesMessage(LocaleKeys.email_sent_successfull.tr());
      } else {
        throw Exception(LocaleKeys.err_unable_build_message.tr());
      }
    } catch (err) {
      errorMessage("${LocaleKeys.err_unable_send_message.tr()} (${err.toString()})");
    }

    setState(() {
      _isSending = false;
    });
  }

  Widget emailForm() {
    double fieldWidth = MediaQuery.of(context).size.width > mobileWidth
        ? MediaQuery.of(context).size.width * 0.5 - 35
        : MediaQuery.of(context).size.width - 40;

    return FormBuilder(
      key: _sendMailFormKey,
      child: Expansible(
        controller: _addressExpandController,
        headerBuilder: (context, animation) => GestureDetector(
          onTap: () => _addressExpandController.isExpanded
              ? _addressExpandController.collapse()
              : _addressExpandController.expand(),
          child: Padding(
            padding: EdgeInsetsGeometry.only(bottom: 15, left: 15),
            child: Row(
              spacing: 15,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.expand),
                Text(
                  LocaleKeys.open_address_fields.tr(),
                  style: TextTheme.of(context).titleMedium?.copyWith(decoration: TextDecoration.underline) ??
                      TextStyle(decoration: TextDecoration.underline, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Flex(
                  direction: Axis.horizontal,
                )
              ],
            ),
          ),
        ),
        expansibleBuilder: (context, header, body, animation) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [if (!_addressExpandController.isExpanded) header, body],
        ),

        bodyBuilder: (context, animation) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).scaffoldBackgroundColor, // Theme.of(context).canvasColor,
              child: Padding(
                padding: EdgeInsetsGeometry.all(15),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 20,
                  runSpacing: 20,
                  runAlignment: WrapAlignment.start,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: FormBuilderTextField(
                              decoration: InputDecoration(
                                labelText: LocaleKeys.from.tr(),
                              ),
                              valueTransformer: (adr) =>
                                  adr == null ? <MailAddress>[] : <MailAddress>[MailAddress.parse(adr)],
                              validator: (value) => MailValidator.isStringValidEmail(value!)
                                  ? null
                                  : LocaleKeys.err_invalid_email_address.tr(),
                              name: 'from',
                              initialValue: context.read<EmailProvider>().currentMailAccount?.fromAddress.toString(),
                            ),
                          ),
                          // MenuAnchor(
                          //   builder: (BuildContext context, MenuController controller, Widget? child) {
                          //     return InkWell(
                          //       onTap: () => controller.isOpen ? controller.close() : controller.open(),
                          //       child: Icon(
                          //         controller.isOpen ? Icons.expand_less : Icons.expand_more,
                          //         size: 28,
                          //       ),
                          //     );
                          //   },
                          //   style: MenuStyle(
                          //     alignment: Alignment.bottomCenter,
                          //     backgroundColor: WidgetStateProperty.all<Color>(Colors.white),
                          //   ),
                          //   menuChildren: [
                          //     ...MailAccountController().mailAddresses.values.map((item) {
                          //       return MenuItemButton(
                          //         onPressed: () {
                          //           _sendMailFormKey.currentState?.fields["from"]?.didChange(item.toString());
                          //         },
                          //         child: Text(item.toString()),
                          //       );
                          //     })
                          //   ],
                          // ),
                        ],
                      ),
                    ),
                    Container(
                      width: fieldWidth,
                      constraints: BoxConstraints(maxHeight: _editMaxHeight),
                      child: EmailChipInput(
                        name: "to",
                        manager: outsideTapManager,
                        hintText: LocaleKeys.hint_enter_email.tr(),
                        decoration: InputDecoration(labelText: LocaleKeys.to.tr()),
                        initialValue: switch (widget.composerType) {
                          MailComposerType.reply => _baseMsg!.replyToAddresses(),
                          MailComposerType.replyall => _baseMsg!.replyToAllAddresses(),
                          _ => []
                        },
                      ),
                    ),
                    Container(
                      width: fieldWidth,
                      constraints: BoxConstraints(maxHeight: _editMaxHeight),
                      child: EmailChipInput(
                        hintText: LocaleKeys.hint_enter_email.tr(),
                        decoration: InputDecoration(labelText: LocaleKeys.cc.tr()),
                        name: 'cc',
                        manager: outsideTapManager,
                        initialValue:
                            widget.composerType == MailComposerType.replyall ? _baseMsg!.replyToAllCCAddresses() : [],
                      ),
                    ),
                    Container(
                      width: fieldWidth,
                      constraints: BoxConstraints(maxHeight: _editMaxHeight),
                      child: EmailChipInput(
                        hintText: LocaleKeys.hint_enter_email.tr(),
                        decoration: InputDecoration(labelText: LocaleKeys.bcc.tr()),
                        name: 'bcc',
                        manager: outsideTapManager,
                      ),
                    ),
                    SizedBox(
                      width: 2 * fieldWidth + 20,
                      child: FormBuilderTextField(
                        decoration: InputDecoration(labelText: LocaleKeys.subject.tr()),
                        name: 'subject',
                        initialValue: switch (widget.composerType) {
                          MailComposerType.reply ||
                          MailComposerType.replyall =>
                            "${MailConventions.defaultReplyAbbreviation}: ${_baseMsg!.decodeSubject()}",
                          MailComposerType.forward =>
                            "${MailConventions.defaultForwardAbbreviation}: ${_baseMsg!.decodeSubject()}",
                          _ => '',
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        //),
        //],
      ),
    );
  }

  String getCombinedHTML(MimeMessage? baseMime, String msgHTML) {
    return HtmlEmailTransformer.combineHtmlEmail(
        msgHTML,
        _htmlEmailTransformer?.transformHtml(
                baseMime?.getMimeHTML() ?? '', _prefixMsg ?? '', widget.composerType == MailComposerType.forward) ??
            '');
  }

  Future<MessageBuilder?> buildMessageContent(String html, String? txt, bool encrypted) async {
    if (txt == null) txt == HtmlToPlainTextConverter.convert(html);
    String? outPlainText;
    String? outHtml;
    MessageBuilder msgBuilder;

    switch (widget.composerType) {
      case MailComposerType.reply || MailComposerType.replyall:
        msgBuilder = MessageBuilder.prepareReplyToMessage(
            _baseMsg!, _sendMailFormKey.currentState!.instantValue["from"][0],
            quoteOriginalText: false);
        outPlainText = _isOriginIncluded
            ? "$txt\n${MessageBuilder.quotePlainText("${_prefixMsg ?? ''}\n", _baseMsg?.decodeTextPlainPart() ?? '')}"
            : txt;
        outHtml = _isOriginIncluded ? getCombinedHTML(_baseMsg, html) : HtmlEmailTransformer.combineHtmlEmail(html, '');

        break;
      case MailComposerType.forward:
        msgBuilder = MessageBuilder.prepareForwardMessage(_baseMsg!,
            forwardAttachments: false,
            from: _sendMailFormKey.currentState!.instantValue["from"][0],
            quoteMessage: false);
        outPlainText = _isOriginIncluded
            ? "$txt\n${MessageBuilder.quotePlainText("${_prefixMsg ?? ''}\n", _baseMsg?.decodeTextPlainPart() ?? '')}"
            : txt;
        outHtml =
            _isOriginIncluded ? getCombinedHTML(_baseMsg!, html) : HtmlEmailTransformer.combineHtmlEmail(html, '');
        break;
      case MailComposerType.empty:
        msgBuilder = MessageBuilder();
        outPlainText = txt;
        outHtml = getCombinedHTML(null, html);
        break;
    }

    if (_attachments.isNotEmpty) {
      msgBuilder.setContentType(MediaType.fromSubtype(MediaSubtype.multipartMixed));
      msgBuilder.addMultipartAlternative(plainText: outPlainText, htmlText: outHtml);
      for (AttachmentLocalInfo ai in _attachments) {
        if (ai.isContentInfo) {
          await ai.addToBuilder(msgBuilder, originalMsg: _baseMsg, mc: widget.mailClient);
        } else {
          await ai.addToBuilder(msgBuilder);
        }
      }
    } else {
      msgBuilder.setContentType(MediaType.fromSubtype(MediaSubtype.multipartAlternative));
      msgBuilder.addTextPlain(outPlainText ?? '');
      msgBuilder.addTextHtml(outHtml ?? '');
    }

    msgBuilder.messageId = MessageBuilder.createMessageId(widget.mailClient.account.outgoing.serverConfig.hostname);

    msgBuilder
      ..from = _sendMailFormKey.currentState!.instantValue["from"]
      ..to = _sendMailFormKey.currentState!.instantValue["to"]
      ..cc = _sendMailFormKey.currentState!.instantValue["cc"]
      ..bcc = _sendMailFormKey.currentState!.instantValue["bcc"]
      ..subject = _sendMailFormKey.currentState!.instantValue["subject"];

    if (!encrypted) {
      return msgBuilder;
    }

    final keyList = getKeyList([
      ...msgBuilder.from ?? [],
      ...msgBuilder.to ?? [],
      ...msgBuilder.cc ?? [],
      ...msgBuilder.bcc ?? [],
    ], msgBuilder.from!.first);

    if (keyList == null) {
      throw Exception("Missing public keys of receiver(s)");
    }
    MimeMessage encMMsg = msgBuilder.buildMimeMessage();
    StringBuffer msgBuf = StringBuffer();
    encMMsg.render(msgBuf);

    String? encMsg = await PgpEmail.getInstance().encryptText(msgBuf.toString(), keyList.pubKeys, keyList.privKey,
        keyList.privKeyPassword, msgBuilder.bcc?.isNotEmpty ?? false);

    MessageBuilder encContainer = MessageBuilder.prepareMessageWithMediaType(MediaSubtype.multipartEncrypted);
    PartBuilder pb = encContainer.addText(
      "Version: 1",
      mediaType: MediaType.fromSubtype(MediaSubtype.applicationPgpEncrypted),
    );
    pb.addHeader("Content-Description", "PGP/MIME version identification");

    pb = encContainer.addText(
      encMsg!,
    );

    pb.contentType = ContentTypeHeader.from(MediaType.fromSubtype(MediaSubtype.applicationOctetStream))
      ..setParameter("name", "encrypted.asc");
    pb.addHeader("Content-Description", "OpenPGP encrypted message");
    pb.addHeader("Content-Disposition", "inline; filename=\"encrypted.asc\"");

    encContainer
      ..from = _sendMailFormKey.currentState!.instantValue["from"]
      ..to = _sendMailFormKey.currentState!.instantValue["to"]
      ..cc = _sendMailFormKey.currentState!.instantValue["cc"]
      ..bcc = _sendMailFormKey.currentState!.instantValue["bcc"]
      ..subject = _sendMailFormKey.currentState!.instantValue["subject"];

    return encContainer;
  }

  ({List<String> pubKeys, String? privKey, String? privKeyPassword})? getKeyList(
      List<MailAddress> encryptEmail, MailAddress? signEmail) {
    SettingsProvider s = context.read<SettingsProvider>();
    List<String> pubKeys = [];
    String? privKey;
    String? privKeyPassword;

    for (MailAddress adr in encryptEmail) {
      if (PgpEmail.getInstance().publicEmailKeyMap.containsKey(adr.email)) {
        pubKeys.add(
            PgpEmail.getInstance().publicKeyList[PgpEmail.getInstance().publicEmailKeyMap[adr.email]]!["armoredKey"]);
      }
    }
    if (pubKeys.length != encryptEmail.length) return null;

    if (signEmail != null) {
      if (PgpEmail.getInstance().privateEmailKeyMap.containsKey(signEmail.email)) {
        privKey = PgpEmail.getInstance().privateKeyList[PgpEmail.getInstance().privateEmailKeyMap[signEmail.email]]
            ?["armoredKey"];
        privKeyPassword = PgpEmail.getInstance()
            .privateKeyList[PgpEmail.getInstance().privateEmailKeyMap[signEmail.email]]?["privateKeyPassword"];
        if (privKeyPassword == '') privKeyPassword = null;
      }
    }
    return (pubKeys: pubKeys, privKey: privKey, privKeyPassword: privKeyPassword);
  }

  String _getPrefixMsg(MimeMessage? msg) {
    if (msg == null) return '';
    if (widget.composerType == MailComposerType.forward) {
      return MessageBuilder.fillTemplate(MailConventions.defaultForwardHeaderTemplate, msg);
    } else {
      String replyHeaderTemplate = "---------- Am <date_de> schrieb <from>: ----------";

      return MessageBuilder.fillTemplate(replyHeaderTemplate, msg,
          parameters: {"date_de": DateFormat.yMd('de').format(msg.decodeDate() ?? DateTime.now())});
    }
  }
}
