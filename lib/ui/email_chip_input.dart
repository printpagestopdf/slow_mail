import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:collection/collection.dart';
import 'package:slow_mail/settings.dart';
import 'package:slow_mail/utils/globals.dart';
import 'package:provider/provider.dart';
import 'package:slow_mail/utils/utils.dart';

class EmailChipInput extends StatefulWidget {
  final String hintText;
  final String name;
  final List<MailAddress>? initialValue;
  final InputDecoration? decoration;
  final double extent;
  final void Function(List<MailAddress>? adr)? onUpdate;
  final OutsideTapManager manager;

  const EmailChipInput({
    super.key,
    required this.name,
    required this.manager,
    this.hintText = "",
    this.decoration,
    this.extent = 150,
    this.initialValue,
    this.onUpdate,
  });

  @override
  State<EmailChipInput> createState() => _EmailChipInputState();
}

class _EmailChipInputState extends State<EmailChipInput> {
  late FocusNode focusNode;
  late FocusNode baseFocusNode;
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open(FormFieldState<List<MailAddress>> formFieldState, double parentWidth) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;

    if (_entry != null) return;
    _entry = OverlayEntry(
      builder: (context) {
        return _OverlayTextField(
          link: _link,
          formFieldState: formFieldState,
          decoration: widget.decoration,
          hintText: widget.hintText,
          onClose: _close,
          focusNode: focusNode,
          width: box?.size.width ?? parentWidth,
          extent: widget.extent,
          manager: widget.manager,
        );
      },
    );
    setState(() {});
    Overlay.of(context).insert(_entry!);
    focusNode.requestFocus();
  }

  void _close([String? val]) {
    _entry?.remove();
    _entry = null;
    setState(() {});
  }

  @override
  void dispose() {
    baseFocusNode.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    focusNode = FocusNode();
    baseFocusNode = FocusNode();
    // baseFocusNode.canRequestFocus = false;
    super.initState();

    if (widget.onUpdate != null) {
      widget.onUpdate!(widget.initialValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return CompositedTransformTarget(
        link: _link,
        child: FormBuilderField<List<MailAddress>>(
          onChanged: widget.onUpdate,
          initialValue: widget.initialValue ?? <MailAddress>[],
          name: widget.name,
          builder: (field) {
            //if (_entry != null) return SizedBox();
            return InkWell(
              focusNode: baseFocusNode,
              onTap: () => _open(field, constraints.maxWidth),
              onFocusChange: (value) {
                if (value && _entry == null) {
                  _open(field, constraints.maxWidth);
                  // baseFocusNode.nextFocus();
                  // baseFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                  baseFocusNode.unfocus(disposition: UnfocusDisposition.scope);
                }
              },
              child: InputDecorator(
                decoration: widget.decoration?.copyWith(
                        errorText: field.errorText,
                        contentPadding: EdgeInsets.all(6),
                        hintText: "",
                        constraints: BoxConstraints(minHeight: 40)) ??
                    InputDecoration(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 5,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: field.value != null && field.value!.isNotEmpty
                        ? field.value!.mapIndexed<Widget>((int idx, MailAddress item) {
                            return _tagItem(
                              context: context,
                              txt: item.toString(),
                              withTooltip: true,
                              onIconTap: () {
                                setState(() {
                                  // _addressList.removeAt(idx);
                                  field.value!.removeAt(idx);
                                  field.didChange(field.value);
                                });
                              },
                            );
                          }).toList()
                        : [Text(widget.hintText)],
                  ),
                ),
              ),
              // ),
            );
          },
        ),
        // ),
        // ),
        // ),
      );
    });
  }
}

class _OverlayTextField extends StatefulWidget {
  final LayerLink link;
  final String hintText;
  final InputDecoration? decoration;
  final Function([String? val]) onClose;
  final FocusNode focusNode;
  final double width;
  final double extent;
  final FormFieldState<List<MailAddress>> formFieldState;
  final OutsideTapManager manager;

  const _OverlayTextField({
    required this.link,
    required this.formFieldState,
    required this.decoration,
    required this.hintText,
    required this.onClose,
    required this.focusNode,
    required this.width,
    required this.extent,
    required this.manager,
  });
  @override
  State<_OverlayTextField> createState() => _OverlayTextFieldState();
}

class _OverlayTextFieldState extends State<_OverlayTextField> {
  final ScrollController _tagScrollController = ScrollController();
  final TextEditingController controller = TextEditingController();
  String? inputError;
  final key = GlobalKey();
  OverlayEntry? _overlayEntry;
  LayerLink suggetListLink = LayerLink();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    inputError = widget.formFieldState.errorText;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _tagScrollController.animateTo(_tagScrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 100), curve: Curves.ease);
    });

    widget.manager.register(key, () {
      if (controller.text.isNotEmpty) {
        _addToList(controller.text);
      }
      widget.onClose(controller.text);
    });
  }

  @override
  void dispose() {
    widget.manager.unregister(key);
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: true,
      //focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          if (controller.text.isNotEmpty) {
            _addToList(controller.text);
          }

          widget.onClose(controller.text);
        }
      },
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: widget.link,
            showWhenUnlinked: false,
            offset: Offset.zero,
            child: Material(
              elevation: 10,
              child: InputDecorator(
                decoration: widget.decoration?.copyWith(
                      constraints: BoxConstraints(maxWidth: widget.width, maxHeight: 150),
                      contentPadding: EdgeInsets.all(6),
                    ) ??
                    InputDecoration(),
                child: Column(
                  key: key,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _tagScrollController,
                        scrollDirection: Axis.vertical,
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(0), // EdgeInsetsGeometry.all(10),
                          child: Wrap(
                              spacing: 10,
                              runSpacing: 5,
                              // children: widget.addressList.mapIndexed<Widget>((int idx, MailAddress item) {
                              children: widget.formFieldState.value!.mapIndexed<Widget>((int idx, MailAddress item) {
                                return _tagItem(
                                  context: context,
                                  txt: item.toString(),
                                  onTextTap: () async {
                                    controller.text = item.toString();
                                    setState(() {
                                      widget.formFieldState.value!.removeAt(idx);
                                      widget.formFieldState.didChange(widget.formFieldState.value);
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                                      await _tagScrollController.animateTo(
                                          _tagScrollController.position.maxScrollExtent,
                                          duration: Duration(milliseconds: 100),
                                          curve: Curves.ease);
                                    });
                                  },
                                  onIconTap: () {
                                    setState(() {
                                      // widget.addressList.removeAt(idx);
                                      widget.formFieldState.value!.removeAt(idx);
                                      widget.formFieldState.didChange(widget.formFieldState.value);
                                    });
                                  },
                                );
                              }).toList()),
                        ),
                      ),
                    ),
                    Divider(
                      indent: 10,
                      endIndent: 10,
                      height: 0,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CompositedTransformTarget(
                            link: suggetListLink,
                            child: TextField(
                              controller: controller,
                              onChanged: (value) {
                                if (_overlayEntry == null) _showOverlay();
                                if (value.isNullOrEmpty()) {
                                  _filteredItems.clear();
                                } else {
                                  _filteredItems = context
                                      .read<SettingsProvider>()
                                      .emailSuggestions
                                      .where((item) => item.toLowerCase().contains(value))
                                      .toList();
                                }
                                _overlayEntry?.markNeedsBuild();
                              },
                              focusNode: widget.focusNode,
                              autofocus: true,
                              maxLines: 1,
                              onEditingComplete: () {
                                String? result = _addToList(controller.text);
                                if (result != null) {
                                  setState(() {
                                    inputError = result;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                  hintText: widget.hintText, border: InputBorder.none, errorText: inputError),
                            ),
                          ),
                        ),
                        ExcludeFocus(
                          child: IconButton(
                              onPressed: () {
                                if (controller.text.isNotEmpty) {
                                  _addToList(controller.text);
                                }

                                widget.onClose(controller.text);
                              },
                              icon: Icon(Icons.arrow_drop_up)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _addToList(String value) {
    MailAddress newAdr;
    try {
      newAdr = MailAddress.parse(value);
      if (widget.formFieldState.value!.firstWhereOrNull((e) => e.email == newAdr.email) != null) {
        throw MessageException("Email already in list");
      }
      setState(() {
        // widget.addressList.add(newAdr);
        widget.formFieldState.value!.add(newAdr);
        widget.formFieldState.didChange(widget.formFieldState.value);
        controller.text = '';
        inputError = null;
        widget.formFieldState.validate();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _tagScrollController.animateTo(_tagScrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 100), curve: Curves.ease);
      });
    } on MessageException catch (m) {
      return m.toString();
    } catch (_) {
      return "Invalid Email Address";
    }

    return null;
  }

  void _showOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Positioned(
        width: widget.width - 30,
        child: CompositedTransformFollower(
          link: suggetListLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 4,
            child: LimitedBox(
              maxHeight: 350,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      controller.text = _filteredItems[index];
                      _removeOverlay();
                    },
                    child: Container(
                      decoration: BoxDecoration(color: index.isOdd ? Colors.white : Colors.grey.shade200),
                      padding: EdgeInsetsGeometry.symmetric(vertical: 3, horizontal: 10),
                      child: Text(_filteredItems[index]),
                    ),
                  );
                  // return ListTile(
                  //   dense: true,
                  //   title: Text(_filteredItems[index]),
                  //   onTap: () {
                  //     controller.text = _filteredItems[index];
                  //     _removeOverlay();
                  //   },
                  // );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _tagItem({
  required BuildContext context,
  required String txt,
  String? shortTxt,
  String? tooltip,
  double tagMaxWidth = 150,
  void Function()? onTextTap,
  void Function()? onIconTap,
  bool withTooltip = false,
}) {
  return Container(
    constraints: BoxConstraints(maxWidth: tagMaxWidth),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.all(
        Radius.circular(20.0),
      ),
      color: Theme.of(context).colorScheme.primary,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: InkWell(
            onTap: onTextTap,
            child: withTooltip
                ? Tooltip(
                    message: tooltip ?? txt,
                    child: Text(
                      shortTxt ?? txt,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  )
                : Text(
                    shortTxt ?? txt,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    maxLines: 1,
                  ),
          ),
        ),
        const SizedBox(width: 4.0),
        InkWell(
          onTap: onIconTap,
          child: const Icon(
            Icons.cancel,
            size: 14.0,
            color: Color.fromARGB(255, 233, 233, 233),
          ),
        )
      ],
    ),
  );
}

class OutsideTapManager {
  final List<_PopupEntry> _entries = [];

  void register(GlobalKey key, VoidCallback onOutside) {
    _entries.add(_PopupEntry(key, onOutside));
  }

  void unregister(GlobalKey key) {
    _entries.firstWhereOrNull((e) => e.key == key)?.isValid = false;
  }

  void handle(TapDownDetails event) {
    for (final e in _entries) {
      if (!e.isValid) continue;
      final box = e.key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;

      final pos = box.globalToLocal(event.globalPosition);

      if (!box.size.contains(pos)) {
        e.onOutside();
      }
    }
    _entries.removeWhere((e) => !e.isValid);
  }
}

class _PopupEntry {
  final GlobalKey key;
  final VoidCallback onOutside;
  bool isValid = true;

  _PopupEntry(this.key, this.onOutside);
}
