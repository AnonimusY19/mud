import 'package:flutter/material.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_tabs.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'I miei ordini', subtitle: 'Traccia acquisti e vendite con pagamenti in-app'),
          const SizedBox(height: 20),
          SegmentedTabs(labels: const ['Acquisti', 'Vendite'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          Expanded(
            child: Center(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nessun ordine',
                subtitle: _tab == 0 ? 'I tuoi acquisti appariranno qui' : 'Le tue vendite appariranno qui',
              ),
            ),
          ),
        ],
      ),
    );
  }
}