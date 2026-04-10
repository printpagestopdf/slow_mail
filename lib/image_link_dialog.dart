import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillDialogTheme;
import 'package:flutter_quill/internal.dart';

final imageRegExp = RegExp(
  r'https?://.*?\.(?:png|jpe?g|gif|bmp|webp|tiff?)',
  caseSensitive: false,
);

class ImageLinkDialog extends StatefulWidget {
  const ImageLinkDialog({
    this.dialogTheme,
    this.link,
    this.linkRegExp,
    super.key,
  });

  final QuillDialogTheme? dialogTheme;
  final String? link;
  final RegExp? linkRegExp;

  @override
  ImageLinkDialogState createState() => ImageLinkDialogState();
}

class ImageLinkDialogState extends State<ImageLinkDialog> {
  late String _link;
  late TextEditingController _controller;
  RegExp? _linkRegExp;

  @override
  void initState() {
    super.initState();
    _link = widget.link ?? '';
    _controller = TextEditingController(text: _link);

    _linkRegExp = widget.linkRegExp;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.dialogTheme?.dialogBackgroundColor,
      content: TextField(
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        maxLines: null,
        style: widget.dialogTheme?.inputTextStyle,
        decoration: InputDecoration(
          labelText: context.loc.pasteLink,
          hintText: "Please enter a valid image URL",
          labelStyle: widget.dialogTheme?.labelTextStyle,
          floatingLabelStyle: widget.dialogTheme?.labelTextStyle,
        ),
        autofocus: true,
        onChanged: _linkChanged,
        controller: _controller,
        onEditingComplete: () {
          if (!_canPress()) {
            return;
          }
          _applyLink();
        },
      ),
      actions: [
        TextButton(
          onPressed: _canPress() ? _applyLink : null,
          child: Text(
            context.loc.ok,
            style: widget.dialogTheme?.labelTextStyle,
          ),
        ),
      ],
    );
  }

  void _linkChanged(String value) {
    setState(() {
      _link = value;
    });
  }

  void _applyLink() {
    Navigator.pop(context, _link.trim());
  }

  RegExp get linkRegExp {
    final customRegExp = _linkRegExp;
    if (customRegExp != null) {
      return customRegExp;
    }
    return imageRegExp;
  }

  bool _canPress() {
    if (_link.isEmpty) {
      return false;
    }
    return _link.isNotEmpty && linkRegExp.hasMatch(_link);
  }
}
