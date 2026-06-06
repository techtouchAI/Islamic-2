import 'package:flutter/material.dart';

class PaginationFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const PaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final bool canGoPrevious = currentPage > 1;
    final bool canGoNext = currentPage < totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Button
            _PaginationButton(
              label: 'السابق',
              icon: Icons.chevron_right,
              onPressed: canGoPrevious ? onPrevious : null,
            ),

            // Page Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الصفحة $currentPage من $totalPages',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),

            // Next Button
            _PaginationButton(
              label: 'التالي',
              icon: Icons.chevron_left,
              isReversed: true,
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isReversed;

  const _PaginationButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isReversed = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? Theme.of(context).primaryColor : Colors.grey[300],
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (!isReversed) Icon(icon, size: 18, color: enabled ? Colors.white : Colors.grey[500]),
              if (!isReversed) const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.grey[500],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (isReversed) const SizedBox(width: 4),
              if (isReversed) Icon(icon, size: 18, color: enabled ? Colors.white : Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}
