import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../utility.dart';

@immutable
class AdaptiveCopyText extends StatelessWidget {
  const AdaptiveCopyText({
    required this.clipboardText,
    required this.child,
    required this.chatStyle,
    this.onEdit,
    super.key,
  });

  final String clipboardText;
  final Widget child;
  final VoidCallback? onEdit;
  final LlmChatViewStyle chatStyle;

  @override
  Widget build(BuildContext context) {
    return isMobile
        ? GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => _showBottomSheet(context),
          child: child,
        )
        : isCupertinoApp(context)
        ? Localizations(
          locale: Localizations.localeOf(context),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          child: SelectionArea(child: child),
        )
        : SelectionArea(child: child);
  }

  void _showBottomSheet(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  ListTile(
                    leading: Icon(
                      chatStyle.editButtonStyle!.icon,
                      color: Colors.black,
                      weight: 0.5,
                    ),
                    title: const Text(
                      'Edit',
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        height: 1.33,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEdit?.call();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    chatStyle.copyButtonStyle!.icon,
                    color: Colors.black,
                    weight: 0.5,
                  ),
                  title: const Text(
                    'Share',
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      height: 1.33,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(Share.share(clipboardText));
                  },
                ),
              ],
            ),
          ),
    );
  }
}
