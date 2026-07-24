import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Animated pill toggle that lets the user switch between two modes
/// (e.g. Email ↔ MediLink ID).  Works with any enum or string [T].
class SegmentedToggle<T> extends StatefulWidget {
  const SegmentedToggle({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    this.padding = 6,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final double padding;

  @override
  State<SegmentedToggle<T>> createState() => _SegmentedToggleState<T>();
}

class _SegmentedToggleState<T> extends State<SegmentedToggle<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;
  int _prevIndex = 0;

  int get _selectedIndex {
    final idx = widget.values.indexOf(widget.selected);
    return idx < 0 ? 0 : idx;
  }

  @override
  void initState() {
    super.initState();
    _prevIndex = _selectedIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(covariant SegmentedToggle<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      final oldIdx = old.values.indexOf(old.selected);
      _prevIndex = oldIdx < 0 ? 0 : oldIdx;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.values.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = widget.height;
        final pad = widget.padding;
        final segmentW = (w - pad * 2) / n;

        return GestureDetector(
          onTapDown: (details) {
            final idx = (details.localPosition.dx / segmentW).floor().clamp(0, n - 1);
            if (idx != _selectedIndex) widget.onChanged(widget.values[idx]);
          },
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final t = _anim.value;
              final lerp = _prevIndex + (_selectedIndex - _prevIndex) * t;
              final pillX = pad + lerp * segmentW;

              return Container(
                height: h,
                decoration: BoxDecoration(
                  color: AppColors.mistBackground,
                  borderRadius: BorderRadius.circular(h / 2),
                ),
                padding: EdgeInsets.all(pad),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: pillX - pad,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: segmentW,
                        decoration: BoxDecoration(
                          color: AppColors.canopy,
                          borderRadius: BorderRadius.circular(h / 2 - pad),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.canopy.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(n, (i) {
                        final sel = i == _selectedIndex;
                        return Expanded(
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                color: sel ? Colors.white : AppColors.textMuted,
                              ),
                              child: Text(widget.labels[i]),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
