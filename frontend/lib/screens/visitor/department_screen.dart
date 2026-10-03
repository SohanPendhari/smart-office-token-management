import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/department.dart';
import '../../providers/providers.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/public_app_bar.dart';
import 'generate_token_screen.dart';

class DepartmentScreen extends ConsumerWidget {
  const DepartmentScreen({super.key, required this.departmentId});
  final int departmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(departmentProvider(departmentId));
    return Scaffold(
      appBar: PublicAppBar(title: value.valueOrNull?.name ?? 'Department'),
      body: AsyncView<Department>(
        value: value,
        onRetry: () => ref.invalidate(departmentProvider(departmentId)),
        builder: (d) {
          final queueCard = d.isPaused ? _PausedCard(d) : _QueueCard(d);
          final actionCard = _ActionCard(d);
          return ScrollPage(
            maxWidth: 960,
            onRefresh: () async => ref.invalidate(departmentProvider(departmentId)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DepartmentBadge(code: d.code, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          DeptStatusPill(paused: d.isPaused),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (isTablet(context))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: queueCard),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: actionCard),
                    ],
                  )
                else ...[
                  queueCard,
                  const SizedBox(height: 16),
                  actionCard,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard(this.d);
  final Department d;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Metric(label: 'Waiting', value: '${d.waiting}', large: true)),
              Expanded(
                  child: Metric(
                      label: 'Now serving',
                      value: d.currentlyServing.isEmpty ? '—' : d.currentlyServing.join(', '),
                      color: AppColors.serving,
                      large: true)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),
          Metric(label: 'Estimated wait for a new token', value: formatWait(d.estimatedWaitSeconds), color: AppColors.primary, large: true),
        ],
      ),
    );
  }
}

class _PausedCard extends StatelessWidget {
  const _PausedCard(this.d);
  final Department d;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(32),
      borderColor: AppColors.paused,
      child: Column(
        children: [
          const Icon(Icons.pause_circle_filled, size: 56, color: AppColors.paused),
          const SizedBox(height: 12),
          const Text('Department paused',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.paused)),
          const SizedBox(height: 10),
          const Text('New tokens are temporarily unavailable.\nPlease try again later.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.d);
  final Department d;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Get your token', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            d.isPaused
                ? 'This department is not accepting new tokens right now.'
                : 'Take a token and follow your position live. You can cancel any time before you are called.',
            style: const TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: d.isPaused
                  ? null
                  : () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => GenerateTokenScreen(department: d))),
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Generate Token'),
            ),
          ),
        ],
      ),
    );
  }
}
