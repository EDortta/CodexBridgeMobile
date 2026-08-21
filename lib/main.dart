import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_router.dart';
import 'app/auth_gateway_binding.dart';
import 'app/conversation_repository_binding.dart';
import 'app/gateway_context_binding.dart';

/// Process entry point.
///
/// It only starts the composition root in `lib/app/`; anything a test has to
/// exercise lives there instead, since `main()` itself cannot be called from
/// one.
void main() => runApp(
  ProviderScope(
    overrides: <Override>[
      authGatewayBinding,
      gatewayContextBinding,
      conversationRepositoryBinding,
    ],
    child: CodexBridgeMobileApp(router: createAppRouter()),
  ),
);
