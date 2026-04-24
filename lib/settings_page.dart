// ignore_for_file: use_build_context_synchronously

import 'package:slow_mail/utils/common_import.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:slow_mail/mail/accounts.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:slow_mail/titled_card.dart';
import 'package:slow_mail/utils/android_notifyer.dart';
import 'package:slow_mail/pgp/pgp_email.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:easy_localization/easy_localization.dart';

final _accountsFormKey = GlobalKey<FormBuilderState>();
final _exportFormKey = GlobalKey<FormBuilderState>();
final _importFormKey = GlobalKey<FormBuilderState>();
final _pgpFormKey = GlobalKey<FormBuilderState>();
final _generalFormKey = GlobalKey<FormBuilderState>();

// final FlutterSecureStorage _storage = const FlutterSecureStorage();
// AndroidOptions _getAndroidOptions() =>
//     const AndroidOptions(sharedPreferencesName: 'slow_mail', preferencesKeyPrefix: 'slow_mail');

class GeneralPageProvider extends ChangeNotifier {
  GeneralPageProvider(BuildContext context) {
    _notifyCurrent = context.read<SettingsProvider>().generalPrefs["currentNotificationEnabled"] ?? false;
    _markAsReadOnOpen = context.read<SettingsProvider>().generalPrefs["markAsReadOnOpen"] ?? false;
  }

  bool _notifyCurrent = false;
  bool _markAsReadOnOpen = false;

  bool get notifyCurrent => _notifyCurrent;
  set notifyCurrent(bool value) {
    if (value == _notifyCurrent) return;
    _notifyCurrent = value;
    notifyListeners();
  }

  bool get markAsReadOnOpen => _markAsReadOnOpen;
  set markAsReadOnOpen(bool value) {
    if (value == _markAsReadOnOpen) return;
    _markAsReadOnOpen = value;
    notifyListeners();
  }
}

class ExportImportPageProvider extends ChangeNotifier {
  bool isExportPassordObscured = true;
  bool encryptExport = true;
  bool overrideByImport = false;

  void setOverrideByImport(bool value) {
    if (value == overrideByImport) return;
    overrideByImport = value;
    notifyListeners();
  }

  void setEncryptExport(bool value) {
    if (value == encryptExport) return;
    encryptExport = value;
    notifyListeners();
  }

  void togleExportPasswordObscured() {
    isExportPassordObscured = !isExportPassordObscured;
    notifyListeners();
  }
}

class PgpPageProvider extends ChangeNotifier {
  String? _selectedPubKey;
  String? _selectedPrivKey;
  bool isKeyPassordObscured = true;

  void togleKeyPasswordObscured() {
    isKeyPassordObscured = !isKeyPassordObscured;
    notifyListeners();
  }

  String? get selectedPubKey {
    return _selectedPubKey;
  }

  set selectedPubKey(String? key) {
    if (key == _selectedPubKey) return;
    _selectedPubKey = key;
    notifyListeners();
  }

  String? get selectedPrivKey {
    return _selectedPrivKey;
  }

  set selectedPrivKey(String? key) {
    if (key == _selectedPrivKey) return;
    _selectedPrivKey = key;
    notifyListeners();
  }
}

class AccountsPageProvider extends ChangeNotifier {
  bool isKeyAuth = false;
  bool isIncomingPassordObscured = true;
  bool isOutgoingPassordObscured = true;
  MailAccount? _currentMailAccount;
  bool _incomingServerUsePassword = true;
  bool _outgoingServerUsePassword = true;
  bool outgoingAuthEQIncoming = true;
  bool saveIncomingPassword = true;
  bool saveOutgoingPassword = true;

  bool get incomingServerUsePassword => _incomingServerUsePassword;
  set incomingServerUsePassword(bool p) {
    _incomingServerUsePassword = p;
    notifyListeners();
  }

  bool get outgoingServerUsePassword => _outgoingServerUsePassword;
  set outgoingServerUsePassword(bool p) {
    _outgoingServerUsePassword = p;
    notifyListeners();
  }

  void setSaveOutgoingPassword(bool value) {
    saveOutgoingPassword = value;
    notifyListeners();
  }

  void setSaveIncomingPassword(bool value) {
    saveIncomingPassword = value;
    notifyListeners();
  }

  void setOutgoingAuthEQIncoming(bool value) {
    outgoingAuthEQIncoming = value;
    notifyListeners();
  }

  void togleIncommingPasswordObscured() {
    isIncomingPassordObscured = !isIncomingPassordObscured;
    notifyListeners();
  }

  void togleOutgoingPasswordObscured() {
    isOutgoingPassordObscured = !isOutgoingPassordObscured;
    notifyListeners();
  }

  AccountsPageProvider() : super() {
    //isKeyAuth = prefs.getBool('sftpIsKeyAuth') ?? false;
  }

  set currentMailAccount(MailAccount? acc) {
    _currentMailAccount = acc;
    notifyListeners();
  }

  MailAccount? get currentMailAccount => _currentMailAccount;

  void setKeyAuth(bool isKey) {
    isKeyAuth = isKey;
    notifyListeners();
  }

  void notify() {
    notifyListeners();
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  //const SettingsPage({super.key});

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_accountsFormKey.currentState != null) {
        _accountsFormKey.currentState!.fields['existingMailAccounts']!
            .didChange(context.read<EmailProvider>().currentMailAccount?.email);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          }
        },
        child: DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              elevation: 1,
              automaticallyImplyLeading: true,
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [Icon(Icons.manage_accounts), Text(LocaleKeys.mailaccounts.tr())],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [Icon(Icons.settings), Text(LocaleKeys.title_general.tr())],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [Icon(Icons.import_export), Text(LocaleKeys.exportimport.tr())],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [Icon(Icons.key), Text(LocaleKeys.pgp_settings.tr())],
                    ),
                  ),
                ],
              ),
              shadowColor:
                  context.watch<ConnectionProvider>().netAvailable ? null : Theme.of(context).colorScheme.error,
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
                child: Text(LocaleKeys.settings.tr()),
              ),
            ),
            body: SafeArea(
              minimum: EdgeInsets.symmetric(horizontal: 5),

              child: TabBarView(children: [
                accountsTab(context),
                generalTab(context),
                exportImport(context),
                pgpSettings(context),
              ]),
              // ),
            ),
          ),
          // ),
        ),
      ),
    );
  }

  Widget pgpSettings(BuildContext context) {
    double fieldWidth = MediaQuery.of(context).size.width > mobileWidth
        ? MediaQuery.of(context).size.width * 0.5 - 45
        : MediaQuery.of(context).size.width - 40;

    return ChangeNotifierProvider<PgpPageProvider>(
      create: (context) => PgpPageProvider(),
      builder: (context, child) => FormBuilder(
        key: _pgpFormKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4, 9, 4, 4),
          child: Column(
            spacing: 5,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitledCard(
                title: LocaleKeys.title_public_pgp_keys.tr(),
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
                        // height: 40,
                        width: fieldWidth,
                        child: Column(
                          children: [
                            FormBuilderTextField(
                              maxLines: 8,
                              minLines: 8,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                alignLabelWithHint: true,
                                labelText: LocaleKeys.lbl_public_pgp_data.tr(),
                              ),
                              name: 'public_key_data',
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        String? filePath = await FlutterFileDialog.pickFile(
                                          params: OpenFileDialogParams(
                                            copyFileToCacheDir: true,
                                          ),
                                        );
                                        if (filePath == null) return;
                                        // EasyLoading.show();
                                        File f = File(filePath);
                                        String pubKey = await File(filePath).readAsString();
                                        _pgpFormKey.currentState!.fields["public_key_data"]!.didChange(pubKey);
                                        await f.delete();
                                      } catch (ex) {
                                        if (context.mounted) {
                                          errorMessage(ex.toString());
                                        }
                                      } finally {
                                        EasyLoading.dismiss();
                                      }
                                    },
                                    label: Text(LocaleKeys.from_file.tr()),
                                    icon: Icon(Icons.folder_open),
                                  ),
                                ),
                                Spacer(
                                  flex: 2,
                                ),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      if (_pgpFormKey.currentState == null ||
                                          !context.mounted ||
                                          !_pgpFormKey.currentState!.saveAndValidate()) {
                                        return;
                                      }

                                      String publicKeyData = _pgpFormKey.currentState!.fields["public_key_data"]!.value;
                                      try {
                                        await PgpEmail.getInstance().addPublicKey(publicKeyData);
                                        context.read<SettingsProvider>().onMailAccounts();
                                        succesMessage(LocaleKeys.msg_success_add_pubkey.tr());
                                      } catch (e) {
                                        errorMessage("Unable to add key: ${e.toString()}");
                                      }
                                    },
                                    label: Text(LocaleKeys.save.tr()),
                                    icon: Icon(Icons.save),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                            border: BoxBorder.all(style: BorderStyle.solid, color: const Color.fromARGB(15, 0, 0, 0)),
                            borderRadius: BorderRadius.all(Radius.circular(15))),
                        width: fieldWidth,
                        child: PgpEmail.getInstance().publicKeyList.isNotEmpty
                            ? ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                itemCount: PgpEmail.getInstance().publicKeyList.length,
                                itemBuilder: (context, index) {
                                  MapEntry<String, Map<String, dynamic>> keyEntry =
                                      PgpEmail.getInstance().publicKeyList.entries.elementAt(index);
                                  Map<String, dynamic> keyData = keyEntry.value;
                                  return Card(
                                    child: ListTile(
                                      onTap: () {
                                        _pgpFormKey.currentState!.fields["public_key_data"]!
                                            .didChange(keyData["armoredKey"]);
                                        context.read<PgpPageProvider>().selectedPubKey = keyEntry.key;
                                      },
                                      dense: true,
                                      enabled: true,
                                      selected: context.watch<PgpPageProvider>().selectedPubKey == keyEntry.key,
                                      subtitle: Text(
                                          "${keyData['creationTime']} sign: ${keyData['canSign']} encrypt: ${keyData['canEncrypt']}"),
                                      title: Text(
                                          "${keyData['identities'].first['name']} ${keyData['identities'].first['email']} ( ${keyData['identities'].first['comment']})"),
                                      trailing: IconButton(
                                        onPressed: () {
                                          try {
                                            PgpEmail.getInstance().deletePublicKey(keyEntry.key);
                                            if (keyEntry.key == context.read<PgpPageProvider>().selectedPubKey) {
                                              _pgpFormKey.currentState!.fields["public_key_data"]!.didChange(null);
                                              context.read<PgpPageProvider>().selectedPubKey = null;
                                            }
                                            succesMessage(LocaleKeys.msg_success_delete_pubkey.tr());
                                            setState(() {});
                                          } catch (e) {
                                            errorMessage("Error deleting key ${e.toString()}");
                                          }
                                        },
                                        icon: Icon(Icons.delete_forever_outlined),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
              TitledCard(
                title: LocaleKeys.title_private_pgp_keys.tr(),
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
                        // height: 40,
                        width: fieldWidth,
                        child: Column(
                          spacing: 5,
                          children: [
                            FormBuilderTextField(
                              maxLines: 8,
                              minLines: 8,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                alignLabelWithHint: true,
                                labelText: LocaleKeys.lbl_private_pgp_data.tr(),
                              ),
                              name: 'private_key_data',
                            ),
                            // FormBuilderTextField(
                            //   decoration: InputDecoration(
                            //       labelText: "Password of key",
                            //       helperText:
                            //           "Leave blank if the key is not protected or if interactive prompting is required."),
                            //   name: 'private_key_password',
                            //   // initialValue: SecPrefs.sftpPassword,
                            // ),
                            FormBuilderTextField(
                              decoration: InputDecoration(
                                labelText: LocaleKeys.lbl_password_key.tr(),
                                helperText: LocaleKeys.hlp_password_key.tr(),
                                suffixIcon: IconButton(
                                  icon: context.watch<PgpPageProvider>().isKeyPassordObscured
                                      ? Icon(Icons.visibility)
                                      : Icon(Icons.visibility_off),
                                  onPressed: () {
                                    context.read<PgpPageProvider>().togleKeyPasswordObscured();
                                  },
                                ),
                              ),
                              name: 'private_key_password',
                              obscureText: context.watch<PgpPageProvider>().isKeyPassordObscured,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        String? filePath = await FlutterFileDialog.pickFile(
                                          params: OpenFileDialogParams(
                                            copyFileToCacheDir: true,
                                          ),
                                        );
                                        if (filePath == null) return;
                                        // EasyLoading.show();
                                        File f = File(filePath);
                                        String pubKey = await File(filePath).readAsString();
                                        _pgpFormKey.currentState!.fields["private_key_data"]!.didChange(pubKey);
                                        await f.delete();
                                      } catch (ex) {
                                        if (context.mounted) {
                                          errorMessage(ex.toString());
                                        }
                                      } finally {
                                        EasyLoading.dismiss();
                                      }
                                    },
                                    label: Text(LocaleKeys.from_file.tr()),
                                    icon: Icon(Icons.folder_open),
                                  ),
                                ),
                                Spacer(
                                  flex: 2,
                                ),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      if (_pgpFormKey.currentState == null ||
                                          !context.mounted ||
                                          !_pgpFormKey.currentState!.saveAndValidate()) {
                                        return;
                                      }

                                      String privateKeyData =
                                          _pgpFormKey.currentState!.fields["private_key_data"]!.value;
                                      String privateKeyPassword =
                                          _pgpFormKey.currentState!.fields["private_key_password"]?.value ?? '';

                                      try {
                                        await PgpEmail.getInstance().addPrivateKey(privateKeyData, privateKeyPassword);
                                        context.read<SettingsProvider>().onMailAccounts();
                                        succesMessage(LocaleKeys.msg_success_add_privkey.tr());
                                      } on WrongPasswordException catch (wp) {
                                        _pgpFormKey.currentState?.fields['private_key_password']
                                            ?.invalidate(wp.toString());
                                      } catch (e) {
                                        errorMessage("Unable to add key: ${e.toString()}");
                                      }
                                    },
                                    label: Text(LocaleKeys.save.tr()),
                                    icon: Icon(Icons.save),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                            border: BoxBorder.all(style: BorderStyle.solid, color: const Color.fromARGB(15, 0, 0, 0)),
                            borderRadius: BorderRadius.all(Radius.circular(15))),
                        width: fieldWidth,
                        child: PgpEmail.getInstance().privateKeyList.isNotEmpty
                            ? ListView.builder(
                                shrinkWrap: true,
                                itemCount: PgpEmail.getInstance().privateKeyList.length,
                                itemBuilder: (context, index) {
                                  MapEntry<String, Map<String, dynamic>> keyEntry =
                                      PgpEmail.getInstance().privateKeyList.entries.elementAt(index);
                                  Map<String, dynamic> keyData = keyEntry.value;

                                  return Card(
                                    child: ListTile(
                                      onTap: () async {
                                        _pgpFormKey.currentState!.fields["private_key_data"]!
                                            .didChange(keyData["armoredKey"]);
                                        if (keyData.containsKey("privateKeyPassword")) {
                                          _pgpFormKey.currentState!.fields["private_key_password"]!
                                              .didChange(keyData["privateKeyPassword"]);
                                        } else {
                                          _pgpFormKey.currentState!.fields["private_key_password"]!.didChange('');
                                        }
                                        context.read<PgpPageProvider>().selectedPrivKey = keyEntry.key;
                                      },
                                      dense: true,
                                      enabled: true,
                                      selected: context.watch<PgpPageProvider>().selectedPrivKey == keyEntry.key,
                                      subtitle: Text(
                                          "${keyData['creationTime']} sign: ${keyData['canSign']} password: ${keyData['encrypted']}"),
                                      title: Text(
                                          "${keyData['identities'].first['name']} ${keyData['identities'].first['email']} ( ${keyData['identities'].first['comment']})"),
                                      trailing: IconButton(
                                        onPressed: () {
                                          try {
                                            PgpEmail.getInstance().deletePrivateKey(keyEntry.key);
                                            if (keyEntry.key == context.read<PgpPageProvider>().selectedPrivKey) {
                                              _pgpFormKey.currentState!.fields["private_key_data"]!.didChange(null);
                                              _pgpFormKey.currentState!.fields["private_key_password"]!.didChange('');
                                              context.read<PgpPageProvider>().selectedPrivKey = null;
                                            }
                                            succesMessage(LocaleKeys.msg_success_delete_pubkey.tr());
                                            setState(() {});
                                          } catch (e) {
                                            errorMessage("Error deleting key ${e.toString()}");
                                          }
                                        },
                                        icon: Icon(Icons.delete_forever_outlined),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : SizedBox(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget exportImport(BuildContext context) {
    double fieldWidth = MediaQuery.of(context).size.width > mobileWidth
        ? MediaQuery.of(context).size.width * 0.5 - 45
        : MediaQuery.of(context).size.width - 40;

    return ChangeNotifierProvider<ExportImportPageProvider>(
      create: (context) => ExportImportPageProvider(),
      builder: (context, child) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(4, 9, 4, 4),
        child: Wrap(
          spacing: 5,
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormBuilder(
              key: _exportFormKey,
              child: SizedBox(
                width: fieldWidth,
                child: TitledCard(
                  title: LocaleKeys.title_export.tr(),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 10,
                      children: [
                        FormBuilderCheckboxGroup<String>(
                          decoration: InputDecoration(
                            labelText: LocaleKeys.lbl_select_export_accounts.tr(),
                            // isCollapsed: true,
                            // isDense: true,
                          ),
                          name: "exportAccounts",
                          orientation: OptionsOrientation.vertical,
                          wrapAlignment: WrapAlignment.start,
                          options: [
                            ...MailAccountController().mailAddresses.values.map((item) {
                              return FormBuilderFieldOption<String>(
                                value: item.email,
                              );
                            })
                          ],
                          initialValue: [
                            ...MailAccountController().mailAddresses.values.map((item) {
                              return item.email;
                            })
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return LocaleKeys.lbl_select_export_accounts.tr();
                            } else {
                              return null;
                            }
                          },
                        ),
                        if (PgpEmail.getInstance().hasPGP)
                          FormBuilderCheckbox(
                            name: "cbIncludePgpKeys",
                            decoration: InputDecoration(/* labelText: "Encrypt exported Data" */),
                            title: Text(LocaleKeys.include_pgp_keys.tr()),
                            initialValue: true,
                          ),
                        FormBuilderCheckbox(
                          name: "cbExportEncrypted",
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_encrypt_export.tr()),
                          title: FormBuilderTextField(
                            enabled: context.watch<ExportImportPageProvider>().encryptExport,
                            decoration: InputDecoration(
                              labelText: LocaleKeys.password.tr(),
                              suffixIcon: IconButton(
                                icon: context.watch<ExportImportPageProvider>().isExportPassordObscured
                                    ? Icon(Icons.visibility)
                                    : Icon(Icons.visibility_off),
                                onPressed: () {
                                  context.read<ExportImportPageProvider>().togleExportPasswordObscured();
                                },
                              ),
                            ),
                            name: 'exportPassword',
                            obscureText: context.watch<ExportImportPageProvider>().isExportPassordObscured,
                            validator: (value) {
                              if (!context.read<ExportImportPageProvider>().encryptExport) return null;
                              if (value == null || value.isEmpty) {
                                return LocaleKeys.err_field_notbe_empty.tr();
                              } else {
                                return null;
                              }
                            },
                          ),
                          onChanged: (value) {
                            if (value != null) {
                              context.read<ExportImportPageProvider>().setEncryptExport(value);
                            }
                          },
                          initialValue: context.read<ExportImportPageProvider>().encryptExport,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // spacing: 20,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                Map<String, String>? ex = await prepareExport();
                                if (ex == null) return;

                                await FlutterFileDialog.saveFile(
                                    params: SaveFileDialogParams(
                                  data: utf8.encode(ex["data"]!),
                                  fileName: ex["fileName"]!,
                                  mimeTypesFilter: [ex["mimeType"]!],
                                ));
                              },
                              label: Text(LocaleKeys.save_as.tr()),
                              icon: Icon(Icons.drive_folder_upload),
                            ),
                            FilledButton.icon(
                              onPressed: () async {
                                Map<String, String>? ex = await prepareExport();
                                if (ex == null) return;
                                final params = ShareParams(
                                    files: [XFile.fromData(utf8.encode(ex["data"]!), mimeType: ex["mimeType"]!)],
                                    fileNameOverrides: [ex["fileName"]!]);

                                await SharePlus.instance.share(params);
                              },
                              label: Text(LocaleKeys.share.tr()),
                              icon: Icon(Icons.share),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            FormBuilder(
              key: _importFormKey,
              child: SizedBox(
                width: fieldWidth,
                child: TitledCard(
                  title: LocaleKeys.title_import.tr(),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(15),
                    child: Column(
                      spacing: 10,
                      children: [
                        FormBuilderRadioGroup<String>(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_import_type.tr()),
                          name: "importType",
                          wrapRunSpacing: 1,
                          orientation: OptionsOrientation.vertical,
                          options: [
                            FormBuilderFieldOption<String>(
                                value: "optImportMerge", child: Text(LocaleKeys.merge_with_existing_accounts.tr())),
                            FormBuilderFieldOption<String>(
                                value: "optImportOverwrite", child: Text(LocaleKeys.overwrite_existing_accounts.tr())),
                            FormBuilderFieldOption<String>(
                                value: "optImportOverlay", child: Text(LocaleKeys.overlay_existing_accounts.tr())),
                          ],
                          initialValue: "optImportMerge",
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              if (_importFormKey.currentState == null) return;
                              if (!_importFormKey.currentState!.saveAndValidate()) return;

                              String? filePath = await FlutterFileDialog.pickFile(
                                params: OpenFileDialogParams(
                                  copyFileToCacheDir: true,
                                  fileExtensionsFilter: ["json", "pgp"],
                                ),
                              );
                              if (filePath == null) return;
                              // EasyLoading.show();
                              File f = File(filePath);
                              String json = await File(filePath).readAsString();
                              await f.delete();
                              bool removeCurrent = false;
                              bool storeAccounts = false;
                              bool overlayAccounts = false;
                              switch (_importFormKey.currentState?.fields["importType"]!.value) {
                                case "optImportOverwrite":
                                  removeCurrent = true;
                                  storeAccounts = true;
                                  overlayAccounts = false;
                                  break;
                                case "optImportMerge":
                                  removeCurrent = false;
                                  storeAccounts = true;
                                  overlayAccounts = false;
                                  break;
                                case "optImportOverlay":
                                  removeCurrent = false;
                                  storeAccounts = false;
                                  overlayAccounts = true;
                                  break;
                                default:
                                  throw Exception("Importtype not supported");
                              }
                              await context.read<SettingsProvider>().updateConfiguration(
                                    json,
                                    removeCurrent: removeCurrent,
                                    storeAccounts: storeAccounts,
                                    overlayAccounts: overlayAccounts,
                                  );
                              succesMessage(LocaleKeys.success_import.tr());
                            } catch (ex) {
                              if (context.mounted) {
                                errorMessage(ex.toString());
                              }
                            } finally {
                              EasyLoading.dismiss();
                            }
                          },
                          label: Text(LocaleKeys.import_from_file.tr()),
                          icon: Icon(Icons.folder_open),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      //),
    );
  }

  Future<Map<String, String>?> prepareExport() async {
    if (_exportFormKey.currentState == null) return null;
    if (!_exportFormKey.currentState!.saveAndValidate()) return null;

    bool encrypted = _exportFormKey.currentState?.fields["cbExportEncrypted"]?.value ?? true;

    // Map<String, dynamic> data = await MailAccountController().exportAccounts(
    //   _exportFormKey.currentState?.fields["exportAccounts"]?.value,
    //   encrypted: encrypted,
    //   password: _exportFormKey.currentState?.fields["exportPassword"]?.value ?? '',
    //   includePGP: _exportFormKey.currentState?.fields["cbIncludePgpKeys"]?.value ?? false,
    // );
    Map<String, dynamic> data = await context.read<SettingsProvider>().exportConfiguration(
          _exportFormKey.currentState?.fields["exportAccounts"]?.value,
          encrypted: encrypted,
          password: _exportFormKey.currentState?.fields["exportPassword"]?.value ?? '',
          includePGP: _exportFormKey.currentState?.fields["cbIncludePgpKeys"]?.value ?? false,
        );

    return <String, String>{
      "data": JsonEncoder.withIndent('  ').convert(data),
      "fileName": encrypted ? 'SlowMailAccounts.pgp' : 'SlowMailAccounts.json',
      "mimeType": encrypted ? "application/pgp-signature" : "application/json",
    };
  }

  Widget generalTab(BuildContext context) {
    double fieldWidth = MediaQuery.of(context).size.width > mobileWidth
        ? MediaQuery.of(context).size.width * 0.5 - 45
        : MediaQuery.of(context).size.width - 40;

    return ChangeNotifierProvider<GeneralPageProvider>(
      create: (context) => GeneralPageProvider(context),
      builder: (context, child) => FormBuilder(
        key: _generalFormKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4, 9, 4, 4),
          child: Column(
            spacing: 5,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitledCard(
                title: LocaleKeys.title_behavior_settings.tr(),
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
                        height: 40,
                        child: FormBuilderField<bool>(
                          initialValue: context.read<SettingsProvider>().generalPrefs["markAsReadOnOpen"],
                          name: "markAsReadOnOpen",
                          builder: (FormFieldState<bool> field) {
                            return InputDecorator(
                              decoration: InputDecoration(
                                labelText: LocaleKeys.lbl_auto_mark_as_read.tr(),
                              ),
                              child: Row(
                                spacing: 8,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 0.7,
                                    child: Switch(
                                      value: context.watch<GeneralPageProvider>().markAsReadOnOpen,
                                      // value: field.value ?? false,
                                      onChanged: (value) {
                                        field.didChange(value);
                                        //context.read<AccountsPageProvider>().setSaveIncomingPassword(value);
                                      },
                                    ),
                                  ),
                                  context.watch<GeneralPageProvider>().markAsReadOnOpen
                                      ? Text(LocaleKeys.msg_auto_mark_as_read_on.tr())
                                      : Text(LocaleKeys.msg_auto_mark_as_read_off.tr()),
                                  //Spacer(),
                                ],
                              ),
                            );
                          },
                          onChanged: (value) {
                            if (value == null) return;
                            context.read<GeneralPageProvider>().markAsReadOnOpen = value;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TitledCard(
                title: LocaleKeys.title_notification_settings.tr(),
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
                        height: 40,
                        child: FormBuilderField<bool>(
                          initialValue: context.read<SettingsProvider>().generalPrefs["currentNotificationEnabled"],
                          name: "currentNotificationEnabled",
                          builder: (FormFieldState<bool> field) {
                            return InputDecorator(
                              decoration: InputDecoration(
                                labelText: LocaleKeys.lbl_active_account_notification.tr(),
                              ),
                              child: Row(
                                spacing: 8,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 0.7,
                                    child: Switch(
                                      value: context.watch<GeneralPageProvider>().notifyCurrent,
                                      // value: field.value ?? false,
                                      onChanged: (value) {
                                        field.didChange(value);
                                        //context.read<AccountsPageProvider>().setSaveIncomingPassword(value);
                                      },
                                    ),
                                  ),
                                  context.watch<GeneralPageProvider>().notifyCurrent
                                      ? Text(LocaleKeys.msg_active_account_notification_on.tr())
                                      : Text(LocaleKeys.msg_active_account_notification_off.tr()),
                                  //Spacer(),
                                ],
                              ),
                            );
                          },
                          onChanged: (value) {
                            if (value == null) return;
                            context.read<GeneralPageProvider>().notifyCurrent = value;
                          },
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderDropdown<String?>(
                          initialValue: context.read<SettingsProvider>().generalPrefs["permanentNotificationAccount"],
                          decoration: InputDecoration(
                            labelText: LocaleKeys.lbl_permanent_notification.tr(),
                            helper: Text(LocaleKeys.hlp_permanent_notification.tr()),
                            prefix: InkWell(
                              child: Transform.translate(
                                offset: Offset(0.0, 4),
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                ),
                              ),
                              onTap: () {
                                _generalFormKey.currentState!.fields['permanentNotificationAccount']?.didChange(null);
                              },
                            ),
                          ),
                          name: 'permanentNotificationAccount',
                          items: [
                            ...(MailAccountController().getMailAccountModels().entries.where((e) {
                              return !e.value.incomingAskForPassword &&
                                  e.value.incomingAuthentication != Authentication.oauth2;
                            })).map((item) {
                              return DropdownMenuItem<String>(
                                value: item.key,
                                child: Text(item.key),
                              );
                            })
                          ],
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderFilterChips<String>(
                          spacing: 5,
                          decoration: InputDecoration(
                            labelText: LocaleKeys.lbl_notification_attributes.tr(),
                          ),
                          name: "notificationAttributes",
                          showCheckmark: true,
                          options: [
                            FormBuilderChipOption<String>(
                              value: "subject",
                              child: Text(LocaleKeys.subject.tr()),
                            ),
                            FormBuilderChipOption<String>(
                              value: "from",
                              child: Text(LocaleKeys.lbl_from_address.tr()),
                            ),
                          ],
                          initialValue: List<String>.from(
                              context.read<SettingsProvider>().generalPrefs["notificationAttributes"] ?? []),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsGeometry.only(left: 10, right: 10, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FilledButton.icon(
                      icon: Icon(Icons.save_alt),
                      onPressed: () async {
                        try {
                          _generalFormKey.currentState!.saveAndValidate();
                          bool? currentNotificationEnabled =
                              _generalFormKey.currentState!.fields["currentNotificationEnabled"]!.value;
                          String? permanentNotificationAccount =
                              _generalFormKey.currentState!.fields["permanentNotificationAccount"]!.value;

                          if (permanentNotificationAccount != null || (currentNotificationEnabled ?? false)) {
                            if (!AndroidNotifyer().isInitialized) {
                              await AndroidNotifyer().initialize();
                            } else if (!AndroidNotifyer().isPermitted) {
                              await AndroidNotifyer().requestPermission();
                            }
                            if (!AndroidNotifyer().isPermitted) {
                              context.read<SettingsProvider>().generalPrefs["currentNotificationEnabled"] = false;
                              context.read<SettingsProvider>().generalPrefs["permanentNotificationAccount"] = null;
                              context.read<SettingsProvider>().saveGeneralPrefs();
                              context.read<GeneralPageProvider>().notifyCurrent = false;
                              _generalFormKey.currentState!.fields["permanentNotificationAccount"]!.didChange(null);

                              errorMessage(LocaleKeys.err_no_notification_perms.tr());
                              return;
                            }
                          }
                          context.read<SettingsProvider>().generalPrefs["currentNotificationEnabled"] =
                              currentNotificationEnabled;

                          context.read<SettingsProvider>().generalPrefs["permanentNotificationAccount"] =
                              permanentNotificationAccount;

                          context.read<SettingsProvider>().generalPrefs["notificationAttributes"] =
                              _generalFormKey.currentState!.fields["notificationAttributes"]!.value;

                          context.read<SettingsProvider>().generalPrefs["markAsReadOnOpen"] =
                              _generalFormKey.currentState!.fields["markAsReadOnOpen"]!.value;

                          context.read<SettingsProvider>().saveGeneralPrefs();
                          succesMessage(LocaleKeys.msg_saved_successfully.tr());
                        } catch (e) {
                          errorMessage("${LocaleKeys.msg_saved_error.tr()}: $e");
                        }
                      },
                      label: Text(LocaleKeys.speichern.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget accountsTab(BuildContext context) {
    double fieldWidth = MediaQuery.of(context).size.width > mobileWidth
        ? MediaQuery.of(context).size.width * 0.5 - 45
        : MediaQuery.of(context).size.width - 40;

    return ChangeNotifierProvider<AccountsPageProvider>(
      create: (context) => AccountsPageProvider(),
      //dispose: (context, value) => value.dispose(),
      builder: (context, child) => FormBuilder(
        key: _accountsFormKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(4, 9, 4, 4),
          child: Column(
            spacing: 5,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 20,
                children: [
                  Expanded(
                    child: FormBuilderDropdown<String>(
                      // key: UniqueKey(),
                      decoration: InputDecoration(labelText: LocaleKeys.lbl_select_account.tr()),
                      name: 'existingMailAccounts',
                      items: [
                        ...MailAccountController().mailAddresses.values.map((item) {
                          return DropdownMenuItem<String>(
                            value: item.email,
                            child: Text(item.email),
                          );
                        })
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setFormByEmail(value, context);
                      },
                    ),
                  ),
                  Spacer(flex: 1),
                  FilledButton.icon(
                    onPressed: () {
                      _accountsFormKey.currentState!.reset();
                      context.read<AccountsPageProvider>().currentMailAccount = null;
                    },
                    label: Text(LocaleKeys.lbl_create_account.tr()),
                    icon: Icon(Icons.contact_mail),
                  ),
                ],
              ),
              TitledCard(
                title: LocaleKeys.title_general.tr(),
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
                        height: 40,
                        width: fieldWidth,
                        child: FormBuilderTextField(
                          textAlignVertical: TextAlignVertical.center,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return LocaleKeys.err_field_notbe_empty.tr();
                            } else {
                              return null;
                            }
                          },
                          errorBuilder: (context, errorText) {
                            // return Text(errorText);
                            return SizedBox();
                          },
                          decoration: InputDecoration(
                            labelText: LocaleKeys.email.tr(),
                            suffixIcon: IconButton(
                              tooltip: LocaleKeys.tt_search_settings.tr(),
                              icon: Icon(
                                Icons.travel_explore,
                              ),
                              onPressed: () async {
                                if (!(_accountsFormKey.currentState?.fields["email"]?.validate() ?? true)) {
                                  return;
                                }
                                ClientConfig? cfg =
                                    await Discover.discover(_accountsFormKey.currentState?.instantValue["email"]);
                                if (cfg == null) {
                                  errorMessage(LocaleKeys.err_cant_find_config.tr());
                                  return;
                                }
                                setFormByClientConfig(_accountsFormKey.currentState?.instantValue["email"], cfg);
                              },
                            ),
                          ),
                          name: 'email',
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderTextField(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_display_name.tr()),
                          name: 'name',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TitledCard(
                title: LocaleKeys.title_incoming_server.tr(),
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
                        child: FormBuilderTextField(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_hostname.tr()),
                          name: 'incoming/serverConfig/hostname',
                          // initialValue: prefs.getString('sftpHost'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderDropdown<SocketType>(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_connection_security.tr()),
                          name: 'incoming/serverConfig/socketType',
                          items: [
                            ...SocketType.values.map<DropdownMenuItem<SocketType>>((e) {
                              return DropdownMenuItem<SocketType>(
                                value: e,
                                child: Text(e.name),
                              );
                            }),
                          ],
                          initialValue: SocketType.ssl,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderTextField(
                          maxLength: 12,
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_port.tr()),
                          name: 'incoming/serverConfig/port',
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          keyboardType: TextInputType.number,
                          valueTransformer: (value) => int.tryParse(value!) ?? 993,
                          initialValue: "993",
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderTextField(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_login_name.tr()),
                          name: 'incoming/authentication/userName',
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderDropdown<Authentication>(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_authentication_type.tr()),
                          name: 'incoming/serverConfig/authentication',
                          items: [
                            ...SupportedAuthentication.supported.map<DropdownMenuItem<Authentication>>((e) {
                              return DropdownMenuItem<Authentication>(
                                value: e,
                                child: Text(e.name),
                              );
                            }),
                          ],
                          initialValue: Authentication.passwordEncrypted,
                          onChanged: (value) {
                            context.read<AccountsPageProvider>().incomingServerUsePassword =
                                (value == Authentication.passwordClearText ||
                                    value == Authentication.passwordEncrypted);
                          },
                        ),
                      ),
                      Visibility(
                        visible: context.watch<AccountsPageProvider>().incomingServerUsePassword,
                        maintainState: true,
                        child: SizedBox(
                          height: 40,
                          width: fieldWidth,
                          child: FormBuilderField<bool>(
                            name: "incoming/savePassword",
                            builder: (FormFieldState<bool> field) {
                              return InputDecorator(
                                decoration: InputDecoration(
                                  labelText: LocaleKeys.lbl_save_password.tr(),
                                ),
                                child: Row(
                                  spacing: 8,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Transform.scale(
                                      scale: 0.7,
                                      child: Switch(
                                        value: context.watch<AccountsPageProvider>().saveIncomingPassword,
                                        onChanged: (value) {
                                          field.didChange(value);
                                          //context.read<AccountsPageProvider>().setSaveIncomingPassword(value);
                                        },
                                      ),
                                    ),
                                    context.watch<AccountsPageProvider>().saveIncomingPassword
                                        ? Text(LocaleKeys.save_password_locally_encrypted.tr())
                                        : Text(LocaleKeys.ask_for_password.tr()),
                                    //Spacer(),
                                  ],
                                ),
                              );
                            },
                            initialValue: true,
                            onChanged: (value) {
                              context.read<AccountsPageProvider>().setSaveIncomingPassword(value ?? true);
                            },
                          ),
                        ),
                      ),
                      Visibility(
                        visible: context.watch<AccountsPageProvider>().saveIncomingPassword &&
                            context.watch<AccountsPageProvider>().incomingServerUsePassword,
                        maintainState: true,
                        child: SizedBox(
                          height: 40,
                          width: fieldWidth,
                          child: FormBuilderTextField(
                            decoration: InputDecoration(
                              labelText: LocaleKeys.password,
                              suffixIcon: IconButton(
                                icon: context.read<AccountsPageProvider>().isIncomingPassordObscured
                                    ? Icon(Icons.visibility)
                                    : Icon(Icons.visibility_off),
                                onPressed: () {
                                  context.read<AccountsPageProvider>().togleIncommingPasswordObscured();
                                },
                              ),
                            ),
                            name: 'incoming/authentication/password',
                            obscureText: context.read<AccountsPageProvider>().isIncomingPassordObscured,
                            // initialValue: SecPrefs.sftpPassword,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TitledCard(
                title: LocaleKeys.title_outgoing_server.tr(),
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
                        child: FormBuilderTextField(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_hostname.tr()),
                          name: 'outgoing/serverConfig/hostname',
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderDropdown<SocketType>(
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_connection_security.tr()),
                          name: 'outgoing/serverConfig/socketType',
                          items: [
                            ...SocketType.values.map<DropdownMenuItem<SocketType>>((e) {
                              return DropdownMenuItem<SocketType>(
                                value: e,
                                child: Text(e.name),
                              );
                            }),
                          ],
                          initialValue: SocketType.ssl,
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: FormBuilderTextField(
                          maxLength: 12,
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_port.tr()),
                          name: 'outgoing/serverConfig/port',
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          keyboardType: TextInputType.number,
                          valueTransformer: (value) => int.tryParse(value!) ?? 465,
                          initialValue: "465",
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        width: fieldWidth,
                        child: FormBuilderField<bool>(
                          name: "outputAuthSameAsInput",
                          builder: (FormFieldState<bool> field) {
                            return InputDecorator(
                              decoration: InputDecoration(
                                labelText: LocaleKeys.lbl_incoming_equals_outgoing.tr(),
                              ),
                              child: Row(
                                spacing: 8,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Transform.scale(
                                    scale: 0.7,
                                    child: Switch(
                                      value: context.watch<AccountsPageProvider>().outgoingAuthEQIncoming,
                                      onChanged: (value) {
                                        field.didChange(value);
                                        // context.read<AccountsPageProvider>().setOutgoingAuthEQIncoming(value);
                                      },
                                    ),
                                  ),
                                  context.watch<AccountsPageProvider>().outgoingAuthEQIncoming
                                      ? Text(LocaleKeys.same_authentication_as_incoming.tr())
                                      : Text(LocaleKeys.ougoing_authentication_different_from_incoming.tr()),
                                  //Spacer(),
                                ],
                              ),
                            );
                          },
                          initialValue: true,
                          onChanged: (value) {
                            context.read<AccountsPageProvider>().setOutgoingAuthEQIncoming(value ?? false);
                          },
                        ),
                      ),
                      Visibility(
                        visible: !context.watch<AccountsPageProvider>().outgoingAuthEQIncoming,
                        maintainState: true,
                        child: SizedBox(
                          height: 40,
                          width: fieldWidth,
                          child: FormBuilderTextField(
                            decoration: InputDecoration(
                              labelText: LocaleKeys.lbl_login_name.tr(),
                            ),
                            name: 'outgoing/authentication/userName',
                          ),
                        ),
                      ),
                      Visibility(
                        visible: !context.watch<AccountsPageProvider>().outgoingAuthEQIncoming,
                        maintainState: true,
                        child: SizedBox(
                          width: fieldWidth,
                          child: FormBuilderDropdown<Authentication>(
                            decoration: InputDecoration(labelText: LocaleKeys.lbl_authentication_type.tr()),
                            name: 'outgoing/serverConfig/authentication',
                            items: [
                              ...SupportedAuthentication.supported.map<DropdownMenuItem<Authentication>>((e) {
                                return DropdownMenuItem<Authentication>(
                                  value: e,
                                  child: Text(e.name),
                                );
                              }),
                            ],
                            initialValue: Authentication.passwordEncrypted,
                            onChanged: (value) {
                              context.read<AccountsPageProvider>().outgoingServerUsePassword =
                                  (value == Authentication.passwordClearText ||
                                      value == Authentication.passwordEncrypted);
                            },
                          ),
                        ),
                      ),
                      Visibility(
                        visible: context.watch<AccountsPageProvider>().outgoingServerUsePassword &&
                            !context.watch<AccountsPageProvider>().outgoingAuthEQIncoming,
                        maintainState: true,
                        child: SizedBox(
                          height: 40,
                          width: fieldWidth,
                          child: FormBuilderField<bool>(
                            name: "outgoing/savePassword",
                            builder: (FormFieldState<bool> field) {
                              return InputDecorator(
                                decoration: InputDecoration(
                                  labelText: LocaleKeys.lbl_save_password.tr(),
                                ),
                                child: Row(
                                  spacing: 8,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Transform.scale(
                                      scale: 0.7,
                                      child: Switch(
                                        value: context.watch<AccountsPageProvider>().saveOutgoingPassword,
                                        onChanged: (value) {
                                          field.didChange(value);
                                          // context.read<AccountsPageProvider>().setSaveOutgoingPassword(value);
                                        },
                                      ),
                                    ),
                                    context.watch<AccountsPageProvider>().saveOutgoingPassword
                                        ? Text(LocaleKeys.save_password_locally_encrypted.tr())
                                        : Text(LocaleKeys.ask_for_password.tr()),
                                    //Spacer(),
                                  ],
                                ),
                              );
                            },
                            initialValue: true,
                            onChanged: (value) {
                              context.read<AccountsPageProvider>().setSaveOutgoingPassword(value ?? true);
                            },
                          ),
                        ),
                      ),
                      Visibility(
                        visible: context.watch<AccountsPageProvider>().saveOutgoingPassword &&
                            context.watch<AccountsPageProvider>().outgoingServerUsePassword &&
                            !context.watch<AccountsPageProvider>().outgoingAuthEQIncoming,
                        maintainState: true,
                        child: SizedBox(
                          height: 40,
                          width: fieldWidth,
                          child: FormBuilderTextField(
                            decoration: InputDecoration(
                              labelText: LocaleKeys.password.tr(),
                              suffixIcon: IconButton(
                                icon: context.read<AccountsPageProvider>().isOutgoingPassordObscured
                                    ? Icon(Icons.visibility)
                                    : Icon(Icons.visibility_off),
                                onPressed: () {
                                  context.read<AccountsPageProvider>().togleOutgoingPasswordObscured();
                                },
                              ),
                            ),
                            name: 'outgoing/authentication/password',
                            obscureText: context.read<AccountsPageProvider>().isOutgoingPassordObscured,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TitledCard(
                title: LocaleKeys.title_network_options.tr(),
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
                        child: FormBuilderTextField(
                          maxLength: 12,
                          decoration: InputDecoration(labelText: LocaleKeys.lbl_timeout.tr()),
                          name: 'timeout',
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          keyboardType: TextInputType.number,
                          valueTransformer: (value) => int.tryParse(value!) ?? 20,
                          initialValue: "20",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsGeometry.only(left: 10, right: 10, top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FilledButton.icon(
                      icon: Icon(Icons.perm_data_setting),
                      onPressed: () async {
                        if (context.mounted) {
                          try {
                            MailAccountModel? newAcc = getMailAccountFromForm(context);
                            if (newAcc == null) throw Exception("Unable to create account");
                            await MailAccountController().addAccount(newAcc);
                            succesMessage(LocaleKeys.msg_saved_successfully.tr());
                          } catch (ex) {
                            errorMessage("Failed to save (${ex.toString()})");
                          }
                        }
                      },
                      label: Text(LocaleKeys.speichern.tr()),
                    ),
                    Spacer(),
                    Padding(
                      padding: EdgeInsetsGeometry.only(right: 10),
                      child: FilledButton.icon(
                        icon: Icon(Icons.delete_forever),
                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                        onPressed: context.watch<AccountsPageProvider>().currentMailAccount == null
                            ? null
                            : () async {
                                if (context.mounted) {
                                  MailAccountModel? newAcc = getMailAccountFromForm(context);

                                  try {
                                    if (newAcc == null) throw Exception("No valid Account");
                                    await MailAccountController().deleteMailAccountModel(newAcc);
                                    _accountsFormKey.currentState!.reset();
                                    context.read<AccountsPageProvider>().currentMailAccount = null;
                                    succesMessage(LocaleKeys.msg_deleted_successfully.tr());
                                  } catch (ex) {
                                    errorMessage("Error: (${ex.toString()})");
                                  }
                                }
                              },
                        label: Text(LocaleKeys.txt_delete.tr()),
                      ),
                    ),
                    FilledButton.icon(
                      icon: Icon(Icons.network_check),
                      style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.tertiary),
                      onPressed: context.watch<ConnectionProvider>().netAvailable
                          ? () async {
                              EasyLoading.show();
                              MailClient? mc;
                              try {
                                MailAccountModel? newAcc = getMailAccountFromForm(context);
                                if (newAcc != null) {
                                  mc = MailClient(await newAcc.mailAccountWithSecrets);
                                  await mc.connect();
                                  succesMessage(LocaleKeys.msg_connection_successful.tr());
                                }
                              } catch (e) {
                                errorMessage("${LocaleKeys.msg_connection_failed.tr()}: $e");
                              } finally {
                                if (mc != null && mc.isConnected) await mc.disconnect();
                                EasyLoading.dismiss();
                              }
                            }
                          : null,
                      label: Text(LocaleKeys.test_connection.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> setFormByEmail(String email, BuildContext context) async {
    MailAccountModel? acc = (await MailAccountController().mailAccountModelByEmail(email));
    // context.read<AccountsPageProvider>().currentMailAccount = acc?.mailAccount;
    context.read<AccountsPageProvider>().currentMailAccount = await acc?.mailAccountWithSecrets;
    if (acc == null || !context.mounted) return;

    _accountsFormKey.currentState?.patchValue(_formFromMailAccount(acc));
  }

  Map<String, dynamic> _formFromMailAccount(MailAccountModel? acc) {
    if (acc == null) return <String, dynamic>{};

    // String userName = acc.userName;

    return <String, dynamic>{
      'email': acc.email,
      'name': acc.name,
      'timeout': acc.timeout.toString(),
      //'userName': userName,
      'incoming/serverConfig/hostname': acc.incomingHostname,
      'incoming/serverConfig/socketType': acc.incomingSocketType,
      'incoming/serverConfig/port': acc.incomingPort.toString(),
      'incoming/serverConfig/authentication': acc.incomingAuthentication?.mapSupported() ?? Authentication.unknown,
      'incoming/authentication/password': acc.incomingPassword,
      'incoming/authentication/userName': acc.incomingUserName,
      'outgoing/serverConfig/hostname': acc.outgoingHostname,
      'outgoing/serverConfig/socketType': acc.outgoingSocketType,
      'outgoing/serverConfig/port': acc.outgoingPort.toString(),
      'outgoing/serverConfig/authentication': acc.outgoingAuthentication?.mapSupported() ?? Authentication.unknown,
      'outgoing/authentication/password': acc.outgoingPassword,
      'outgoing/authentication/userName': acc.outgoingUserName,
      'outputAuthSameAsInput': acc.outgoingAuthEqualIncoming,
      "outgoing/savePassword": !acc.outgoingAskForPassword,
      "incoming/savePassword": !acc.incomingAskForPassword,
    };
  }

  void setFormByClientConfig(String? email, ClientConfig cfg) {
    _accountsFormKey.currentState?.patchValue({
      'name': cfg.displayName ?? '',
      //'userName': cfg.preferredIncomingImapServer?.username.replaceAll("%EMAILADDRESS%", email ?? '') ?? '',
      'incoming/serverConfig/hostname': cfg.preferredIncomingImapServer?.hostname ?? '',
      'incoming/serverConfig/socketType': cfg.preferredIncomingImapServer?.socketType ?? SocketType.unknown,
      'incoming/serverConfig/port': cfg.preferredIncomingImapServer?.port.toString() ?? "0",
      'incoming/serverConfig/authentication':
          cfg.preferredIncomingImapServer?.authentication.mapSupported() ?? Authentication.unknown,
      'outgoing/serverConfig/hostname': cfg.preferredOutgoingSmtpServer?.hostname ?? '',
      'outgoing/serverConfig/socketType': cfg.preferredOutgoingSmtpServer?.socketType ?? SocketType.unknown,
      'outgoing/serverConfig/port': cfg.preferredOutgoingSmtpServer?.port.toString() ?? "0",
      'outgoing/serverConfig/authentication':
          cfg.preferredOutgoingSmtpServer?.authentication.mapSupported() ?? Authentication.unknown,
    });
  }

  MailAccountModel? getMailAccountFromForm(BuildContext context) {
    if (_accountsFormKey.currentState == null) return null;

    if (!_accountsFormKey.currentState!.saveAndValidate()) return null;

    Map<String, dynamic> values = _accountsFormKey.currentState!.value;

    Authentication outgoingAuthentication = values['outgoing/serverConfig/authentication'];
    String outgoingSecret = values['outgoing/authentication/password'] ?? '';
    String outgoingUserName = values['outgoing/authentication/userName'] ?? '';
    bool outgoingSavePassword = values["outgoing/savePassword"];

    if (context.read<AccountsPageProvider>().outgoingAuthEQIncoming) {
      outgoingAuthentication = values['incoming/serverConfig/authentication'];
      outgoingSecret = values['incoming/authentication/password'] ?? '';
      outgoingUserName = values['incoming/authentication/userName'] ?? '';
      outgoingSavePassword = values["incoming/savePassword"];
    }

    return MailAccountModel.fromSettings(
        name: values["name"],
        email: values["email"],
        timeout: values["timeout"],
        incomingHost: values['incoming/serverConfig/hostname'],
        outgoingHost: values['outgoing/serverConfig/hostname'],
        incomingPassword: values["incoming/savePassword"] ? values['incoming/authentication/password'] ?? '' : '',
        incomingUserName: values['incoming/authentication/userName'] ?? '',
        incomingAuthType: values['incoming/serverConfig/authentication'],
        outgoingPassword: outgoingSavePassword ? outgoingSecret : '',
        outgoingUserName: outgoingUserName,
        outgoingAuthType: outgoingAuthentication,
        outgoingClientDomain: values['outgoing/serverConfig/hostname'],
        incomingPort: values["incoming/serverConfig/port"],
        outgoingPort: values["outgoing/serverConfig/port"],
        incomingSocketType: values['incoming/serverConfig/socketType'],
        outgoingSocketType: values['outgoing/serverConfig/socketType'],
        outgoingAuthEqualIncoming: values["outputAuthSameAsInput"],
        incomingAskForPassword: !values["incoming/savePassword"],
        outgoingAskForPassword: !outgoingSavePassword);
  }
}
