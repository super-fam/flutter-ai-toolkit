import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../providers/interface/chat_message.dart';
import '../../styles/llm_chat_view_style.dart';
import '../../styles/llm_message_style.dart';
import '../jumping_dots_progress_indicator/jumping_dots_progress_indicator.dart';
import 'adaptive_copy_text.dart';
import 'hovering_buttons.dart';

/// A widget that displays an LLM (Language Model) message in a chat interface.
@immutable
class LlmMessageView extends StatelessWidget {
  const LlmMessageView(
    this.message, {
    this.botAvatar,
    this.isWelcomeMessage = false,
    super.key,
  });

  final Widget? botAvatar;
  final ChatMessage message;
  final bool isWelcomeMessage;

  @override
  Widget build(BuildContext context) {
    return ChatViewModelClient(
      builder: (context, viewModel, child) {
        final text = message.text;
        final chatStyle = LlmChatViewStyle.resolve(viewModel.style);
        final llmStyle = LlmMessageStyle.resolve(chatStyle.llmMessageStyle);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (botAvatar != null)
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: botAvatar!,
              ),
            Expanded(
              child: HoveringButtons(
                isUserMessage: false,
                chatStyle: chatStyle,
                clipboardText: text,
                child: Container(
                  decoration: llmStyle.decoration,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(8),
                  child: text == null
                      ? SizedBox(
                          width: 32,
                          child: JumpingDotsProgressIndicator(
                            fontSize: 24,
                            color: chatStyle.progressIndicatorColor!,
                          ),
                        )
                      : AdaptiveCopyText(
                          clipboardText: text,
                          chatStyle: chatStyle,
                          child: isWelcomeMessage ||
                                  viewModel.responseBuilder == null
                              ? MarkdownBody(
                                  data: text,
                                  selectable: false,
                                  styleSheet: llmStyle.markdownStyle,
                                )
                              : viewModel.responseBuilder!(context, text),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
