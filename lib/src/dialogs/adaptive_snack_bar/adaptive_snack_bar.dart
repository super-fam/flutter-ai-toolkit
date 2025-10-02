// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart'
    show Colors, Material;
import 'package:flutter/widgets.dart';

/// A utility class for showing adaptive snack bars in Flutter applications.
///
/// This class provides a static method to display snack bars that adapt to the
/// current application environment, showing either a Material Design snack bar
/// or a Cupertino-style snack bar based on the app's context.
@immutable
class AdaptiveSnackBar {
  /// Shows an adaptive snack bar with the given message.
  ///
  /// This method determines whether the app is using Cupertino or Material
  /// design and displays an appropriate snack bar.
  ///
  /// Parameters:
  ///   * [context]: The build context in which to show the snack bar.
  ///   * [message]: The text message to display in the snack bar.
  static void show(BuildContext context, String message) {
    showShortAlert(context, message);
  }

  /// Snackbar overlay helper
  static void showShortAlert(BuildContext context, String message) {
    final overlayState = Overlay.of(context);
    if (overlayState == null) return;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double bottomPadding = keyboardHeight > 0 ? keyboardHeight + 20 : 80;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: bottomPadding,
            left: 30,
            right: 30,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Text(
                    message,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: "Inter",
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      height: 1.33,
                      color: Colors.white
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
    );

    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }
}
