import 'package:flutter/widgets.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../styles/suggestion_style.dart';

/// A widget that displays a list of chat suggestions.
///
/// This widget takes a list of suggestions and a callback function that is
/// triggered when a suggestion is selected. Each suggestion is displayed
/// as a tappable container with padding and a background color.
@immutable
class ChatSuggestionsView extends StatelessWidget {
  /// Creates a [ChatSuggestionsView] widget.
  ///
  /// The [suggestions] parameter is a list of suggestion strings to display.
  /// The [onSelectSuggestion] parameter is a callback function that is called
  /// when a suggestion is tapped.
  const ChatSuggestionsView({
    required this.suggestions,
    required this.onSelectSuggestion,
    super.key,
  });

  /// The list of suggestions to display.
  final List<String> suggestions;

  /// The callback function to call when a suggestion is selected.
  final void Function(String suggestion) onSelectSuggestion;

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final suggestionStyle = SuggestionStyle.resolve(
        viewModel.style?.suggestionStyle,
      );

      final llmStyle = LlmMessageStyle.resolve(
        viewModel.style?.llmMessageStyle,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final suggestion in suggestions)
            GestureDetector(
              onTap: () => onSelectSuggestion(suggestion),
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: suggestionStyle.decoration,
                child: MarkdownBody(
                  data: suggestion,
                  styleSheet: llmStyle.markdownStyle,
                ),
              ),
            ),
        ],
      );
    },
  );
}
