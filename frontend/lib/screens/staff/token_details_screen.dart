import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/token.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/ui.dart';
import '../../widgets/app_card.dart';
import '../../widgets/token_card.dart';

/// Opens the token details + actions (priority, transfer, complete, no-show) in a dialog.
Future<void> showTokenDetails(BuildContext context, Token token, bool canManage) {
  return showDialog<void>(
    context: context,
    builder: (_) => TokenDetailsDialog(token: token, canManage: canManage),
  );
}

class TokenDetailsDialog extends ConsumerStatefulWidget {
  const TokenDetailsDialog({super.key, required this.token, required this.canManage});

  final Token token;
  final bool canManage;

  @override
  ConsumerState<TokenDetailsDialog> createState() => _TokenDetailsDialogState();
}

class _TokenDetailsDialogState extends ConsumerState<TokenDetailsDialog> {
  int? _targetDept;
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(staffQueueProvider(widget.token.departmentId));
      ref.invalidate(departmentsProvider);
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, success);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.token;
    final staff = ref.read(staffServiceProvider);
    final departments = ref.watch(departmentsProvider);
    final canAct = widget.canManage && !t.isFinished;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DepartmentBadge(code: t.departmentCode, size: 44),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.tokenNumber, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary)),
                        Text(t.departmentName, style: const TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  StatusChip(t.status),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const Divider(height: 28),
              _Info(Icons.person_outline, 'Visitor', t.visitorName),
              _Info(Icons.phone_outlined, 'Mobile', t.visitorMobile),
              if (t.isWaiting) _Info(Icons.format_list_numbered, 'Position', '${t.queuePosition}  (${formatWait(t.estimatedWaitSeconds)})'),
              if (t.priority) _Info(Icons.star, 'Priority', 'Yes'),
              if (t.noShowCount > 0) _Info(Icons.person_off_outlined, 'No-shows', '${t.noShowCount}'),
              if (!widget.canManage)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('You can only manage tokens of your own department.', style: TextStyle(color: AppColors.textMuted)),
                ),
              if (canAct) ...[
                const Divider(height: 28),
                if (t.isServing)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _run(() => staff.complete(t.id), '${t.tokenNumber} completed'),
                          icon: const Icon(Icons.check),
                          label: const Text('Complete'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _run(() => staff.noShow(t.id), '${t.tokenNumber} marked as no-show'),
                          icon: const Icon(Icons.person_off_outlined),
                          label: const Text('No show'),
                        ),
                      ),
                    ],
                  ),
                if (t.isWaiting)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Priority', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Moves ahead of normal tokens; never interrupts the one being served'),
                    value: t.priority,
                    onChanged: _busy
                        ? null
                        : (v) => _run(() => staff.setPriority(t.id, v), v ? 'Marked as priority' : 'Priority removed'),
                  ),
                const SizedBox(height: 12),
                const Text('Transfer to another department', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                departments.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Cannot load departments: $e'),
                  data: (list) {
                    final options = list.where((d) => d.id != t.departmentId).toList();
                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            hint: const Text('Select department'),
                            items: [
                              for (final d in options) DropdownMenuItem<int>(value: d.id, child: Text(d.name)),
                            ],
                            onChanged: _busy ? null : (v) => setState(() => _targetDept = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: (_busy || _targetDept == null)
                              ? null
                              : () async {
                                  final target = options.firstWhere((d) => d.id == _targetDept);
                                  final ok = await confirmDialog(context,
                                      title: 'Transfer token?',
                                      message: '${t.tokenNumber} moves to ${target.name} and joins the end of its queue.',
                                      confirmLabel: 'Transfer');
                                  if (ok) await _run(() => staff.transfer(t.id, target.id), 'Transferred to ${target.name}');
                                },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Transfer'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 12),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
