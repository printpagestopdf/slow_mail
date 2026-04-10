import 'package:slow_mail/utils/common_import.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:path/path.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:slow_mail/email_edit.dart';
import 'package:slow_mail/mime_viewer.dart';
import 'package:slow_mail/ui/dotted_progress.dart';
import 'package:slow_mail/settings_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/ui/tree_view.dart' as tv;
import 'package:enough_mail/enough_mail.dart';

/// TableView.
class InfiniteTable extends StatefulWidget {
  const InfiniteTable({super.key});

  @override
  State<InfiniteTable> createState() => _InfiniteTableState();
}

class _InfiniteTableState extends State<InfiniteTable> {
  final ScrollController verticalScrollController = ScrollController();
  final int pinnedRowCount = 1;
  double _dateFieldWidth = 120;
  double _textHeight = 20;
  bool _isWide = false;
  double _scaledFontSize = 14;
  final MenuController _fontSizeMenuController = MenuController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _scaledFontSize = context.watch<SettingsProvider>().fontScale * Theme.of(context).textTheme.bodyMedium!.fontSize!;
    _isWide = MediaQuery.of(context).size.width > mobileWidth;
    _dateFieldWidth = context.getTextWidth("88.88.8888 88:88",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: _scaledFontSize));
    _textHeight = context
        .getTextSize(_isWide ? "WWWWW" : "WWWWWW\nXXXXXXX",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: _scaledFontSize))
        .height;
    return SafeArea(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        },
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  (context.watch<EmailProvider>().currentEmail ?? '') +
                      ((context.watch<EmailProvider>().currentMailClient?.selectedMailbox?.encodedName != null)
                          ? " (${context.watch<EmailProvider>().currentMailClient!.selectedMailbox!.encodedName})"
                          : ""),
                  style: TextTheme.of(context).titleSmall,
                ),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: 0,
                toolbarHeight: 40,
                backgroundColor: Colors.transparent,
                leading: MenuAnchor(
                  controller: _fontSizeMenuController,
                  builder: (BuildContext context, MenuController controller, Widget? child) {
                    return IconButton(
                      icon: Icon(Icons.format_size),
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    );
                  },
                  menuChildren: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 3,
                      child: Slider(
                        divisions: 15,
                        min: 1.0,
                        max: 2.5,
                        value: context.watch<SettingsProvider>().fontScale,
                        onChanged: (value) => context.read<SettingsProvider>().fontScale = value,
                        onChangeEnd: (value) {
                          context.read<SettingsProvider>().fontScale = value;
                          context.read<SettingsProvider>().saveGeneralPrefs();
                          _fontSizeMenuController.close();
                        },
                      ),
                    ),
                  ],
                ),
                // leading: IconButton(
                //   icon: const Icon(Icons.settings),
                //   tooltip: LocaleKeys.tt_settings.tr(),
                //   onPressed: () => Navigator.push(
                //     context,
                //     MaterialPageRoute<void>(
                //       builder: (context) => SettingsPage(),
                //     ),
                //   ),
                // ),
                actions: [
                  AbsorbPointer(
                    absorbing: !context.watch<ConnectionProvider>().netAvailable,
                    child: Row(
                      children: [
                        IconButton(
                          icon: Image.asset(
                            "assets/mail_new.png",
                            width: 32,
                            color: context.isDarkMode ? Colors.white : null,
                          ),
                          tooltip: LocaleKeys.tt_new_email.tr(),
                          onPressed: context.watch<EmailProvider>().currentMailClient == null
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (context) => EmailEditor(
                                            MailComposerType.empty, context.read<EmailProvider>().currentMailClient!)),
                                  );
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.drive_folder_upload),
                          tooltip: LocaleKeys.tt_move_to.tr(),
                          onPressed: context.watch<EmailProvider>().countSelectedEmails == 0
                              ? null
                              : () {
                                  _moveToFolder(context);
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.mark_email_read_outlined),
                          tooltip: LocaleKeys.tt_mark_read.tr(),
                          onPressed: context.watch<EmailProvider>().countSelectedEmails == 0
                              ? null
                              : () async {
                                  await context.read<EmailProvider>().setMessagesSeen(isSeen: true);
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.mark_email_unread_outlined),
                          tooltip: LocaleKeys.tt_mark_unread.tr(),
                          onPressed: context.watch<EmailProvider>().countSelectedEmails == 0
                              ? null
                              : () async {
                                  await context.read<EmailProvider>().setMessagesSeen(isSeen: false);
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: LocaleKeys.tt_delete_emails.tr(),
                          onPressed: context.watch<EmailProvider>().countSelectedEmails == 0
                              ? null
                              : () async {
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

                                  EasyLoading.show();
                                  double pos = verticalScrollController.position.extentBefore;
                                  String? error = (res["checkbox"] == false)
                                      // ignore: use_build_context_synchronously
                                      ? await context.read<EmailProvider>().deleteMessages()
                                      // ignore: use_build_context_synchronously
                                      : await context.read<EmailProvider>().deleteMessages(deletePermanent: true);

                                  if (error != null) {
                                    errorMessage(error);
                                  } else {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      verticalScrollController.jumpTo(pos);
                                    });
                                  }

                                  EasyLoading.dismiss();
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                  child: switch (
                      context.select<EmailProvider, MailProcessingState>((EmailProvider p) => p.processingState)) {
                MailProcessingState.busy => Center(child: CircularProgressIndicator()),
                MailProcessingState.error => Center(
                    child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: Card(
                          color: Theme.of(context).colorScheme.error,
                          child: Padding(
                            padding: EdgeInsetsGeometry.all(20),
                            child: Text(
                              context.read<EmailProvider>().lastErrorMessage,
                              style: TextTheme.of(context).titleLarge?.copyWith(color: Colors.white),
                            ),
                          ),
                        )),
                  ),
                MailProcessingState.message => Center(
                    child: FractionallySizedBox(
                        widthFactor: 0.9,
                        child: Card(
                          color: Theme.of(context).colorScheme.primary,
                          child: Padding(
                            padding: EdgeInsetsGeometry.all(20),
                            child: Text(
                              context.read<EmailProvider>().lastErrorMessage,
                              style: TextTheme.of(context).titleLarge,
                            ),
                          ),
                        )),
                  ),
                MailProcessingState.uninitialized => Center(
                    child: Text(
                      LocaleKeys.no_mailaccount_selected.tr(),
                      style: TextTheme.of(context).titleLarge,
                    ),
                  ),
                MailProcessingState.done => AbsorbPointer(
                    absorbing: !context.watch<ConnectionProvider>().netAvailable,
                    child: TableView.builder(
                      pinnedRowCount: pinnedRowCount,
                      verticalDetails:
                          ScrollableDetails(direction: AxisDirection.down, controller: verticalScrollController),
                      // pinnedColumnCount: 4,
                      cellBuilder: _buildCell,
                      columnCount: null, //_columnCount,
                      columnBuilder: _buildSpanColumn,
                      // rowCount: context.read<EmailProvider>().totalMessageCount,
                      rowBuilder: (int row) => _buildSpanRow(context, row),
                      diagonalDragBehavior: DiagonalDragBehavior.weightedEvent,
                    ),
                  ),
              }),
            ], //),
          ),
        ),
      ),
    );
  }

  void _moveToFolder(BuildContext context) {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          final size = MediaQuery.of(context).size;
          final moveFormKey = GlobalKey<FormBuilderState>();
          return AlertDialog(
            actionsAlignment: MainAxisAlignment.spaceBetween,
            title: Text(LocaleKeys.title_move_to.tr()),
            content: SizedBox(
              width: size.width * 0.5,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            tv.TreeView(
                              root: context.read<EmailProvider>().mailboxTree,
                              onTextTap: (Mailbox? mb) async {
                                Navigator.pop(context);
                                if (mb == null || !context.mounted) return;
                                moveFormKey.currentState!.save();

                                EasyLoading.show();
                                double pos = verticalScrollController.position.extentBefore;
                                String? error = (moveFormKey.currentState!.fields["isMove"]!.value == true)
                                    // ignore: use_build_context_synchronously
                                    ? await context.read<EmailProvider>().moveMessages(mb)
                                    // ignore: use_build_context_synchronously
                                    : await context.read<EmailProvider>().copyMessages(mb);
                                if (error != null) {
                                  errorMessage(error);
                                } else {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    verticalScrollController.jumpTo(pos);
                                  });
                                }

                                EasyLoading.dismiss();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              IntrinsicWidth(
                child: FormBuilder(
                  key: moveFormKey,
                  child: FormBuilderCheckbox(
                    initialValue: false,
                    name: "isMove",
                    title: Text(LocaleKeys.lbl_move_instead_copy.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocaleKeys.cancel.tr()),
              ),
            ],
          );
        });
  }

  TableViewCell _getTableHeaderCell(BuildContext context, TableVicinity vicinity) {
    return switch (vicinity.column) {
      0 => TableViewCell(
          child: GestureDetector(
            onTap: () => context.read<EmailProvider>().unselectEmail(null),
            child: Padding(
              padding: EdgeInsetsGeometry.only(left: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                spacing: 0,
                children: [
                  Tooltip(
                    message: LocaleKeys.tt_deselect_all.tr(),
                    child: Icon(
                      Icons.radio_button_unchecked,
                      size: 20,
                    ),
                  ),
                  const Icon(
                    fontWeight: FontWeight.bold,
                    Icons.attach_file,
                    size: 18,
                  ),
                  Tooltip(
                    richMessage: TextSpan(
                      children: [
                        TextSpan(
                          text: LocaleKeys.forwarded.tr(),
                        ),
                        WidgetSpan(
                          child: Image.asset(
                            "assets/forwarded.png",
                            width: 18,
                            height: 18,
                            color: const Color.fromARGB(143, 244, 67, 54),
                          ),
                        ),
                        TextSpan(
                          text: LocaleKeys.replied.tr(),
                        ),
                        WidgetSpan(
                          child: Image.asset(
                            "assets/replied.png",
                            width: 18,
                            height: 18,
                            color: const Color.fromARGB(117, 33, 149, 243),
                          ),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Image.asset(
                          "assets/forwarded.png",
                          width: 18,
                          height: 9,
                          color: const Color.fromARGB(143, 244, 67, 54),
                        ),
                        Image.asset("assets/replied.png",
                            width: 18, height: 9, color: const Color.fromARGB(117, 33, 149, 243)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      1 => TableViewCell(
          child: Text(LocaleKeys.subject.tr(),
              overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize)),
        ),
      2 => TableViewCell(
          child: !context.read<EmailProvider>().currentMailClient!.selectedMailbox!.isSent
              ? Text(LocaleKeys.from.tr(), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize))
              : Text(LocaleKeys.recipients.tr(),
                  overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize)),
        ),
      3 => TableViewCell(
          child:
              Text(LocaleKeys.date.tr(), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize)),
        ),
      4 => TableViewCell(
          child: context.read<EmailProvider>().currentMailClient!.selectedMailbox!.isSent
              ? Text(LocaleKeys.from.tr(), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize))
              : Text(LocaleKeys.recipients.tr(),
                  overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: _scaledFontSize)),
        ),
      5 => TableViewCell(
          child: Tooltip(
            message: LocaleKeys.tt_is_encrypted.tr(),
            child: const Icon(
              fontWeight: FontWeight.bold,
              Icons.vpn_key_outlined,
              size: 18,
            ),
          ),
        ),
      _ => TableViewCell(child: Text("")),
    };
  }

  TableViewCell _buildCell(BuildContext context, TableVicinity vicinity) {
    if (vicinity.row == 0) {
      return _getTableHeaderCell(context, vicinity);
    }

    int currentIndex = vicinity.row - pinnedRowCount;
    try {
      MimeMessage msg = context.read<EmailProvider>().getMessage(currentIndex);

      // if ((msg.sequenceId ?? -42) == -42) {
      if ((msg.uid ?? -42) == -42) {
        return TableViewCell(
          columnMergeStart: 0,
          columnMergeSpan: 6,
          child: SizedBox(child: Center(child: DottedProgress())),
        );
      }
      return (vicinity.column > 0)
          ? TableViewCell(
              child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => MimeEmailViewer(
                      context.read<EmailProvider>().getMessage(vicinity.row - pinnedRowCount),
                      context.read<EmailProvider>().currentMailClient!,
                      vicinity.row - pinnedRowCount,
                    ),
                  ),
                );
              },
              child: _cellWidget(context, currentIndex, msg, vicinity.column),
            ))
          : TableViewCell(child: _cellWidget(context, currentIndex, msg, vicinity.column));
    } catch (ex) {
      return TableViewCell(child: Text(ex.toString()));
    }
  }

  Widget _cellWidget(BuildContext context, int currentIndex, MimeMessage msg, int column) {
    TextStyle ts = msg.isSeen
        ? TextStyle(fontSize: _scaledFontSize)
        : TextStyle(fontWeight: FontWeight.bold, fontSize: _scaledFontSize);
    return switch (column) {
      0 => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (context.read<EmailProvider>().isEmailSelected(currentIndex)) {
              context.read<EmailProvider>().unselectEmail(currentIndex);
            } else {
              context.read<EmailProvider>().selectEmail(currentIndex);
            }
          },
          onDoubleTap: () {
            context.read<EmailProvider>().selectEmailRange(currentIndex);
          },
          child: Padding(
            padding: EdgeInsetsGeometry.only(left: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              spacing: 0,
              children: [
                context.watch<EmailProvider>().isEmailSelected(currentIndex)
                    ? Icon(
                        Icons.check_circle_outline,
                        size: 20,
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        size: 20,
                      ),
                msg.hasAttachments()
                    ? const Icon(
                        fontWeight: FontWeight.bold,
                        Icons.attach_file,
                        size: 18,
                      )
                    : SizedBox(
                        width: 18,
                      ),
                Column(
                  children: [
                    msg.isForwarded
                        ? Tooltip(
                            message: LocaleKeys.tt_is_forwarded.tr(),
                            child: Image.asset(
                              "assets/forwarded.png",
                              width: 18,
                              height: 9,
                              color: const Color.fromARGB(143, 244, 67, 54),
                            ),
                          )
                        : SizedBox(
                            width: 18,
                            height: 9,
                          ),
                    msg.isAnswered
                        ? Tooltip(
                            message: LocaleKeys.tt_is_answered.tr(),
                            child: Image.asset("assets/replied.png",
                                width: 18, height: 9, color: const Color.fromARGB(117, 33, 149, 243)),
                          )
                        : SizedBox(
                            width: 18,
                            height: 9,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      1 => Tooltip(
          message: msg.decodeSubject() ?? '',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg.decodeSubject() ?? LocaleKeys.hint_no_subject.tr(), overflow: TextOverflow.ellipsis, style: ts),
              if (!_isWide)
                Text(msg.emailFrom(),
                    overflow: TextOverflow.ellipsis,
                    style: ts.copyWith(fontStyle: FontStyle.italic, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
      2 => !context.read<EmailProvider>().currentMailClient!.selectedMailbox!.isSent
          ? _getFrom(msg, ts)
          : _getRecipients(msg, ts),
      3 => Tooltip(
          message: msg.emailDisplayDate(),
          child: Align(
            alignment: AlignmentGeometry.centerStart,
            child: Text(msg.emailDisplayDate(), overflow: TextOverflow.ellipsis, style: ts),
          ),
        ),
      4 => context.read<EmailProvider>().currentMailClient!.selectedMailbox!.isSent
          ? _getFrom(msg, ts)
          : _getRecipients(msg, ts),
      5 => msg.mediaType.text == 'multipart/encrypted'
          ? const Icon(
              // fontWeight: FontWeight.bold,
              Icons.vpn_key_outlined,
              size: 18,
            )
          : SizedBox(
              width: 18,
            ),
      _ => Text(""),
    };
  }

  Widget _getRecipients(MimeMessage msg, TextStyle ts) {
    return Tooltip(
      message: msg.recipientAddresses.join(", "),
      child: Align(
        alignment: AlignmentGeometry.centerStart,
        child: Text(
          msg.recipientAddresses.join(", "),
          overflow: TextOverflow.ellipsis,
          style: ts,
          maxLines: _isWide ? 1 : 2,
        ),
      ),
    );
  }

  Widget _getFrom(MimeMessage msg, TextStyle ts) {
    return _isWide
        ? Tooltip(
            message: msg.emailFrom(),
            child: Align(
              alignment: AlignmentGeometry.centerStart,
              child: Text(msg.emailFrom(), overflow: TextOverflow.ellipsis, style: ts),
            ),
          )
        : SizedBox();
  }

  TableSpan? _buildSpanColumn(int index) {
    const double fromFieldWidth = 220;
    const double defPadding = 5;

    return switch (index) {
      0 => const TableSpan(extent: FixedSpanExtent(61), padding: SpanPadding.all(0)),
      1 => TableSpan(
          extent: CombiningSpanExtent(
              RemainingSpanExtent(),
              FixedSpanExtent(_isWide
                  ? fromFieldWidth + _dateFieldWidth + 3 * 2 * defPadding
                  : _dateFieldWidth + 2 * 2 * defPadding),
              (a, b) => a - b),
          padding: SpanPadding.all(defPadding),
        ),
      2 => _isWide
          ? const TableSpan(extent: FixedSpanExtent(fromFieldWidth), padding: SpanPadding.all(defPadding))
          : const TableSpan(extent: FixedSpanExtent(0), padding: SpanPadding.all(0)),
      // 5 => const TableSpan(extent: FixedSpanExtent(120), padding: SpanPadding.all(5)),
      3 => TableSpan(extent: FixedSpanExtent(_dateFieldWidth), padding: SpanPadding.all(defPadding)),
      4 => const TableSpan(extent: FixedSpanExtent(250), padding: SpanPadding.all(defPadding)),
      5 => const TableSpan(extent: FixedSpanExtent(18), padding: SpanPadding.all(0)),
      _ => null,
    };
  }

  TableSpan? _buildSpanRow(BuildContext context, int index) {
    if (index == 0) {
      return TableSpan(
          extent: FixedTableSpanExtent(_textHeight + 10), // FixedTableSpanExtent(20),
          // extent: FixedTableSpanExtent(20),
          padding: SpanPadding(trailing: 5, leading: 5),
          backgroundDecoration: SpanDecoration(
            border: SpanBorder(
              trailing:
                  BorderSide(color: const Color.fromARGB(83, 0, 0, 0)), /* leading: BorderSide(color: Colors.black) */
            ),
            color: Theme.of(context).highlightColor, // Colors.grey.shade200,
          ));
    }
    if (context.read<EmailProvider>().totalMessageCount != null &&
        index - pinnedRowCount >= context.read<EmailProvider>().totalMessageCount!) {
      return null;
    }
    return TableSpan(
      extent: FixedTableSpanExtent(_textHeight + 10), // FixedTableSpanExtent(20),
      // padding: SpanPadding.all(5),
      backgroundDecoration: context.read<EmailProvider>().getMessage(index - pinnedRowCount).isDeleted
          ? SpanDecoration(color: Colors.red)
          : SpanDecoration(
              color: index.isOdd
                  ? Theme.of(context).scaffoldBackgroundColor
                  : context.isDarkMode
                      ? Theme.of(context).scaffoldBackgroundColor.lighten(20)
                      : Colors.grey.shade200),
      // recognizerFactories: <Type, GestureRecognizerFactory>{
      //   TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(() => TapGestureRecognizer(), (
      //     TapGestureRecognizer instance,
      //   ) {
      //     instance.onTap = () {
      //       Navigator.push(
      //         context,
      //         MaterialPageRoute<void>(
      //           builder: (context) => MimeEmailViewer(
      //             context.read<EmailProvider>().getMessage(index - pinnedRowCount),
      //             context.read<EmailProvider>().currentMailClient!,
      //             index - pinnedRowCount,
      //           ),
      //         ),
      //       );
      //     };
      //   }),
      // },
      // recognizerFactories: <Type, GestureRecognizerFactory>{
      //   ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
      //       () => ScaleGestureRecognizer(), (ScaleGestureRecognizer instance) {
      //     instance.onStart = (ScaleStartDetails? ssd) {
      //       print(ssd);
      //     };
      //     instance.onUpdate = (ScaleUpdateDetails? ssd) {
      //       print(ssd);
      //     };
      //   }),
      // },
    );
  }
}
