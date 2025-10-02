import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../providers/interface/attachments.dart';
import '../../platform_helper/platform_helper.dart';

/// Helper class for picking files and images
class PickerHelper {
  static const int maxPdfSizeMb = 2;
  static const int maxGalleryImages = 4;

  static Future<XFile?> openCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) return await _compressImage(photo);
    } on PlatformException {
      if (context.mounted) {
        AdaptiveSnackBar.show(context, 'Please enable the Camera permission');
      }
    }
    return null;
  }

  static Future<List<XFile>?> openGallery(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final files = <XFile>[];
      for (var i = 0; i < result.files.length && i < maxGalleryImages; i++) {
        files.add(await _compressImage(XFile(result.files[i].path!)));
      }

      if (result.files.length > maxGalleryImages && context.mounted) {
        AdaptiveSnackBar.show(
          context,
          "You can only select up to $maxGalleryImages images",
        );
      }

      return files;
    } on PlatformException {
      if (context.mounted) {
        AdaptiveSnackBar.show(context, 'Please enable the Storage permission');
      }
    }
    return null;
  }

  static Future<XFile?> openPdf(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      if (file.size > maxPdfSizeMb * 1024 * 1024 && context.mounted) {
        AdaptiveSnackBar.show(
          context,
          'Size exceeded max size (${maxPdfSizeMb}MB)',
        );
        return null;
      }

      return XFile(file.path!);
    } on PlatformException {
      if (context.mounted) {
        AdaptiveSnackBar.show(context, 'Please enable the Storage permission');
      }
    }
    return null;
  }

  static Future<XFile> _compressImage(XFile file) async {
    final targetPath = "${file.path}_compressed.jpg";
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: 80,
    );
    return compressed != null ? XFile(compressed.path) : file;
  }
}

/// AttachmentActionBar widget
class AttachmentActionBar extends StatefulWidget {
  const AttachmentActionBar({
    required this.onAttachments,
    required this.isDisabled,
    super.key,
  });

  final bool isDisabled;
  final Function(Iterable<Attachment> attachments) onAttachments;

  @override
  State<AttachmentActionBar> createState() => _AttachmentActionBarState();
}

class _AttachmentActionBarState extends State<AttachmentActionBar> {
  late final bool _canCamera;

  @override
  void initState() {
    super.initState();
    _canCamera = canTakePhoto();
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Color(0xFF061F3C),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: "Inter",
              fontWeight: FontWeight.w500,
              fontSize: 14,
              letterSpacing: 0.5,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add, color: Color(0XFF566170)),
      onPressed: () {
        if (widget.isDisabled) {
          AdaptiveSnackBar.show(context, 'Cannot add attachments anymore');
          return;
        }

        FocusManager.instance.primaryFocus?.unfocus();

        showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          builder: (context) {
            return Container(
              padding: const EdgeInsets.all(28.0),
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_canCamera)
                    _buildActionItem(
                      icon: Icons.camera_alt,
                      label: "Camera",
                      onTap: () {
                        Navigator.pop(context);
                        _pickCamera();
                      },
                    ),
                  _buildActionItem(
                    icon: Icons.image_rounded,
                    label: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickGallery();
                    },
                  ),
                  _buildActionItem(
                    icon: Icons.folder,
                    label: "File manager",
                    onTap: () {
                      Navigator.pop(context);
                      _pickPdf();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _pickCamera() => unawaited(_handleCamera());
  void _pickGallery() => unawaited(_handleGallery());
  void _pickPdf() => unawaited(_handlePdf());

  Future<void> _handleCamera() async {
    final file = await PickerHelper.openCamera(context);
    if (file != null) {
      final attachment = await ImageFileAttachment.fromFile(file);
      widget.onAttachments([attachment]);
    }
  }

  Future<void> _handleGallery() async {
    final files = await PickerHelper.openGallery(context);
    if (files != null && files.isNotEmpty) {
      final attachments = await Future.wait(
        files.map(ImageFileAttachment.fromFile),
      );
      widget.onAttachments(attachments);
    }
  }

  Future<void> _handlePdf() async {
    final file = await PickerHelper.openPdf(context);
    if (file != null) {
      final attachment = await FileAttachment.fromFile(file);
      widget.onAttachments([attachment]);
    }
  }
}
