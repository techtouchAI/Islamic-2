import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 18,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            '— $title —',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
