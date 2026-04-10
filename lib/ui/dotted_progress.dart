import 'package:flutter/material.dart';

class DottedProgress extends StatefulWidget {
  const DottedProgress({super.key});

  @override
  State<DottedProgress> createState() => _DottedProgressState();
}

class _DottedProgressState extends State<DottedProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
          return FadeTransition(
            opacity: Tween(begin: 0.2, end: 1.0).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  index * 0.15,
                  0.75 + index * 0.05,
                  curve: Curves.easeInOut,
                ),
              ),
            ),
            child: const _Dot(),
          );
        }),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.fromARGB(131, 0, 0, 0),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
