import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'app_card.dart';

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.primary,
    this.icon = Icons.insights,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Metric(label: label, value: value, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
