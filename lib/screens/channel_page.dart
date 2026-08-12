import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../services/stream_chat_service.dart';
import '../theme/app_colors.dart';

/// Conversazione Stream a schermo intero.
class ChannelPage extends StatelessWidget {
  final Channel channel;

  const ChannelPage({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final content = StreamChannel(
      channel: channel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const StreamChannelHeader(),
        body: Column(
          children: [
            const Expanded(child: StreamMessageListView()),
            StreamMessageComposer(),
          ],
        ),
      ),
    );

    // Le route pushate sul navigator di MaterialApp sono fuori da StreamChat
    // (che avvolge solo MainShell in AppBootstrap).
    if (StreamChat.maybeOf(context) != null) {
      return content;
    }

    final stream = StreamChatService.instance;
    if (!stream.isReady) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Chat non disponibile')),
      );
    }

    return StreamChat(
      client: stream.client,
      themeData: StreamChatThemeData(),
      child: content,
    );
  }
}
