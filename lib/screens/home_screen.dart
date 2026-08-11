import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../widgets/listing_card.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showFilters = false;
  String _selectedCategory = 'Tutte';
  final _searchCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  static const List<String> _categories = ['Tutte', ...kCategories];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    var items = appState.listings.where((l) => l.type == 'Vendo').toList();

    if (_selectedCategory != 'Tutte') {
      items = items.where((l) => l.category == _selectedCategory).toList();
    }
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((l) => l.title.toLowerCase().contains(query)).toList();
    }
    final maxPrice = double.tryParse(_maxPriceCtrl.text.replaceAll(',', '.'));
    if (maxPrice != null) {
      items = items.where((l) => l.price <= maxPrice).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const SectionHeader(title: 'Cosa cerchi?', subtitle: 'Esplora i prodotti dei fornitori', titleSize: 30),
        const SizedBox(height: 18),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cerca annunci...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Assistente AI in arrivo 🚀')),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Cerca con AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: const Icon(Icons.tune, size: 18, color: Colors.black87),
              label: const Text('Filtri', style: TextStyle(color: Colors.black87)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        if (_showFilters) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final selected = c == _selectedCategory;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedCategory = c),
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                      backgroundColor: Colors.white,
                      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Prezzo massimo (€)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: _maxPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Nessun limite',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Nessun annuncio trovato', style: TextStyle(color: AppColors.textLightGrey))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (context, i) => ListingCard(listing: items[i]),
          ),
      ],
    );
  }
}