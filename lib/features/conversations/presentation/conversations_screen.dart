import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/format/relative_moment.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/conversation.dart';
import 'conversation_providers.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(appClockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.conversations.label)),
      body: AsyncStateView<List<Conversation>>(
        value: ref.watch(conversationsProvider),
        data: (BuildContext context, List<Conversation> conversations) {
          if (conversations.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: conversations.length,
            itemBuilder: (BuildContext context, int index) {
              final Conversation conversation = conversations[index];
              final DateTime? lastActivity = conversation.lastActivityAt;
              final String subtitle = lastActivity == null
                  ? 'No messages yet'
                  : 'Active ${RelativeMoment.describe(lastActivity, now: now)}';
              return ListTile(
                leading: Icon(
                  AppIcons.conversations,
                  color: conversation.unread
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(conversation.title ?? conversation.id),
                subtitle: Text(subtitle),
                trailing: conversation.unread
                    ? Icon(
                        Icons.circle,
                        size: 8,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () =>
                    context.go(AppDestination.conversations.detailPath),
              );
            },
          );
        },
      ),
    );
  }
}
