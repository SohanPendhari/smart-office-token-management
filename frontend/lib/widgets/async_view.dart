import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/settings/server_settings_screen.dart';
import '../services/api_service.dart';

/// Shows loading / error / data for an [AsyncValue]. During a background poll that fails, the last
/// good data stays visible instead of flashing an error.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final data = value.valueOrNull;
    if (data != null) return builder(data);
    return value.when(
      data: builder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: onRetry),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : 'Something went wrong: $error';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const ServerSettingsScreen())),
                  icon: const Icon(Icons.settings),
                  label: const Text('Server settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
