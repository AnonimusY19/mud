import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import '../utils/auth_navigation.dart';
import '../widgets/listing_card.dart';

class HomeScreen extends StatefulWidget {
  final bool isGuest;

  const HomeScreen({super.key, this.isGuest = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showFilters = false;
  String _selectedCategory = 'Tutte';
  String _sort = 'recent';
  int _visibleCount = 8;
  final _searchCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  static const List<String> _categories = ['Tutte', ...kCategories];
  static const _suggestions = ['PET Riciclato', 'Farina 00', 'Pallet EPAL', 'Logistica'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  List<Listing> _filtered(AppState appState) {
    var items = appState.listings.toList();

    if (_selectedCategory != 'Tutte') {
      items = items.where((l) => l.category == _selectedCategory).toList();
    }
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items.where((l) {
        final hay = '${l.displayTitle} ${l.displayCompanyName} ${l.description} ${l.category}'.toLowerCase();
        return hay.contains(query);
      }).toList();
    }
    final maxPrice = double.tryParse(_maxPriceCtrl.text.replaceAll(',', '.'));
    if (maxPrice != null) {
      items = items.where((l) => l.price <= maxPrice).toList();
    }

    switch (_sort) {
      case 'price_asc':
        items.sort((a, b) => a.price.compareTo(b.price));
      case 'price_desc':
        items.sort((a, b) => b.price.compareTo(a.price));
      default:
        break;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final all = _filtered(appState);
    final items = all.take(_visibleCount).toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _HeroSearch(
          wide: wide,
          searchCtrl: _searchCtrl,
          showFilters: _showFilters,
          onToggleFilters: () => setState(() => _showFilters = !_showFilters),
          onSearchChanged: () => setState(() {}),
          onSuggestion: (s) {
            _searchCtrl.text = s;
            setState(() {});
          },
          onAiSearch: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Assistente AI in arrivo')),
            );
          },
        )),
        if (_showFilters)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 0, wide ? 48 : 20, 8),
              child: _FiltersPanel(
                categories: _categories,
                selectedCategory: _selectedCategory,
                maxPriceCtrl: _maxPriceCtrl,
                onCategory: (c) => setState(() => _selectedCategory = c),
                onPriceChanged: () => setState(() {}),
              ),
            ),
          ),
        if (widget.isGuest)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 8, wide ? 48 : 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blueBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Stai navigando come ospite: vedi le preview degli annunci. Accedi per contattare i fornitori, chat e ordini.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.35),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => openAuthScreen(context),
                      child: const Text('Accedi', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 28, wide ? 48 : 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ultimi Annunci Pubblicati',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Transazioni sicure garantite tra aziende verificate.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    dropdownColor: AppColors.surfaceElevated,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'recent', child: Text('Ordina per: Più recenti')),
                      DropdownMenuItem(value: 'price_asc', child: Text('Prezzo crescente')),
                      DropdownMenuItem(value: 'price_desc', child: Text('Prezzo decrescente')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sort = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (appState.listingsLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('Nessun annuncio trovato', style: TextStyle(color: AppColors.textLightGrey)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 0, wide ? 48 : 20, 16),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final crossAxisCount = width >= 1100
                    ? 4
                    : width >= 800
                        ? 3
                        : 2;
                final childAspectRatio = crossAxisCount >= 4
                    ? 0.82
                    : crossAxisCount == 3
                        ? 0.76
                        : 0.70;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => ListingCard(
                      listing: items[i],
                      isGuestPreview: widget.isGuest,
                    ),
                    childCount: items.length,
                  ),
                );
              },
            ),
          ),
        if (!appState.listingsLoading && all.length > _visibleCount)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _visibleCount += 8),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  label: const Text('Carica Altri Annunci'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: _SiteFooter()),
      ],
    );
  }
}

class _HeroSearch extends StatelessWidget {
  final bool wide;
  final TextEditingController searchCtrl;
  final bool showFilters;
  final VoidCallback onToggleFilters;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onAiSearch;

  const _HeroSearch({
    required this.wide,
    required this.searchCtrl,
    required this.showFilters,
    required this.onToggleFilters,
    required this.onSearchChanged,
    required this.onSuggestion,
    required this.onAiSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 36, wide ? 48 : 20, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.isDark
              ? const [Color(0xFF0A1628), Color(0xFF0D1F3A), Color(0xFF0A1628)]
              : const [Color(0xFFE8F0FE), Color(0xFFF4F7FB), Color(0xFFF4F7FB)],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'LA PIATTAFORMA B2B PER L\'INDUSTRIA ITALIANA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Cosa cerchi?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: wide ? 44 : 34,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _searchField()),
                        const SizedBox(width: 8),
                        _filtersBtn(),
                        const SizedBox(width: 8),
                        _aiBtn(),
                      ],
                    )
                  : Column(
                      children: [
                        _searchField(),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _filtersBtn()),
                            const SizedBox(width: 8),
                            Expanded(child: _aiBtn()),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _HomeScreenState._suggestions.map((s) {
              return ActionChip(
                label: Text(s),
                onPressed: () => onSuggestion(s),
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(color: AppColors.border),
                labelStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: searchCtrl,
      onChanged: (_) => onSearchChanged(),
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Cerca materiali riciclati, imballaggi, servizi logistici o macchinari...',
        hintStyle: TextStyle(color: AppColors.textLightGrey, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: AppColors.textGrey),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _filtersBtn() {
    return OutlinedButton.icon(
      onPressed: onToggleFilters,
      icon: Icon(Icons.tune, size: 18, color: showFilters ? AppColors.primary : AppColors.textPrimary),
      label: Text('Filtri', style: TextStyle(color: showFilters ? AppColors.primary : AppColors.textPrimary)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: showFilters ? AppColors.primary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _aiBtn() {
    return ElevatedButton.icon(
      onPressed: onAiSearch,
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: const Text('Cerca con AI'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final TextEditingController maxPriceCtrl;
  final ValueChanged<String> onCategory;
  final VoidCallback onPriceChanged;

  const _FiltersPanel({
    required this.categories,
    required this.selectedCategory,
    required this.maxPriceCtrl,
    required this.onCategory,
    required this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Categoria', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((c) {
              final selected = c == selectedCategory;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => onCategory(c),
                selectedColor: AppColors.primary,
                showCheckmark: false,
                labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                backgroundColor: AppColors.surfaceElevated,
                shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Prezzo massimo (€)', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: maxPriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onPriceChanged(),
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Nessun limite',
              hintStyle: TextStyle(color: AppColors.textLightGrey),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: EdgeInsets.fromLTRB(wide ? 48 : 20, 36, wide ? 48 : 20, 24),
      decoration: BoxDecoration(
        color: Color(0xFF08121F),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MUD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      const SizedBox(height: 10),
                      Text(
                        'Il marketplace B2B per l\'industria italiana: materiali, imballaggi, logistica e macchinari tra aziende verificate.',
                        style: TextStyle(color: AppColors.textGrey, height: 1.4, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(child: _footerCol('PIATTAFORMA', const ['Chi siamo', 'Come funziona', 'Tariffe e piani', 'FAQ per Imprese'])),
                Expanded(child: _footerCol('ASSISTENZA', const ['Centro Supporto', 'Segnala un problema', 'Guida alla Sicurezza'])),
                Expanded(child: _footerCol('CONTATTI', const ['info@mudmarketplace.it', '+39 02 0000 0000', 'Milano, Italia'])),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MUD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Text(
                  'Il marketplace B2B per l\'industria italiana: materiali, imballaggi, logistica e macchinari tra aziende verificate.',
                  style: TextStyle(color: AppColors.textGrey, height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 24),
                _footerCol('PIATTAFORMA', const ['Chi siamo', 'Come funziona', 'Tariffe e piani', 'FAQ per Imprese']),
                _footerCol('ASSISTENZA', const ['Centro Supporto', 'Segnala un problema', 'Guida alla Sicurezza']),
                _footerCol('CONTATTI', const ['info@mudmarketplace.it', '+39 02 0000 0000', 'Milano, Italia']),
              ],
            ),
          const SizedBox(height: 28),
          Divider(color: AppColors.border),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '© 2026 MUD Marketplace · P.IVA 00000000000',
                style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
              ),
              Text(
                'Privacy Policy  ·  Termini e Condizioni  ·  Cookie Policy',
                style: TextStyle(color: AppColors.textLightGrey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _footerCol(String title, List<String> links) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.textLightGrey, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 12),
          for (final l in links) ...[
            Text(l, style: TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.7)),
          ],
        ],
      ),
    );
  }
}
