import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/queue.dart';
import '../../models/token.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../utils/ui.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import 'token_details_screen.dart';

/// Queue management body for one department (shown inside the staff shell).
class DepartmentQueueView extends ConsumerStatefulWidget {
  const DepartmentQueueView({super.key, required this.departmentId});

  final int departmentId;

  @override
  ConsumerState<DepartmentQueueView> createState() => _DepartmentQueueViewState();
}

class _DepartmentQueueViewState extends ConsumerState<DepartmentQueueView> {
  bool _busy = false;

  /// Runs a staff action, refreshes queue + dashboard, and reports backend errors.
  Future<void> _run(Future<Object?> Function() action, String? success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(staffQueueProvider(widget.departmentId));
      ref.invalidate(dashboardProvider);
      ref.invalidate(departmentsProvider);
      if (mounted && success != null) showSnack(context, success);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      if (e.isUnauthorized) {
        await ref.read(authProvider.notifier).logout();
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.departmentId;
    final value = ref.watch(staffQueueProvider(id));
    final user = ref.watch(authProvider).user;
    final canManage = user?.canManage(id) ?? false;
    final staff = ref.read(staffServiceProvider);

    return AsyncView<StaffQueue>(
      value: value,
      onRetry: () => ref.invalidate(staffQueueProvider(id)),
      builder: (q) {
        final paused = q.department.isPaused;

        final servingSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Now serving'),
            if (q.serving.isEmpty)
              const AppCard(
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, color: AppColors.textMuted),
                    SizedBox(width: 12),
                    Text('Nobody is being served right now.', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
            for (final t in q.serving)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ServingCard(
                  token: t,
                  canManage: canManage,
                  busy: _busy,
                  onTap: () => showTokenDetails(context, t, canManage),
                  onComplete: () => _run(() => staff.complete(t.id), '${t.tokenNumber} completed'),
                  onNoShow: () async {
                    final ok = await confirmDialog(context,
                        title: 'Mark no-show?',
                        message: t.noShowCount == 0
                            ? '${t.tokenNumber} goes to the END of the queue (first no-show).'
                            : '${t.tokenNumber} will be CANCELLED (second no-show).',
                        confirmLabel: 'No Show');
                    if (ok) await _run(() => staff.noShow(t.id), '${t.tokenNumber} marked as no-show');
                  },
                ),
              ),
          ],
        );

        final waitingSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle('Waiting queue (${q.waiting.length})'),
            AppCard(
              padding: EdgeInsets.zero,
              child: q.waiting.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: Text('The queue is empty.', style: TextStyle(color: AppColors.textMuted))),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < q.waiting.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _WaitingRow(token: q.waiting[i], onTap: () => showTokenDetails(context, q.waiting[i], canManage)),
                        ],
                      ],
                    ),
            ),
          ],
        );

        final header = AppCard(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(builder: (context, c) {
            final info = Row(
              children: [
                DepartmentBadge(code: q.department.code, size: 52),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.department.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DeptStatusPill(paused: paused),
                          Text('${q.completedToday} completed today', style: const TextStyle(color: AppColors.textMuted)),
                          Text('${q.noShowsToday} no-shows', style: const TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (canManage)
                  FilledButton.icon(
                    onPressed: (_busy || q.waiting.isEmpty)
                        ? null
                        : () => _run(() async {
                              final t = await staff.callNext(id);
                              if (mounted) showSnack(context, 'Now serving ${t.tokenNumber}');
                              return t;
                            }, null),
                    icon: const Icon(Icons.campaign),
                    label: const Text('Call next'),
                  ),
                if (canManage)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final ok = await confirmDialog(context,
                                title: paused ? 'Resume department?' : 'Pause department?',
                                message: paused
                                    ? 'Visitors will be able to generate new tokens again.'
                                    : 'Existing tokens keep working, but NEW tokens cannot be generated until you resume.',
                                confirmLabel: paused ? 'Resume' : 'Pause');
                            if (ok) {
                              await _run(() => paused ? staff.resume(id) : staff.pause(id),
                                  paused ? 'Department resumed' : 'Department paused');
                            }
                          },
                    icon: Icon(paused ? Icons.play_circle_outline : Icons.pause_circle_outline),
                    label: Text(paused ? 'Resume department' : 'Pause department'),
                  ),
              ],
            );
            if (c.maxWidth >= 760) {
              return Row(children: [Expanded(child: info), const SizedBox(width: 16), actions]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 16), actions]);
          }),
        );

        return ScrollPage(
          maxWidth: 1200,
          onRefresh: () async => ref.invalidate(staffQueueProvider(id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 20),
              if (paused)
                NoticeBox(
                    text: 'Department is PAUSED - no new tokens can be generated. Existing tokens continue as normal.',
                    color: AppColors.paused,
                    background: statusBackground('PAUSED'),
                    icon: Icons.pause_circle),
              if (!canManage)
                const NoticeBox(
                    text: 'View only: you can manage tokens of your own department.',
                    color: AppColors.textMuted,
                    background: Color(0xFFE2E8F0),
                    icon: Icons.visibility),
              if (isDesktop(context))
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: servingSection),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: waitingSection),
                  ],
                )
              else ...[
                servingSection,
                const SizedBox(height: 12),
                waitingSection,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ServingCard extends StatelessWidget {
  const _ServingCard({
    required this.token,
    required this.canManage,
    required this.busy,
    required this.onComplete,
    required this.onNoShow,
    required this.onTap,
  });

  final Token token;
  final bool canManage;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onNoShow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.serving,
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(token.tokenNumber,
                  style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: AppColors.serving)),
              const Spacer(),
              const StatusPill(),
            ],
          ),
          const SizedBox(height: 6),
          Text(token.visitorName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          Text(token.visitorMobile, style: const TextStyle(color: AppColors.textMuted)),
          if (canManage) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Complete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onNoShow,
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('No show'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key});

  @override
  Widget build(BuildContext context) =>
      Pill('SERVING', color: AppColors.serving, background: statusBackground('SERVING'), icon: Icons.play_arrow);
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.token, required this.onTap});

  final Token token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: token.priority
                  ? const Icon(Icons.star, color: AppColors.priority)
                  : Text('${token.queuePosition}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMuted, fontSize: 16)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token.tokenNumber, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                      '${token.visitorName}${token.noShowCount > 0 ? '  •  missed ${token.noShowCount}x' : ''}',
                      style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            if (isTablet(context))
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(formatWait(token.estimatedWaitSeconds), style: const TextStyle(color: AppColors.textMuted)),
              ),
            token.priority
                ? const Pill('Priority', color: AppColors.priority, background: Color(0xFFFEF3C7))
                : const Pill('Normal', color: AppColors.completed, background: Color(0xFFE2E8F0)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
