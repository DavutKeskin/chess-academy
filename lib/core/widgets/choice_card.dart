import 'package:flutter/material.dart';

import '../theme.dart';

/// Tek seçimli seçenek kartı. Dikey (ızgara) ya da yatay (liste) yerleşim.
/// Seçili: lacivert çerçeve + açık lacivert zemin; seçili değil: beyaz kart.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.horizontal = false,
    this.icon,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final align = horizontal ? TextAlign.start : TextAlign.center;
    final texts = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: align,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.navyDark : AppColors.ink,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            textAlign: align,
            style: TextStyle(fontSize: 13, height: 1.3, color: AppColors.inkMuted),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.navyLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.navy : AppColors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: horizontal
                ? Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: selected ? AppColors.navy : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: texts),
                    ],
                  )
                : Column(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 28, color: selected ? AppColors.navy : AppColors.inkMuted),
                        const SizedBox(height: 6),
                      ],
                      texts,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
