import 'package:flutter/material.dart';

class PatientSuccessAnimation extends StatefulWidget {
  const PatientSuccessAnimation({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<PatientSuccessAnimation> createState() => _PatientSuccessAnimationState();
}

class _PatientSuccessAnimationState extends State<PatientSuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) widget.onComplete();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnim,
            child: const Icon(
              Icons.check_circle_rounded,
              size: 72,
              color: Color(0xFF5D9973),
            ),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnim,
            child: const Text(
              'Phone verified',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF152A45),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _fadeAnim,
            child: const Text(
              'Welcome to AfiCare MediLink',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF55708A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
