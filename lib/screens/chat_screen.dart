import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SectionHeader(title: 'Chat', subtitle: 'Comunica con fornitori e acquirenti'),
          Expanded(
            child: Center(
              child: EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'Nessuna conversazione',
                subtitle: 'Contatta un annuncio per iniziare a chattare',
              ),
            ),
          ),
        ],
      ),
    );
  }
}