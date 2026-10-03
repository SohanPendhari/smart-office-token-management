import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive.dart';
import '../../widgets/app_card.dart';
import '../../widgets/public_app_bar.dart';
import '../../widgets/token_card.dart';
import 'token_screen.dart';

/// Tokens generated in this browser (ids are stored locally; details come from the backend).
class MyTokensScreen extends ConsumerWidget {
  const MyTokensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(myTokensProvider);
    return Scaffold(
      appBar: const PublicAppBar(title: 'My tokens'),
      body: ScrollPage(
        maxWidth: 760,
        child: ids.isEmpty
            ? AppCard(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 14),
                    const Text('No tokens yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('Pick a service on the home page to generate your first token.',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                        child: const Text('Browse services')),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('My tokens'),
                  for (final id in ids) Padding(padding: const EdgeInsets.only(bottom: 12), child: _TokenTile(id: id)),
                ],
              ),
      ),
    );
  }
}

class _TokenTile extends ConsumerWidget {
  const _TokenTile({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(tokenProvider(id));
    final token = value.valueOrNull;

    if (token == null) {
      return value.when(
        loading: () => const AppCard(child: Text('Loading...')),
        error: (e, _) => AppCard(
          child: Row(
            children: [
              Expanded(
                child: Text(e is ApiException && e.statusCode == 404 ? 'Token no longer exists' : 'Cannot load token: $e'),
              ),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => ref.read(myTokensProvider.notifier).remove(id)),
            ],
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TokenScreen(tokenId: id))),
      child: Row(
        children: [
          DepartmentBadge(code: token.departmentCode, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(token.tokenNumber,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(
                  token.isWaiting
                      ? '${token.departmentName}  •  position ${token.queuePosition}  •  ${formatWait(token.estimatedWaitSeconds)}'
                      : token.departmentName,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(token.status),
              if (token.isFinished)
                InkWell(
                  onTap: () => ref.read(myTokensProvider.notifier).remove(id),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Remove', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
