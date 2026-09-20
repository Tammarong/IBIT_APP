import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Official ITD faculty wordmark with the app section beneath it.
class ItdBrand extends StatelessWidget {
  const ItdBrand({super.key, required this.section, this.logoHeight = 48});

  final String section;
  final double logoHeight;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ITD faculty logo. $section',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: logoHeight,
          child: Image.asset(
            'assets/branding/itd-header.png',
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(width: 4, height: 17, color: AppColors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
