import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/token.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/public_app_bar.dart';
import '../../widgets/queue_card.dart';

/// Live queue for one token; refreshes by polling every few seconds.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key, required this.tokenId});
  final int tokenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(liveQueueProvider(tokenId));
    return Scaffold(
      appBar: const PublicAppBar(title: 'Live queue'),
      body: AsyncView<LiveQueue>(
        value: value,
        onRetry: () => ref.invalidate(liveQueueProvider(tokenId)),
        builder: (q) => ScrollPage(
          maxWidth: 760,
          onRefresh: () async => ref.invalidate(liveQueueProvider(tokenId)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your token: ${q.tokenNumber}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        Text(q.departmentName, style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
                      ],
                    ),
                  ),
                  const Pill('Live', color: AppColors.serving, background: Color(0xFFDCFCE7), icon: Icons.sensors),
                ],
              ),
              const SizedBox(height: 20),
              if (q.departmentStatus == 'PAUSED')
                NoticeBox(
                    text: 'This department is paused for NEW tokens. Your token stays valid.',
                    color: AppColors.paused,
                    background: statusBackground('PAUSED'),
                    icon: Icons.pause_circle),
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  spacing: 40,
                  runSpacing: 20,
                  children: [
                    Metric(
                        label: 'Currently serving',
                        value: q.currentlyServing.isEmpty ? '—' : q.currentlyServing.join(', '),
                        color: AppColors.serving),
                    if (q.status == 'WAITING') ...[
                      Metric(label: 'Ahead of you', value: '${q.peopleAhead} ${q.peopleAhead == 1 ? 'person' : 'people'}'),
                      Metric(label: 'Estimated wait', value: formatWait(q.estimatedWaitSeconds), color: AppColors.primary),
                    ] else
                      Metric(label: 'Your status', value: q.status, color: statusColor(q.status)),
                  ],
                ),
              ),
              if (q.status == 'WAITING') ...[
                const SizedBox(height: 28),
                const SectionTitle('Queue'),
                for (final e in q.queue) QueueCard(entry: e),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
