import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../llm_exception.dart';
import '../../platform_helper/platform_helper.dart' as ph;
import '../../providers/interface/attachments.dart';
import '../../providers/interface/chat_message.dart';
import '../../providers/interface/llm_provider.dart';
import '../../styles/llm_chat_view_style.dart';
import '../chat_history_view.dart';
import '../chat_input/chat_input.dart';
import '../response_builder.dart';
import 'llm_response.dart';

@immutable
class LlmChatView extends StatefulWidget {
  LlmChatView({
    required LlmProvider provider,
    LlmChatViewStyle? style,
    ResponseBuilder? responseBuilder,
    LlmStreamGenerator? messageSender,
    SpeechToTextConverter? speechToText,
    List<String> suggestions = const [],
    String? welcomeMessage,
    this.onCancelCallback,
    this.onErrorCallback,
    this.cancelMessage = 'CANCEL',
    this.errorMessage = 'ERROR',
    this.enableAttachments = true,
    this.enableVoiceNotes = true,
    this.autofocus,
    this.botAvatar,
    super.key,
  }) : viewModel = ChatViewModel(
         provider: provider,
         responseBuilder: responseBuilder,
         messageSender: messageSender,
         speechToText: speechToText,
         style: style,
         suggestions: suggestions,
         welcomeMessage: welcomeMessage,
         enableAttachments: enableAttachments,
         enableVoiceNotes: enableVoiceNotes,
       );

  final bool enableAttachments;
  final bool enableVoiceNotes;
  late final ChatViewModel viewModel;
  final void Function(BuildContext context)? onCancelCallback;
  final void Function(BuildContext context, LlmException error)?
  onErrorCallback;
  final String cancelMessage;
  final String errorMessage;
  final bool? autofocus;
  Widget? botAvatar;

  @override
  State<LlmChatView> createState() => _LlmChatViewState();
}

class _LlmChatViewState extends State<LlmChatView>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  LlmResponse? _pendingPromptResponse;
  ChatMessage? _initialMessage;
  ChatMessage? _associatedResponse;
  LlmResponse? _pendingSttResponse;

  @override
  void initState() {
    super.initState();
    widget.viewModel.provider.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
    widget.viewModel.provider.removeListener(_onHistoryChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    // final chatStyle = LlmChatViewStyle.resolve(widget.viewModel.style);
    return ListenableBuilder(
      listenable: widget.viewModel.provider,
      builder:
          (context, child) => ChatViewModelProvider(
            viewModel: widget.viewModel,
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFFFFFBF5)),
              child: Column(
                children: [
                  Expanded(
                    child: ChatHistoryView(
                      controller: _scrollController,
                      botAvatar: widget.botAvatar,
                      onEditMessage:
                          _pendingPromptResponse == null &&
                                  _associatedResponse == null
                              ? _onEditMessage
                              : null,
                      onSelectSuggestion: (suggestion) {
                        _onSendMessage(suggestion, []);
                      },
                    ),
                  ),
                  ChatInput(
                    initialMessage: _initialMessage,
                    autofocus: false,
                    onCancelEdit:
                        _associatedResponse != null ? _onCancelEdit : null,
                    onSendMessage: _onSendMessage,
                    onCancelMessage:
                        _pendingPromptResponse == null
                            ? null
                            : _onCancelMessage,
                    onTranslateStt: _onTranslateStt,
                    onCancelStt:
                        _pendingSttResponse == null ? null : _onCancelStt,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _onSendMessage(
    String prompt,
    Iterable<Attachment> attachments,
  ) async {
    _initialMessage = null;
    _associatedResponse = null;

    final sendMessageStream =
        widget.viewModel.messageSender ??
        widget.viewModel.provider.sendMessageStream;

    _pendingPromptResponse = LlmResponse(
      stream: sendMessageStream(prompt, attachments: attachments),
      onUpdate: (_) => setState(() {}),
      onDone: _onPromptDone,
    );

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});

    // After updating the state, scroll to the bottom
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _scrollController.animateTo(
    //     _scrollController.position.maxScrollExtent + MediaQuery.of(context).size.height,
    //     duration: Duration(milliseconds: 300), // Adjust animation duration
    //     curve: Curves.easeInOut,
    //   );
    // });
  }

  void _onPromptDone(LlmException? error) {
    setState(() => _pendingPromptResponse = null);
    unawaited(_showLlmException(error));
  }

  void _onCancelMessage() => _pendingPromptResponse?.cancel();

  void _onEditMessage(ChatMessage message) {
    assert(_pendingPromptResponse == null);

    final history = widget.viewModel.provider.history.toList();
    assert(history.last.origin.isLlm);
    final llmMessage = history.removeLast();

    assert(history.last.origin.isUser);
    final userMessage = history.removeLast();

    widget.viewModel.provider.history = history;

    setState(() {
      _initialMessage = userMessage;
      _associatedResponse = llmMessage;
    });
  }

  Future<void> _onTranslateStt(
    XFile file,
    Iterable<Attachment> currentAttachments,
  ) async {
    assert(widget.enableVoiceNotes);
    _initialMessage = null;
    _associatedResponse = null;

    final response = StringBuffer();
    _pendingSttResponse = LlmResponse(
      stream:
          widget.viewModel.speechToText?.call(file) ??
          _convertSpeechToText(file),
      onUpdate: (text) => response.write(text),
      onDone:
          (error) async => _onSttDone(
            error,
            response.toString().trim(),
            file,
            currentAttachments,
          ),
    );

    setState(() {});
  }

  Stream<String> _convertSpeechToText(XFile file) async* {
    const prompt =
        'translate the attached audio to text; provide the result of that '
        'translation as just the text of the translation itself. be careful to '
        'separate the background audio from the foreground audio and only '
        'provide the result of translating the foreground audio.';
    final attachments = [await FileAttachment.fromFile(file)];

    yield* widget.viewModel.provider.generateStream(
      prompt,
      attachments: attachments,
    );
  }

  Future<void> _onSttDone(
    LlmException? error,
    String response,
    XFile file,
    Iterable<Attachment> attachments,
  ) async {
    assert(_pendingSttResponse != null);
    setState(() {
      _initialMessage = ChatMessage.user(response, attachments);
      _pendingSttResponse = null;
    });

    unawaited(ph.deleteFile(file));
    unawaited(_showLlmException(error));
  }

  void _onCancelStt() => _pendingSttResponse?.cancel();

  Future<void> _showLlmException(LlmException? error) async {
    if (error == null) return;

    final llmMessage = widget.viewModel.provider.history.last;
    if (llmMessage.text == null) {
      final polishedText = switch (error) {
        LlmCancelException _ =>
          "Got it — I’ve stopped that request. You can try again anytime!",
        LlmSocketException _ =>
          "Hmm, looks like there’s no internet connection right now. Let’s try again once you’re back online.",
        _ =>
          "Oops! Something went wrong on my end. Please try again in a moment.",
      };

      llmMessage.append(polishedText);
    }

    switch (error) {
      case LlmSocketException _:
        {
          await showDialog<void>(
            context: context,
            barrierDismissible: true,
            barrierColor: Colors.black.withOpacity(0.3),
            useSafeArea: true,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'No Internet Connection',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                content: const Text(
                  'Please check your internet connection and try again.',
                  style: TextStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      case LlmCancelException _:
        if (widget.onCancelCallback != null) {
          widget.onCancelCallback!(context);
        } else {
          AdaptiveSnackBar.show(context, 'LLM operation canceled by user');
        }
        break;
      case LlmFailureException _:
      case LlmException _:
        if (widget.onErrorCallback != null) {
          widget.onErrorCallback!(context, error);
        } else {
          await AdaptiveAlertDialog.show(
            context: context,
            content: Text(error.toString()),
            showOK: true,
          );
        }
    }
  }

  void _onSelectSuggestion(String suggestion) =>
      setState(() => _initialMessage = ChatMessage.user(suggestion, []));

  void _onHistoryChanged() {
    if (widget.viewModel.provider.history.isEmpty) {
      setState(() {
        _initialMessage = null;
        _associatedResponse = null;
      });
    }
  }

  void _onCancelEdit() {
    assert(_initialMessage != null);
    assert(_associatedResponse != null);

    final history = widget.viewModel.provider.history.toList();
    history.addAll([_initialMessage!, _associatedResponse!]);
    widget.viewModel.provider.history = history;

    setState(() {
      _initialMessage = null;
      _associatedResponse = null;
    });
  }
}
