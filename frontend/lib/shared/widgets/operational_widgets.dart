import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';

enum OperationalStatusTone {
  success,
  warning,
  danger,
  info,
  neutral,
  offline,
}

Color operationalToneColor(OperationalStatusTone tone) {
  return switch (tone) {
    OperationalStatusTone.success => AppColors.success,
    OperationalStatusTone.warning => AppColors.warning,
    OperationalStatusTone.danger => AppColors.danger,
    OperationalStatusTone.info => AppColors.info,
    OperationalStatusTone.neutral => AppColors.subtle,
    OperationalStatusTone.offline => AppColors.offline,
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = OperationalStatusTone.neutral,
    this.icon,
    this.showDot = true,
  });

  final String label;
  final OperationalStatusTone tone;
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = operationalToneColor(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
          ] else if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class OperationalBanner extends StatelessWidget {
  const OperationalBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.tone = OperationalStatusTone.info,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final OperationalStatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = operationalToneColor(tone);

    return AppCard(
      color: color.withValues(alpha: 0.09),
      borderColor: color.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

class OperationalMetric extends StatelessWidget {
  const OperationalMetric({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.tone = OperationalStatusTone.neutral,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final OperationalStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = operationalToneColor(tone);

    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.label = 'Loading operational data',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class OperationalDataRow extends StatelessWidget {
  const OperationalDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.monoMetric.copyWith(
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
