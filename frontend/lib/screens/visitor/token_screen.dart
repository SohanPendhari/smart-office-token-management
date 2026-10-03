import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/token.dart';
import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../utils/ui.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_view.dart';
import '../../widgets/public_app_bar.dart';
import '../../widgets/token_card.dart';
import 'queue_screen.dart';

class TokenScreen extends ConsumerStatefulWidget {
  const TokenScreen({super.key, required this.tokenId});
  final int tokenId;

  @override
  ConsumerState<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends ConsumerState<TokenScreen> {
  bool _busy = false;

  Future<void> _cancel() async {
    final ok = await confirmDialog(context,
        title: 'Cancel token?', message: 'You will lose your place in the queue.', confirmLabel: 'Cancel token');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(tokenServiceProvider).cancel(widget.tokenId);
      ref.invalidate(tokenProvider(widget.tokenId));
      ref.invalidate(departmentsProvider);
      if (mounted) showSnack(context, 'Token cancelled');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(tokenProvider(widget.tokenId));
    return Scaffold(
      appBar: const PublicAppBar(title: 'My token'),
      body: AsyncView<Token>(
        value: value,
        onRetry: () => ref.invalidate(tokenProvider(widget.tokenId)),
        builder: (t) {
          final actions = AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your visit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _Line(Icons.person_outline, t.visitorName),
                _Line(Icons.phone_outlined, t.visitorMobile),
                _Line(Icons.apartment, t.departmentName),
                const SizedBox(height: 18),
                if (!t.isFinished)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => QueueScreen(tokenId: t.id))),
                      icon: const Icon(Icons.format_list_numbered),
                      label: const Text('View live queue'),
                    ),
                  ),
                if (t.isWaiting) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.close, color: AppColors.cancelled),
                      label: const Text('Cancel token', style: TextStyle(color: AppColors.cancelled)),
                    ),
                  ),
                ],
              ],
            ),
          );

          return ScrollPage(
            maxWidth: 960,
            onRefresh: () async => ref.invalidate(tokenProvider(widget.tokenId)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.isServing)
                  NoticeBox(
                      text: 'It\'s your turn! Please go to the service counter.',
                      color: AppColors.serving,
                      background: statusBackground('SERVING'),
                      icon: Icons.notifications_active),
                if (t.status == 'COMPLETED')
                  NoticeBox(
                      text: 'Service completed. Thank you!',
                      color: AppColors.completed,
                      background: statusBackground('COMPLETED'),
                      icon: Icons.check_circle),
                if (t.status == 'CANCELLED')
                  NoticeBox(
                      text: t.noShowCount > 0
                          ? 'This token was cancelled because you were not present when called.'
                          : 'This token was cancelled.',
                      color: AppColors.cancelled,
                      background: statusBackground('CANCELLED'),
                      icon: Icons.cancel),
                if (t.isWaiting && t.noShowCount > 0)
                  NoticeBox(
                      text: 'You missed your call once and were moved to the end of the queue.',
                      color: AppColors.waiting,
                      background: statusBackground('WAITING'),
                      icon: Icons.warning_amber),
                if (isTablet(context))
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: TokenCard(token: t)),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: actions),
                    ],
                  )
                else ...[
                  TokenCard(token: t),
                  const SizedBox(height: 16),
                  actions,
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
