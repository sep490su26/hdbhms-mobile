import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:hdbhms_mobile/theme/app_colors.dart';

class OtpInputBoxes extends StatelessWidget {
  const OtpInputBoxes({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.onChanged,
  }) : assert(controllers.length == 6),
       assert(focusNodes.length == 6);

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = ((constraints.maxWidth - 40) / controllers.length)
            .clamp(38.0, 48.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var index = 0; index < controllers.length; index++)
              _OtpBox(
                key: Key('otp-box-$index'),
                width: boxWidth,
                controller: controllers[index],
                focusNode: focusNodes[index],
                onChanged: (value) {
                  _handleChanged(index, value);
                  onChanged?.call();
                },
                onBackspaceOnEmpty: () {
                  if (index > 0) {
                    focusNodes[index - 1].requestFocus();
                  }
                },
              ),
          ],
        );
      },
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
    super.key,
    required this.width,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspaceOnEmpty,
  });

  final double width;
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
        width: width,
        height: AppColors.minimumTouchTarget,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            color: AppColors.inputText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 24 / 20,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: EdgeInsets.zero,
            border: _border(AppColors.cardBorder),
            enabledBorder: _border(AppColors.cardBorder),
            focusedBorder: _border(AppColors.primary, width: 1.4),
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
