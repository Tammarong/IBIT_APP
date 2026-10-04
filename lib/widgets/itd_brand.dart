import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Official ITD faculty wordmark. Never recolour, crop or stretch it.
class ItdLogo extends StatelessWidget {
  const ItdLogo({super.key, this.height = 30});

  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ITD faculty logo',
    image: true,
    child: Image.asset(
      'assets/branding/itd-header.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      excludeFromSemantics: true,
    ),
  );
}

/// Top of every tab: compact logo, page title and one line of context.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Flexible(child: ItdLogo()),
            if (trailing != null) ...[
              const SizedBox(width: AppSpace.md),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: AppSpace.lg + 4),
        Semantics(
          header: true,
          child: Text(
            title,
            style: text.headlineMedium,
            // Large headings grow less, as Android's non-linear scaling does,
            // so the controls below stay reachable at 200% text.
            textScaler: MediaQuery.textScalerOf(
              context,
            ).clamp(maxScaleFactor: 1.5),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            subtitle!,
            style: text.bodyMedium!.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }
}
