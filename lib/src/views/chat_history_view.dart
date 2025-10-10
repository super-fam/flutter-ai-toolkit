import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_ai_toolkit/src/views/chat_input/chat_suggestion_view.dart';

import '../chat_view_model/chat_view_model_client.dart';
import '../providers/interface/chat_message.dart';
import '../providers/interface/message_origin.dart';
import 'chat_message_view/llm_message_view.dart';
import 'chat_message_view/user_message_view.dart';

@immutable
class ChatHistoryView extends StatefulWidget {
  const ChatHistoryView({
    this.botAvatar,
    this.onEditMessage,
    required this.onSelectSuggestion,
    required this.controller,
    super.key,
  });

  final Widget? botAvatar;
  final void Function(ChatMessage message)? onEditMessage;
  final void Function(String suggestion) onSelectSuggestion;
  final ScrollController controller;

  @override
  State<ChatHistoryView> createState() => _ChatHistoryViewState();
}

class _ChatHistoryViewState extends State<ChatHistoryView>
    with WidgetsBindingObserver {
  int _lastPairCount = 0;
  double _bottomInset = 0.0;

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;

    setState(() {
      _bottomInset = bottomInset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ChatViewModelClient(
        builder: (context, viewModel, child) {
          final showWelcomeMessage = viewModel.welcomeMessage != null;
          final showSuggestions =
              viewModel.suggestions.isNotEmpty &&
              viewModel.provider.history.isEmpty;

          final history = [
            if (showWelcomeMessage)
              ChatMessage(
                origin: MessageOrigin.llm,
                text: viewModel.welcomeMessage,
                attachments: [],
              ),
            ...viewModel.provider.history,
          ];

          if (viewModel.provider.history.isEmpty) {
            return ListView(
              reverse: true, // Keep bottom at start
              controller: widget.controller,
              children: [
                if (showSuggestions)
                  ChatSuggestionsView(
                    suggestions: viewModel.suggestions,
                    onSelectSuggestion: widget.onSelectSuggestion,
                  ),
                if (showWelcomeMessage)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: LlmMessageView(
                      ChatMessage(
                        origin: MessageOrigin.llm,
                        text: viewModel.welcomeMessage,
                        attachments: [],
                      ),
                      isWelcomeMessage: true,
                      botAvatar: widget.botAvatar,
                    ),
                  ),
              ],
            );
          }

          // Create user+bot pairs
          final pairs = <List<ChatMessage>>[];
          for (int i = 0; i < history.length; i++) {
            final current = history[i];
            if (current.origin.isUser) {
              if (i + 1 < history.length && history[i + 1].origin.isLlm) {
                pairs.add([current, history[i + 1]]);
                i++;
              } else {
                pairs.add([current]);
              }
            } else {
              pairs.add([current]);
            }
          }

          // Scroll to bottom when new messages added
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (pairs.length != _lastPairCount) {
              _lastPairCount = pairs.length;
              if (widget.controller.hasClients) {
                widget.controller.animateTo(
                  0.0, // scroll to bottom in reversed list
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              }
            }
          });

          return LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;

              final reversedPairs = pairs.reversed.toList();

              return ListView.builder(
                controller: widget.controller,
                reverse: true, // bottom-to-top scrolling
                padding: EdgeInsets.zero,
                itemCount: reversedPairs.length + (showSuggestions ? 1 : 0),
                itemBuilder: (context, index) {
                  // Suggestions appear at the bottom
                  if (showSuggestions && index == 0) {
                    return ChatSuggestionsView(
                      suggestions: viewModel.suggestions,
                      onSelectSuggestion: widget.onSelectSuggestion,
                    );
                  }

                  final pair = reversedPairs[index - (showSuggestions ? 1 : 0)];

                  // In reversed list, the last pair visually is index 0 (bottom)
                  final isLastPair = index == (showSuggestions ? 1 : 0);

                  final messageWidgets = pair.map((message) {
                    final isUser = message.origin.isUser;
                    final canEdit = isUser && widget.onEditMessage != null;

                    return isUser
                        ? UserMessageView(
                            message,
                            onEdit:
                                canEdit ? () => widget.onEditMessage?.call(message) : null,
                          )
                        : LlmMessageView(
                            message,
                            isWelcomeMessage: false,
                            botAvatar: widget.botAvatar,
                          );
                  }).toList();

                  Widget content = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: messageWidgets,
                  );

                  if (isLastPair) {
                    final remainingHeight =
                        (screenHeight - kToolbarHeight + 40).clamp(0.0, screenHeight);
                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: remainingHeight),
                      child: content,
                    );
                  } else {
                    return content;
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}