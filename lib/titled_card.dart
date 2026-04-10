import 'package:flutter/material.dart';

class TitledCard extends StatelessWidget {
  final String title;
  final Widget child;

  const TitledCard({required this.title, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: Card(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: EdgeInsetsGeometry.only(top: 8),
              child: child,
            ),
          ),
        ),
        // Positionieren des Titels über dem Rand
        Positioned(
          top: -5, // versetzt über den oberen Rand
          left: 16,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
