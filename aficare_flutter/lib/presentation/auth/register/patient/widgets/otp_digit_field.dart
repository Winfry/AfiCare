import 'package:flutter/material.dart';

class OtpDigitField extends StatefulWidget {
  const OtpDigitField({
    super.key,
    required this.onChanged,
    required this.onCompleted,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onCompleted;

  @override
  State<OtpDigitField> createState() => _OtpDigitFieldState();
}

class _OtpDigitFieldState extends State<OtpDigitField> {
  static const int _digitCount = 6;

  final List<FocusNode> _focusNodes =
      List.generate(_digitCount, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(_digitCount, (_) => TextEditingController());

  String get _code =>
      _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.removeListener(() => setState(() {}));
      node.dispose();
    }
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Paste handling
      final digits = value.replaceAll(RegExp(r'\D'), '').split('').take(_digitCount).toList();
      for (int i = 0; i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final filled = digits.length;
      if (filled == _digitCount) {
        _focusNodes[_digitCount - 1].unfocus();
        widget.onCompleted();
      } else if (filled < _digitCount) {
        _focusNodes[filled].requestFocus();
      }
      widget.onChanged(_code);
      return;
    }

    if (value.isNotEmpty) {
      _controllers[index].text = value;
      if (index < _digitCount - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        widget.onCompleted();
      }
    }
    widget.onChanged(_code);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 860;
    final boxSize = isDesktop ? 60.0 : 48.0;
    const borderRadius = BorderRadius.all(Radius.circular(12));

    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_digitCount, (index) {
          final isFocused = _focusNodes[index].hasFocus;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: boxSize,
              height: isDesktop ? 60.0 : 56.0,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                autofillHints: index == 0 ? [AutofillHints.oneTimeCode] : null,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF152A45),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide(
                      color: isFocused
                          ? const Color(0xFF206B5D)
                          : const Color(0xFFDCE3EA),
                      width: isFocused ? 2.0 : 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: const BorderSide(
                      color: Color(0xFFDCE3EA),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: const BorderSide(
                      color: Color(0xFF206B5D),
                      width: 2.0,
                    ),
                  ),
                ),
                onChanged: (v) => _onDigitChanged(index, v),
                onTapOutside: (_) => _focusNodes[index].unfocus(),
              ),
            ),
          );
        }),
      ),
    );
  }
}
