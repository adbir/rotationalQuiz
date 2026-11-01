import 'package:flutter/material.dart';

import '../../view_models/setup_view_model.dart';

/// Sign in to, or out of, Warcraft Logs.
class WarcraftLogsSection extends StatelessWidget {
  const WarcraftLogsSection({super.key, required this.viewModel});

  final SetupViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = viewModel.isSignedInToWarcraftLogs;
    final error = viewModel.warcraftLogsError;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warcraft Logs', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              signedIn
                  ? 'Signed in. Log data can be loaded with your account.'
                  : 'Sign in to load log data with your own account. '
                        'No password or secret is stored here.',
              style: theme.textTheme.bodySmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  signedIn ? Icons.check_circle : Icons.circle_outlined,
                  size: 18,
                  color: signedIn ? Colors.green : theme.disabledColor,
                ),
                const SizedBox(width: 8),
                Text(signedIn ? 'Signed in' : 'Signed out'),
                const Spacer(),
                signedIn
                    ? OutlinedButton(
                        onPressed: viewModel.signOutOfWarcraftLogs,
                        child: const Text('Sign out'),
                      )
                    : FilledButton(
                        onPressed: viewModel.signInToWarcraftLogs,
                        child: const Text('Sign in'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
