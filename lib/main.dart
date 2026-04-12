// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:slow_mail/utils/common_import.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:slow_mail/theme.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:master_detail_flow/master_detail_flow.dart';
import 'package:slow_mail/infinite_table.dart';
import 'package:slow_mail/email_edit.dart';
import 'package:slow_mail/settings_page.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/ui/tree_view.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:slow_mail/utils/android_notifyer.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/generated/codegen_loader.g.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:workmanager/workmanager.dart';
import 'package:slow_mail/utils/background_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initTimeZones();
  EasyLoading.instance.loadingStyle = EasyLoadingStyle.light;
  Map<String, dynamic>? notifyerArgs = await AndroidNotifyer().getLaunchArgs();

  await Workmanager().initialize(
    callbackDispatcher,
  );

  runApp(
    EasyLocalization(
      useFallbackTranslations: true,
      useFallbackTranslationsForEmptyResources: true,
      supportedLocales: [
        Locale('en'),
        Locale('de'),
        Locale('es'),
        Locale('fr'),
        Locale('pt', 'BR'),
        Locale('zh', 'CN'),
      ],
      path: 'resources/langs',
      fallbackLocale: Locale('en'),
      assetLoader: CodegenLoader(),
      startLocale: Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => EmailProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider(notifyerArgs)),
          ChangeNotifierProvider(create: (_) => TreeProvider()),
          ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            localizationsDelegates: context.localizationDelegates
              ..addAll([
                FlutterQuillLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ]),
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            debugShowCheckedModeBanner: false,
            navigatorKey: NavService.navKey,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            // theme: AppTheme.lightTheme, // Light mode theme
            // darkTheme: AppTheme.darkTheme, // Dark mode theme
            themeMode: ThemeMode.system, // Follows system setting
            builder: EasyLoading.init(),
            routes: {
              '/': (context) => const SlowMailApp(),
              '/settings': (context) => const SettingsPage(),
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> initTimeZones() async {
  tzdata.initializeTimeZones();
  try {
    final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
    final String tzName = tzInfo.identifier;

    tz.setLocalLocation(
      tz.getLocation(tzName),
    );
  } catch (err) {
    // If it fails, timezone will be GMT+0 anyway, so nothing to worry about.
  }
}

class SlowMailApp extends StatefulWidget {
  final String? startupAccountEmail;
  final String? startupMailbox;

  const SlowMailApp({
    super.key,
    this.startupAccountEmail,
    this.startupMailbox,
  });
  @override
  SlowMailState createState() => SlowMailState();
}

class SlowMailState extends State<SlowMailApp> {
  SlowMailState();
  String? startupAccountEmail;

  @override
  void initState() {
    super.initState();
    startupAccountEmail = widget.startupAccountEmail;

    if (startupAccountEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await context.read<SettingsProvider>().openAccountOnInit(startupAccountEmail!);
        startupAccountEmail = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;

      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            shadowColor: context.watch<ConnectionProvider>().netAvailable ? null : Theme.of(context).colorScheme.error,
            title: Row(children: [
              Badge(
                isLabelVisible: !context.watch<ConnectionProvider>().netAvailable,
                offset: Offset(20, -4),
                label: Text(
                  LocaleKeys.msg_no_network.tr(),
                  style: TextStyle(fontSize: 14),
                ),
                child: Text(LocaleKeys.slow_mail.tr()),
              ),
              if (context.watch<SettingsProvider>().isOverlayMode)
                Image.asset(
                  "assets/overlay.png",
                  width: 25,
                  color: context.isDarkMode ? Colors.white : null,
                ),
            ]),
            elevation: 1,
          ),
          drawer: !isWide
              ? Drawer(
                  child: mailAccountTree(context),
                )
              : null,
          body: context.watch<SettingsProvider>().settingsInitialized
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide) mailAccountTree(context),
                    Expanded(
                      child: MailAccountController().mailAddresses.isNotEmpty
                          ? InfiniteTable()
                          : Center(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 20,
                              children: [
                                Text(
                                  LocaleKeys.no_email_accounts_configured.tr(),
                                  style: Theme.of(context).textTheme.headlineLarge,
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (context) => SettingsPage(),
                                    ),
                                  ),
                                  child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(color: Theme.of(context).primaryColor),
                                          children: [
                                            TextSpan(
                                              children: [
                                                TextSpan(text: LocaleKeys.go_to_settings.tr()),
                                                WidgetSpan(child: Icon(Icons.settings)),
                                                TextSpan(text: LocaleKeys.and_add_or_import_accounts.tr()),
                                              ],

                                              // text: "Go to Settings \u{26ED} and add  or import Account(s)",
                                            ),
                                          ])),
                                ),
                              ],
                            )),
                    ),
                  ],
                )
              : Center(child: CircularProgressIndicator()),
        ),
      );
    });
    // );
  }

  Widget mailAccountTree(BuildContext context) {
    return SingleChildScrollView(
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsetsGeometry.only(left: 10, right: 10, bottom: 10, top: 10),
              child: Text(
                LocaleKeys.mailaccounts.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.left,
              ),
            ),
            ...MailAccountController().mailAddresses.entries.map((item) {
              return LongPressDraggable<MapEntry<String, MailAddress>>(
                childWhenDragging: Container(
                  padding: EdgeInsetsGeometry.only(left: 10, right: 10, bottom: 10, top: 10),
                  decoration: BoxDecoration(
                      border: BoxBorder.fromLTRB(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                      color: Theme.of(context).disabledColor),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Icon(Icons.email_outlined),
                      SizedBox(
                        width: 250,
                        child: Text(
                          item.value.email,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextTheme.of(context).titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                axis: Axis.vertical,
                rootOverlay: false,
                dragAnchorStrategy: childDragAnchorStrategy,
                // dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Theme.of(context).hoverColor,
                      border: Border.all(),
                      borderRadius: BorderRadius.all(Radius.circular(5))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Icon(Icons.email_outlined),
                      Text(
                        item.value.email,
                        softWrap: true,
                        style: TextTheme.of(context).titleMedium,
                      ),
                    ],
                  ),
                ),
                data: item,
                child: DragTarget<MapEntry<String, MailAddress>>(onAcceptWithDetails: (details) async {
                  await MailAccountController().moveAccount(details.data.key, item.key);
                  // _itemDroppedOnCustomerCart(item: details.data, customer: customer);
                }, builder: (context, candidateItems, rejectedItems) {
                  return AbsorbPointer(
                    absorbing: !context.watch<ConnectionProvider>().netAvailable,
                    child: Container(
                      padding: EdgeInsetsGeometry.only(
                          left: 10, right: 10, bottom: 10, top: candidateItems.isNotEmpty ? 50 : 10),
                      decoration: BoxDecoration(
                          border: BoxBorder.fromLTRB(bottom: BorderSide(color: Theme.of(context).dividerColor))),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            child: context.watch<EmailProvider>().currentEmail == item.key
                                ? InkWell(
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 5,
                                        children: [
                                          Icon(context.watch<TreeProvider>().isRootExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more),
                                          Expanded(
                                            child: Text(
                                              item.value.email,
                                              softWrap: true,
                                              style: TextTheme.of(context).titleMedium,
                                            ),
                                          ),
                                          MenuAnchor(
                                            builder: (BuildContext context, MenuController controller, Widget? child) {
                                              return InkWell(
                                                onTap: () => controller.isOpen ? controller.close() : controller.open(),
                                                child: Icon(
                                                  Icons.more_vert,
                                                  // size: 20,
                                                ),
                                              );
                                            },
                                            style: MenuStyle(
                                              alignment: Alignment.topLeft,
                                              backgroundColor: WidgetStatePropertyAll(Theme.of(context).canvasColor),
                                              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                                                  borderRadius: BorderRadiusGeometry.all(Radius.circular(10)))),
                                            ),
                                            menuChildren: [
                                              MenuItemButton(
                                                onPressed: () async {
                                                  await _handleMailboxEvent(null, "new_mailbox");
                                                },
                                                child: Text(LocaleKeys.title_new_mailbox.tr()),
                                              ),
                                            ],
                                          )
                                        ]),
                                    onTap: () {
                                      context.read<TreeProvider>().toggleExpanded(null);
                                    },
                                  )
                                : InkWell(
                                    onTap: () async {
                                      await context.read<EmailProvider>().initMailAccount(item.key, openInbox: true);
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: 5,
                                      children: [
                                        Icon(Icons.email_outlined),
                                        Expanded(
                                          child: Text(
                                            item.value.email,
                                            softWrap: true,
                                            style: TextTheme.of(context).titleMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          if (context.watch<EmailProvider>().mbEmail == item.key)
                            TreeView(
                              key: ObjectKey(context.read<EmailProvider>().mailboxTree),
                              root: context.read<EmailProvider>().mailboxTree,
                              onTextTap: (Mailbox? mb) {
                                context.read<EmailProvider>().listMailboxMessages(mb);
                              },
                              onMenuTap: (Mailbox? mb, event) async {
                                await _handleMailboxEvent(mb, event);
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                // ),
              );
            }),
            TextButton.icon(
              label: Text(
                LocaleKeys.settings.tr(),
                softWrap: true,
                style: TextTheme.of(context).titleMedium,
              ),
              icon: Icon(
                Icons.settings,
                size: 24,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => SettingsPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMailboxEvent(Mailbox? mb, String event) async {
    if (!context.mounted || mb == context.read<EmailProvider>().currentMailClient?.selectedMailbox) {
      return;
    }
    switch (event) {
      case "new_mailbox":
        {
          String? res = await textInputDialog(
            title: LocaleKeys.title_new_mailbox.tr(),
            hint: LocaleKeys.hint_mailbox_name.tr(),
            validator: (p0) async {
              return p0.isNullOrEmpty() ? LocaleKeys.err_field_notbe_empty.tr() : null;
            },
          );
          if (res == null) return;
          await context.read<EmailProvider>().createMailbox(mb, res);
        }
        break;
      case "rename_mailbox":
        {
          String? res = await textInputDialog(
            title: LocaleKeys.title_rename_mailbox.tr(),
            hint: LocaleKeys.hint_mailbox_name.tr(),
            validator: (p0) async {
              return p0.isNullOrEmpty() ? LocaleKeys.err_field_notbe_empty.tr() : null;
            },
          );
          if (res == null) return;
          await context.read<EmailProvider>().renameMailbox(mb, res);
        }
        break;
      case "delete_mailbox":
        {
          if (mb == null) return;
          if (await yesNoDialog<bool>(
                  title: "${LocaleKeys.txt_delete.tr()}?",
                  content: LocaleKeys.txt_really_delete.tr(),
                  strNo: LocaleKeys.cancel.tr(),
                  strYes: LocaleKeys.ok.tr(),
                  retYes: false,
                  retNo: true) ??
              true) {
            return;
          }
          await context.read<EmailProvider>().deleteMailbox(mb);
        }
        break;
      case "empty_mailbox":
        {
          if (mb == null) return;
          if (await yesNoDialog<bool>(
                  title: "${LocaleKeys.txt_delete.tr()}?",
                  content: "${LocaleKeys.title_empty_mailbox.tr()}?",
                  strNo: LocaleKeys.cancel.tr(),
                  strYes: LocaleKeys.ok.tr(),
                  retYes: false,
                  retNo: true) ??
              true) {
            return;
          }
          await context.read<EmailProvider>().emptyMailbox(mb);
        }
        break;
    }
  }
}
