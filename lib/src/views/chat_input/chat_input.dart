import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../providers/interface/attachments.dart';
import '../../providers/interface/chat_message.dart';
import '../../styles/styles.dart';
import 'attachments_action_bar.dart';
import 'attachments_view.dart';
import 'input_button.dart';
import 'input_state.dart';
import 'text_or_audio_input.dart';

@immutable
class ChatInput extends StatefulWidget {
  const ChatInput({
    required this.onSendMessage,
    required this.onTranslateStt,
    this.initialMessage,
    this.onCancelEdit,
    this.onCancelMessage,
    this.onCancelStt,
    this.autofocus = true,
    super.key,
  }) : assert(
         !(onCancelMessage != null && onCancelStt != null),
         'Cannot be submitting a prompt and doing stt at the same time',
       ),
       assert(
         !(onCancelEdit != null && initialMessage == null),
         'Cannot cancel edit of a message if no initial message is provided',
       );

  final void Function(String, Iterable<Attachment>) onSendMessage;
  final void Function(XFile file, Iterable<Attachment> attachments)
  onTranslateStt;
  final ChatMessage? initialMessage;
  final void Function()? onCancelEdit;
  final void Function()? onCancelMessage;
  final void Function()? onCancelStt;
  final bool autofocus;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _focusNode = FocusNode();
  final _textController = TextEditingController();
  final _waveController = WaveformRecorderController();
  final _attachments = <Attachment>[];

  ChatViewModel? _viewModel;
  ChatInputStyle? _inputStyle;
  LlmChatViewStyle? _chatStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = ChatViewModelProvider.of(context);
    _chatStyle = LlmChatViewStyle.resolve(_viewModel!.style);
    _inputStyle = ChatInputStyle.resolve(_viewModel!.style?.chatInputStyle);
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != null) {
      _textController.text = widget.initialMessage!.text ?? '';
      _attachments.clear();
      _attachments.addAll(widget.initialMessage!.attachments);
    } else if (oldWidget.initialMessage != null) {
      _textController.clear();
      _attachments.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          AttachmentsView(
            attachments: _attachments,
            onRemove: onRemoveAttachment,
          ),
          if (_attachments.isNotEmpty) const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder:
                (context, value, child) => ListenableBuilder(
                  listenable: _waveController,
                  builder: (context, child) {
                    return Row(
                      children: [
                        if (_focusNode.hasFocus)
                          GestureDetector(
                            onTap: () {
                              _focusNode.unfocus();
                            },
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: 8.0,
                                right: _viewModel!.enableAttachments ? 0 : 8.0,
                              ),
                              child: Icon(
                                Icons.keyboard_hide_rounded,
                                color: Color(0XFF566170),
                              ),
                            ),
                          ),
                        if (_viewModel!.enableAttachments)
                          AttachmentActionBar(
                            isDisabled: _attachments.isNotEmpty,
                            onAttachments: onAttachments,
                          ),

                        if (!_viewModel!.enableAttachments &&
                            !_focusNode.hasFocus)
                          const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Color(0xFFD9D9D9)),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    focusNode: _focusNode,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.newline,
                                    keyboardType: TextInputType.multiline,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Type a message...',
                                      border: InputBorder.none,
                                      fillColor: Colors.white,
                                      hintStyle: TextStyle(
                                        color: Color(0XFF566170),
                                        fontSize: 14,
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Transform.translate(
                                  offset: Offset(6, -0.5),
                                  child: Container(
                                    height: 40,
                                    width: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed:
                                          _inputState ==
                                                  InputState.canSubmitPrompt
                                              ? onSubmitPrompt
                                              : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  InputState get _inputState {
    if (_waveController.isRecording) return InputState.isRecording;
    if (widget.onCancelMessage != null) return InputState.canCancelPrompt;
    if (widget.onCancelStt != null) return InputState.canCancelStt;
    if (_textController.text.trim().isEmpty) {
      return _viewModel!.enableVoiceNotes
          ? InputState.canStt
          : InputState.disabled;
    }
    return InputState.canSubmitPrompt;
  }

  void onSubmitPrompt() {
    assert(_inputState == InputState.canSubmitPrompt);

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text, List.from(_attachments));
    _attachments.clear();
    _textController.clear();
  }

  void onCancelPrompt() {
    assert(_inputState == InputState.canCancelPrompt);
    widget.onCancelMessage!();
    _focusNode.requestFocus();
  }

  Future<void> onStartRecording() async {
    await _waveController.startRecording();
  }

  Future<void> onStopRecording() async {
    await _waveController.stopRecording();
  }

  Future<void> onRecordingStopped() async {
    final file = _waveController.file;
    if (file == null) {
      AdaptiveSnackBar.show(context, 'Unable to record audio');
      return;
    }
    widget.onTranslateStt(file, List.from(_attachments));
  }

  void onAttachments(Iterable<Attachment> attachments) {
    assert(_viewModel!.enableAttachments);
    setState(() => _attachments.addAll(attachments));
  }

  void onRemoveAttachment(Attachment attachment) =>
      setState(() => _attachments.remove(attachment));
}
