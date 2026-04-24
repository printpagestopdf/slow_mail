import 'dart:math';
import 'dart:ui' as ui;
import 'package:slow_mail/utils/common_import.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:easy_localization/easy_localization.dart';

extension StringExt on String? {
  bool isNullOrEmpty() {
    return (this == null || (this?.isEmpty ?? true));
  }
}

extension DarkMode on BuildContext {
  /// is dark mode currently enabled?
  bool get isDarkMode {
    final brightness = MediaQuery.of(this).platformBrightness;
    return brightness == Brightness.dark;
  }
}

extension DateFormatExt on DateFormat {
  String yMdHm(DateTime date, [String? useLocale]) {
    // if (useLocale == null) {
    //   useLocale = NavService.navKey.currentContext!.locale.toString();
    // }
    useLocale ??= NavService.navKey.currentContext!.locale.toString();
    final base = DateFormat.yMd(useLocale).pattern!;

    final padded = base
        .replaceAllMapped(RegExp(r'(?<!d)d(?!d)'), (_) => 'dd')
        .replaceAllMapped(RegExp(r'(?<!M)M(?!M)'), (_) => 'MM');

    return DateFormat(padded, useLocale).add_Hm().format(date);
  }
}

extension TextMetrics on BuildContext {
  double getTextWidth(String text, {int? maxLines, double maxWidth = double.infinity, TextStyle? style}) {
    return getTextSize(text, style: style, maxLines: maxLines, maxWidth: maxWidth).width;
  }

  Size getTextSize(String? text, {int? maxLines, double maxWidth = double.infinity, TextStyle? style}) {
    final tp = getTextPainter(text, style: style, maxLines: maxLines, maxWidth: maxWidth);

    return tp.size;
  }

  TextPainter getTextPainter(String? text, {int? maxLines, double maxWidth = double.infinity, TextStyle? style}) {
    final defaultTextStyle = DefaultTextStyle.of(this).style;

    final effectiveStyle = style?.copyWith(
          height: style.height ?? defaultTextStyle.height,
          letterSpacing: style.letterSpacing ?? defaultTextStyle.letterSpacing,
        ) ??
        defaultTextStyle;

    return TextPainter(
      text: TextSpan(text: text ?? '', style: effectiveStyle),
      maxLines: maxLines,
      textDirection: ui.TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(this),
    )..layout(maxWidth: maxWidth);
  }
}

class AppLogger {
  static void log(Object? message) {
    if (!kReleaseMode) {
      // ignore: avoid_print
      print(message);
    }
  }
}

// e.g "d95403adeaaa457f9804d47f70ced0dbb6e46d68" => "217:84:3:173:234:170:69:127:152:4:212:127:112:206:208:219:182:228:109:104"
String hexStringToByteString(String hex) {
  final buffer = <int>[];

  for (int i = 0; i < hex.length; i += 2) {
    final byteHex = hex.substring(i, i + 2);
    final byteDec = int.parse(byteHex, radix: 16);
    buffer.add(byteDec);
  }

  return buffer.join(':');
}

// LinkedHashMap<K, T> sortMapByValue<K, T>(LinkedHashMap<K, T> unsorted, int Function(T, T) sortFunc) {
//   List<K> sortedKeys = unsorted.keys.toList(growable: false)..sort((k1, k2) => sortFunc(unsorted[k1]!, unsorted[k2]!));
//   LinkedHashMap<K, T> sortedMap = LinkedHashMap.fromIterable(sortedKeys, key: (a) => a, value: (a) => unsorted[a]!);
//   return sortedMap;
// }

void succesMessage(String message, {int seconds = 3}) {
  if (NavService.navKey.currentState == null || !NavService.navKey.currentState!.context.mounted) return;
  BuildContext context = NavService.navKey.currentState!.context;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check, color: Colors.lightGreenAccent),
          Padding(padding: EdgeInsetsGeometry.only(right: 5)),
          Text(
            message,
            style: TextStyle(color: Colors.lightGreenAccent),
          ),
        ],
      ),
      showCloseIcon: true,
      duration: Duration(seconds: seconds),
    ),
  );
}

void errorMessage(String message, {Duration? duration}) {
  if (NavService.navKey.currentState == null || !NavService.navKey.currentState!.context.mounted) return;
  BuildContext context = NavService.navKey.currentState!.context;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.dangerous, color: Colors.redAccent),
          Padding(padding: EdgeInsetsGeometry.only(right: 5)),
          Text(
            message,
            style: TextStyle(color: Colors.redAccent),
          ),
        ],
      ),
      showCloseIcon: true,
      duration: duration ?? Duration(days: 365),
    ),
  );
}

Future<T?> yesNoDialog<T>({
  String strYes = "Yes",
  String strNo = "No",
  required String content,
  String? title,
  String? checkboxTitle,
  required T retYes,
  required T retNo,
}) async {
  return await showDialog<T>(
      context: NavService.navKey.currentState!.context,
      builder: (BuildContext context) {
        bool? checkboxValue = false;
        return AlertDialog(
          title: title != null ? Text(title) : null,
          content: checkboxTitle != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(content),
                      StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: checkboxValue,
                              onChanged: (bool? value) {
                                setState(() => checkboxValue = value);
                              },
                            ),
                            Text(checkboxTitle),
                          ],
                        );
                      }),
                    ])
              : Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(
                  context, (checkboxTitle == null) ? retNo : {"button": retNo, "checkbox": checkboxValue}),
              child: Text(strNo),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                  context, (checkboxTitle == null) ? retYes : {"button": retYes, "checkbox": checkboxValue}),
              child: Text(strYes),
            ),
          ],
        );
      });
}

Future<String?> textInputDialog({
  required String title,
  required String hint,
  Future<String?> Function(String?)? validator,
}) async {
  Map<String, String>? res = await passwordDialog(
    mainTitle: title,
    askOutgoing: false,
    incomingTitle: hint,
    incomingPassordObscured: false,
    incomingValidator: validator,
  );
  return res?['incoming'];
}

Future<Map<String, String>?> passwordDialog({
  bool askIncoming = true,
  bool askOutgoing = true,
  bool askImportType = false,
  String mainTitle = "Password(s) for Mailaccount",
  String incomingTitle = "Incoming Password",
  String outgoingTitle = "Outgoing Password",
  bool incomingPassordObscured = true,
  bool outgoingPassordObscured = true,
  Future<String?> Function(String?)? incomingValidator,
  Future<String?> Function(String?)? outgoingValidator,
}) async {
  if (NavService.navKey.currentState == null || !NavService.navKey.currentState!.context.mounted) return null;
  BuildContext context = NavService.navKey.currentState!.context;
  final passwordFormKey = GlobalKey<FormBuilderState>();

  Future<void> onSubmit() async {
    if (!passwordFormKey.currentState!.saveAndValidate()) return;
    Map<String, String> ret = <String, String>{};
    if (askIncoming) {
      ret["incoming"] = passwordFormKey.currentState?.fields['incomingPassword']?.value as String? ?? '';
      if (incomingValidator != null) {
        String? err = await incomingValidator(ret["incoming"]);
        if (err != null) {
          passwordFormKey.currentState?.fields['incomingPassword']?.invalidate(err);
          return;
        }
      }
    }
    if (askOutgoing) {
      ret["outgoing"] = passwordFormKey.currentState?.fields['outgoingPassword']?.value as String? ?? '';
      if (outgoingValidator != null) {
        String? err = await outgoingValidator(ret["outgoing"]);
        if (err != null) {
          passwordFormKey.currentState?.fields['outgoingPassword']?.invalidate(err);
          return;
        }
      }
    }
    if (askImportType) {
      ret["importType"] = passwordFormKey.currentState?.fields['importType']?.value as String? ?? '';
    }

    if (context.mounted) {
      Navigator.pop(context, ret);
    }
  }

  return await showDialog<Map<String, String>?>(
      requestFocus: true,
      context: context,
      builder: (context) {
        bool isIncomingPassordObscured = incomingPassordObscured;
        bool isOutgoingPassordObscured = outgoingPassordObscured;
        return AlertDialog(
          title: Text(mainTitle),
          content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
            return FormBuilder(
              key: passwordFormKey,
              child: SizedBox(
                width: min(MediaQuery.of(context).size.width * 0.9, 500),
                child: Column(
                  spacing: 15,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (askImportType)
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
                    if (askIncoming)
                      FormBuilderTextField(
                        textInputAction: askOutgoing ? TextInputAction.next : TextInputAction.done,
                        onSubmitted: (_) => onSubmit(),
                        autofocus: true,
                        maxLines: 1,
                        // onEditingComplete: onSubmit,
                        onChanged: (value) {
                          if (passwordFormKey.currentState?.fields['incomingPassword']?.hasError ?? false) {
                            passwordFormKey.currentState?.fields['incomingPassword']?.validate();
                          }
                        },
                        validator: incomingValidator == null
                            ? (value) => (value == null || value.isEmpty) ? "Password must not be empty" : null
                            : null,
                        decoration: InputDecoration(
                          labelText: incomingTitle,
                          suffixIcon: IconButton(
                            icon: isIncomingPassordObscured ? Icon(Icons.visibility) : Icon(Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                isIncomingPassordObscured = !isIncomingPassordObscured;
                              });
                            },
                          ),
                        ),
                        name: 'incomingPassword',
                        obscureText: isIncomingPassordObscured,
                      ),
                    if (askOutgoing)
                      FormBuilderTextField(
                        // autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onSubmit(),
                        maxLines: 1,
                        validator: outgoingValidator == null
                            ? (value) => (value == null || value.isEmpty) ? "Password must not be empty" : null
                            : null,
                        onChanged: (value) {
                          if (passwordFormKey.currentState?.fields['outgoingPassword']?.hasError ?? false) {
                            passwordFormKey.currentState?.fields['outgoingPassword']?.validate();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: outgoingTitle,
                          suffixIcon: IconButton(
                            icon: isOutgoingPassordObscured ? Icon(Icons.visibility) : Icon(Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                isOutgoingPassordObscured = !isOutgoingPassordObscured;
                              });
                            },
                          ),
                        ),
                        name: 'outgoingPassword',
                        obscureText: isOutgoingPassordObscured,
                      ),
                  ],
                ),
              ),
            );
          }),
          actions: <Widget>[
            MaterialButton(
              color: Theme.of(context).colorScheme.error,
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(Icons.cancel),
                  Text("cancel".tr()),
                ],
              ),
            ),
            MaterialButton(
              color: Theme.of(context).colorScheme.primary,
              onPressed: onSubmit,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Icon(Icons.done),
                  Text("ok".tr()),
                ],
              ),
            ),
          ],
        );
      });
}
