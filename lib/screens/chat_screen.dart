import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../services/stream_chat_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'channel_page.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  StreamChannelListController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = StreamChatService.instance;
    if (stream.isReady && _controller == null) {
      final userId = stream.client.state.currentUser!.id;
      _controller = StreamChannelListController(
        client: stream.client,
        filter: Filter.and([
          Filter.equal('type', 'messaging'),
          Filter.in_('members', [userId]),
        ]),
        channelStateSort: [const SortOption.desc('last_message_at')],
        limit: 30,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stream = StreamChatService.instance;

    if (!stream.isConfigured || !stream.isReady || _controller == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Chat', subtitle: 'Comunica con fornitori e acquirenti'),
            Expanded(
              child: Center(
                child: EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat non configurata',
                  subtitle: 'Aggiungi STREAM_API_KEY e STREAM_API_SECRET in .env, poi riaccedi',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Chat', subtitle: 'Conversazioni legate agli annunci'),
          const SizedBox(height: 12),
          Expanded(
            child: StreamChannelListView(
              controller: _controller!,
              emptyBuilder: (_) => const Center(
                child: EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Nessuna conversazione',
                  subtitle: 'Tocca Contatta su un annuncio per iniziare',
                ),
              ),
              onChannelTap: (channel) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChannelPage(channel: channel)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
