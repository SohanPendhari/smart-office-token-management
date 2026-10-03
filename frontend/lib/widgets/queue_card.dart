import 'package:flutter/material.dart';

import '../models/token.dart';
import '../utils/constants.dart';

/// One row of the visitor's live queue ("IT-018  Priority", "IT-021  YOU").
class QueueCard extends StatelessWidget {
  const QueueCard({super.key, required this.entry});
  final QueueEntry entry;

  @override
  Widget build(BuildContext context) {
    final label = entry.isYou ? 'YOU' : (entry.priority ? 'Priority' : 'Waiting');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: entry.isYou ? const Color(0xFFDBEAFE) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: entry.isYou ? AppColors.accent : AppColors.border, width: entry.isYou ? 1.5 : 1),
      ),
      child: Row(
        children: [
          if (entry.priority) ...[const Icon(Icons.star, size: 18, color: AppColors.priority), const SizedBox(width: 8)],
          Text(entry.tokenNumber,
              style: TextStyle(fontSize: 16, fontWeight: entry.isYou ? FontWeight.w800 : FontWeight.w600)),
          const Spacer(),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: entry.isYou ? AppColors.accent : (entry.priority ? AppColors.priority : AppColors.textMuted))),
        ],
      ),
    );
  }
}
