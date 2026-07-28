import 'package:flutter/material.dart';

class ResendTimer extends StatefulWidget {
  const ResendTimer({
    super.key,
    required this.onResend,
    this.initialSeconds = 30,
  });

  final VoidCallback onResend;
  final int initialSeconds;

  @override
  State<ResendTimer> createState() => _ResendTimerState();
}

class _ResendTimerState extends State<ResendTimer> {
  late int _seconds;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds;
  }

  void start() {
    _seconds = widget.initialSeconds;
    _active = true;
    _tick();
  }

  void _tick() async {
    while (_active && _seconds > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _seconds--);
    }
    if (!mounted) return;
    setState(() => _active = false);
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  void _handleResend() {
    widget.onResend();
    start();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: 1.0,
      child: Center(
        child: _active
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Color(0xFF55708A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Resend in $_seconds s',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF55708A),
                    ),
                  ),
                ],
              )
            : GestureDetector(
                onTap: _handleResend,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Color(0xFF206B5D),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF206B5D),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
