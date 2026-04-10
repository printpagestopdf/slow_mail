import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:provider/provider.dart';
import 'package:slow_mail/mail/mail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:slow_mail/generated/locale_keys.g.dart';
import 'package:slow_mail/utils/common_import.dart';

class TreeProvider extends ChangeNotifier {
  String? selectedMailbox;
  List<String?> expanded = <String?>[null];

  void reset() {
    selectedMailbox = null;
    expanded.clear();
    expanded.add(null);
  }

  void toggleSelection(String? mailboxPath) {
    selectedMailbox = mailboxPath;
    notifyListeners();
  }

  void toggleExpanded(String? path) {
    if (expanded.contains(path)) {
      expanded.remove(path);
    } else {
      expanded.add(path);
    }

    notifyListeners();
  }

  void onChanged() {
    notifyListeners();
  }

  bool get isRootExpanded {
    return expanded.contains(null);
  }
}

class MailboxNode extends StatefulWidget {
  final TreeElement<Mailbox?> mailbox;
  final int level;
  final void Function(Mailbox?)? onTextTap;
  final Future<void> Function(Mailbox?, String menuItem)? onMenuTap;

  const MailboxNode({super.key, required this.mailbox, required this.level, this.onTextTap, this.onMenuTap});
  @override
  State<MailboxNode> createState() => _MailboxNodeState();
}

class _MailboxNodeState extends State<MailboxNode> {
  final Color _bgSelected = Colors.black12;
  final double _indent = 14.0;
  final List<MailboxNode> _children = [];
  bool _isExpanded = false;

  @override
  void initState() {
    if (widget.mailbox.value != null && widget.mailbox.value!.isInbox) {
      context.read<TreeProvider>().selectedMailbox = widget.mailbox.value!.path;
    }

    if (widget.mailbox.hasChildren) {
      for (TreeElement<Mailbox?> ti
          // in widget.mailbox.children!.where((TreeElement<Mailbox?>? m) => !(m?.value?.isInbox ?? false))) {
          in widget.mailbox.children!) {
        if (ti.value != null) {
          _children.add(MailboxNode(
            mailbox: ti,
            level: widget.level + 1,
            onTextTap: widget.onTextTap,
            onMenuTap: widget.onMenuTap,
          ));
        }
      }

      //Workaround for strange items in sorted Tree
      _children.sort((m1, m2) {
        if (m1.mailbox.value == m2.mailbox.value) return 0;
        if (m1.mailbox.value == null) return -1;
        if (m2.mailbox.value == null) return 1;
        if (m1.mailbox.value!.identityFlag == null && m2.mailbox.value!.identityFlag == null) {
          return m1.mailbox.value!.path.compareTo(m2.mailbox.value!.path);
        }
        if (m1.mailbox.value!.identityFlag == null) {
          return 1;
        }
        if (m2.mailbox.value!.identityFlag == null) {
          return -1;
        }
        if (m1.mailbox.value!.identityFlag != null && m2.mailbox.value!.identityFlag != null) {
          return m1.mailbox.value!.identityFlag!.index - m2.mailbox.value!.identityFlag!.index;
        }
        return 0;
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        // if (widget.level == 0) rootFolder() else _children.isEmpty ? leafFolder() : containerFolder(),
        if (widget.level == 0) SizedBox() else _children.isEmpty ? leafFolder() : containerFolder(),
        if (context.watch<TreeProvider>().expanded.contains(widget.mailbox.value?.path))
          Padding(
            padding: EdgeInsetsGeometry.only(left: widget.level == 0 ? 0 : _indent),
            child: Column(
              spacing: 5,
              children: [
                ..._children,
              ],
            ),
          ),
      ],
    );
  }

  Widget leafFolder() {
    return InkWell(
      onTap: () {
        if (widget.onTextTap != null) {
          context.read<TreeProvider>().toggleSelection(widget.mailbox.value?.path);
          widget.onTextTap!(widget.mailbox.value);
        }
      },
      child: Container(
        padding: EdgeInsets.only(left: IconTheme.of(context).size ?? 22),
        // padding: EdgeInsets.only(left: 22),
        decoration: BoxDecoration(
          color: (context.watch<EmailProvider>().currentMailClient?.selectedMailbox?.path == widget.mailbox.value?.path)
              ? _bgSelected
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon(
            //   Icons.insert_drive_file,
            //   color: Theme.of(context).colorScheme.secondary, /*  size: 38 */
            // ),
            Image.asset(
              switch (widget.mailbox.value?.identityFlag) {
                MailboxFlag.inbox => "assets/inbox_mail.png",
                MailboxFlag.trash => "assets/trash_mail.png",
                MailboxFlag.sent => "assets/sent_mail.png",
                MailboxFlag.junk => "assets/junk_mail.png",
                MailboxFlag.drafts => "assets/drafts_mail.png",
                _ => "assets/mailbox.png",
              },
              color: context.isDarkMode ? Colors.white : null,
              width: IconTheme.of(context).size ?? 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.mailbox.value?.name ?? "(unnamed)",
                // widget.mailbox.value?.encodedName ?? "(unnamed)",
                softWrap: true,
              ),
            ),
            if ((widget.mailbox.value?.isInbox ?? false) && ((context.watch<EmailProvider>().unreadMessages ?? 0) > 0))
              Badge.count(
                // alignment: AlignmentDirectional.topStart,
                // offset: Offset(-8, -6),
                backgroundColor: Theme.of(context).colorScheme.primary,
                count: context.read<EmailProvider>().unreadMessages ?? 0,
                child: const Icon(Icons.mark_email_unread_outlined),
              ),
            if (widget.onMenuTap != null && widget.mailbox.value != null) folderMenu(widget.mailbox.value!),
          ],
        ),
      ),
    );
  }

  Widget rootFolder() {
    return InkWell(
      onTap: () {
        // setState(() {
        //   _isExpanded = !_isExpanded;
        // });
        context.read<TreeProvider>().toggleExpanded(widget.mailbox.value?.path);
      },
      child: Row(
        children: [
          Icon(context.watch<TreeProvider>().expanded.contains(widget.mailbox.value?.path)
              ? Icons.expand_less
              : Icons.expand_more),
          Image.asset(
            "assets/mailbox_drawer.png",
            color: context.isDarkMode ? Colors.white : null,
            width: IconTheme.of(context).size ?? 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "mailfolder".tr(),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget containerFolder() {
    return Container(
      decoration: BoxDecoration(
        //color: (context.watch<TreeProvider>().selectedMailbox == widget.mailbox.value?.path) ? _bgSelected : null,
        color: (context.watch<EmailProvider>().currentMailClient?.selectedMailbox?.path == widget.mailbox.value?.path)
            ? _bgSelected
            : null,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              context.read<TreeProvider>().toggleExpanded(widget.mailbox.value?.path);
            },
            child: Row(
              children: [
                Icon(context.watch<TreeProvider>().expanded.contains(widget.mailbox.value?.path)
                    ? Icons.expand_less
                    : Icons.expand_more),
                Image.asset(
                  switch (widget.mailbox.value?.identityFlag) {
                    MailboxFlag.inbox => "assets/inbox_mail.png",
                    MailboxFlag.trash => "assets/trash_mail.png",
                    MailboxFlag.sent => "assets/sent_mail.png",
                    MailboxFlag.junk => "assets/junk_mail.png",
                    MailboxFlag.drafts => "assets/drafts_mail.png",
                    _ => "assets/mail_folder.png",
                  },
                  color: context.isDarkMode ? Colors.white : null,
                  width: IconTheme.of(context).size ?? 24,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () {
                if (widget.onTextTap != null) {
                  context.read<TreeProvider>().toggleSelection(widget.mailbox.value?.path);
                  widget.onTextTap!(widget.mailbox.value);
                }
              },
              child: Text(
                // widget.mailbox.value?.encodedName ?? "(noname)",
                widget.mailbox.value?.name ?? "(${LocaleKeys.file_unnamed.tr()})",
                softWrap: true,
              ),
            ),
          ),
          if (widget.onMenuTap != null && widget.mailbox.value != null) folderMenu(widget.mailbox.value!),
        ],
      ),
    );
  }

  Widget folderMenu(Mailbox mb) {
    if (mb == context.read<EmailProvider>().currentMailClient!.selectedMailbox) {
      return SizedBox(
        width: 24,
      );
    }
    return MenuAnchor(
      builder: (BuildContext context, MenuController controller, Widget? child) {
        return InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Icon(
            Icons.more_vert,
          ),
        );
      },
      style: MenuStyle(
        alignment: Alignment.topLeft,
        backgroundColor: WidgetStatePropertyAll(Theme.of(context).canvasColor),
        shape:
            WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.all(Radius.circular(10)))),
      ),
      menuChildren: [
        MenuItemButton(
          onPressed: widget.onMenuTap != null
              ? () async {
                  await widget.onMenuTap!(mb, "new_mailbox");
                }
              : null,
          child: Text(LocaleKeys.title_new_submailbox.tr()),
        ),
        Divider(),
        if (!(mb.isSpecialUse)) ...[
          MenuItemButton(
            onPressed: widget.onMenuTap != null
                ? () async {
                    await widget.onMenuTap!(mb, "rename_mailbox");
                  }
                : null,
            child: Text(LocaleKeys.title_rename_mailbox.tr()),
          ),
          Divider(),
        ],
        MenuItemButton(
          onPressed: () async {
            await widget.onMenuTap!(mb, "empty_mailbox");
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: 250),
            child: Text(
              LocaleKeys.title_empty_mailbox.tr(),
              softWrap: true,
            ),
          ),
        ),
        if (!(mb.isSpecialUse)) ...[
          Divider(),
          MenuItemButton(
            onPressed: !mb.hasChildren
                ? () async {
                    await widget.onMenuTap!(mb, "delete_mailbox");
                  }
                : null,
            child: Container(
              constraints: BoxConstraints(maxWidth: 250),
              child: Text(
                LocaleKeys.title_delete_mailbox.tr(),
                softWrap: true,
              ),
            ),
          ),
        ]
      ],
    );
  }
}

class TreeView extends StatefulWidget {
  final Tree<Mailbox?>? root;
  final void Function(Mailbox?)? onTextTap;
  final Future<void> Function(Mailbox?, String menuItem)? onMenuTap;

  const TreeView({super.key, required this.root, this.onTextTap, this.onMenuTap});

  @override
  State<TreeView> createState() => TreeViewState();
}

class TreeViewState extends State<TreeView> {
  @override
  void initState() {
    context.read<TreeProvider>().reset();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //context.read<TreeProvider>().reset();
    return widget.root == null
        ? SizedBox()
        : CustomScrollView(
            shrinkWrap: true,
            primary: false,
            slivers: [
              SliverToBoxAdapter(
                child: MailboxNode(
                  mailbox: widget.root!.root,
                  level: 0,
                  onTextTap: widget.onTextTap,
                  onMenuTap: widget.onMenuTap,
                ),
              ),
            ],
            // ),
          );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
