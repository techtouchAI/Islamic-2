import 'package:flutter/material.dart';
import '../../theme/app_card_theme.dart';

class AppStandardCard extends StatelessWidget {
  final Widget child;
  final double uiOpacity;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? customMargins;
  final EdgeInsetsGeometry? customPadding;

  const AppStandardCard({
    super.key,
    required this.child,
    required this.uiOpacity,
    this.onTap,
    this.customMargins,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor.withValues(alpha: uiOpacity),
      margin: customMargins ?? AppCardTheme.margins,
      elevation: AppCardTheme.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppCardTheme.borderRadius),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppCardTheme.borderRadius),
        child: Padding(
          padding: customPadding ?? AppCardTheme.padding,
          child: child,
        ),
      ),
    );
  }
}
