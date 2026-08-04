import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/navigation/app_destinations.dart';
import '../../../core/presentation/async_state_view.dart';
import '../domain/conversation.dart';
import 'conversation_providers.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(AppDestination.conversations.label)),
      body: AsyncStateView<List<Conversation>>(
        value: ref.watch(conversationsProvider),
        data: (BuildContext context, List<Conversation> conversations) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: conversations.length,
            itemBuilder: (BuildContext context, int index) {
              final Conversation conversation = conversations[index];
              return ListTile(
                leading: const Icon(AppIcons.conversations),
                title: Text(conversation.title),
                subtitle: Text(conversation.lastMessage),
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
