import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

class OtpInputBoxes extends StatelessWidget {
  const OtpInputBoxes({
    super.key,
    required this.controllers,
    required this.focusNodes,
  }) : assert(controllers.length == 6),
       assert(focusNodes.length == 6);

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var index = 0; index < controllers.length; index++)
          _OtpBox(
            controller: controllers[index],
            focusNode: focusNodes[index],
            onChanged: (value) => _handleChanged(index, value),
            onBackspaceOnEmpty: () {
              if (index > 0) {
                focusNodes[index - 1].requestFocus();
              }
            },
          ),
      ],
    );
  }

  void _handleChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _fillFrom(index, digits);
      return;
    }

    if (digits.isEmpty) {
      controllers[index].clear();
      return;
    }

    controllers[index].text = digits;
    controllers[index].selection = TextSelection.collapsed(
      offset: controllers[index].text.length,
    );

    if (index < focusNodes.length - 1) {
      focusNodes[index + 1].requestFocus();
    } else {
      focusNodes[index].unfocus();
    }
  }

  void _fillFrom(int startIndex, String digits) {
    for (var i = 0; i < controllers.length - startIndex; i++) {
      if (i >= digits.length) {
        break;
      }
      controllers[startIndex + i].text = digits[i];
    }

    final nextIndex = (startIndex + digits.length).clamp(
      0,
      controllers.length - 1,
    );
    if (digits.length >= controllers.length - startIndex) {
      focusNodes.last.unfocus();
    } else {
      focusNodes[nextIndex].requestFocus();
    }
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspaceOnEmpty,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspaceOnEmpty;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            controller.text.isEmpty) {
          onBackspaceOnEmpty();
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 42,
        height: 48,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 24 / 20,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
            border: _border(AppColors.cardBorder),
            enabledBorder: _border(AppColors.cardBorder),
            focusedBorder: _border(AppColors.deepBlue, width: 1.4),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
