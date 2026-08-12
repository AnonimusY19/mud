import 'dart:async';

import 'package:flutter/material.dart';
import '../models/address.dart';
import '../services/address_service.dart';
import '../theme/app_colors.dart';

/// Campo indirizzo con autocomplete Google Places (New).
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final Address? initialAddress;
  final ValueChanged<Address>? onAddressSelected;
  final String? hint;
  final AddressService? service;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.initialAddress,
    this.onAddressSelected,
    this.hint,
    this.service,
  });

  @override
  State<AddressAutocompleteField> createState() => _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final AddressService _service;
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _resolving = false;
  String? _error;
  int _requestId = 0;
  bool _suppressSearch = false;
  Address? _selected;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AddressService();
    _selected = widget.initialAddress;
    if ((_selected?.formattedAddress.isNotEmpty ?? false) && widget.controller.text.isEmpty) {
      widget.controller.text = _selected!.formattedAddress;
    }
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressSearch) {
      _suppressSearch = false;
      return;
    }

    _selected = null;
    _debounce?.cancel();
    final query = widget.controller.text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() => _error = null);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await _service.autocomplete(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'Nessun indirizzo trovato';
        }
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _suggestions = const [];
        _loading = false;
        _error = e is AddressServiceException ? e.message : 'Errore nella ricerca indirizzi';
      });
    }
  }

  Future<void> _select(AddressSuggestion suggestion) async {
    _debounce?.cancel();
    _requestId++;
    setState(() {
      _resolving = true;
      _suggestions = const [];
      _error = null;
    });

    try {
      final details = await _service.fetchDetails(suggestion.placeId);
      if (!mounted) return;
      _suppressSearch = true;
      widget.controller.value = TextEditingValue(
        text: details.formattedAddress,
        selection: TextSelection.collapsed(offset: details.formattedAddress.length),
      );
      _selected = details;
      widget.onAddressSelected?.call(details);
      setState(() => _resolving = false);
      _focusNode.unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = e is AddressServiceException ? e.message : 'Impossibile recuperare i dettagli';
      });
    }
  }

  Address? get selectedAddress => _selected;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Inizia a digitare un indirizzo...',
            hintStyle: const TextStyle(color: AppColors.textLightGrey),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            suffixIcon: _resolving || _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.place_outlined, color: AppColors.textGrey),
          ),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ricerca indirizzi...', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          ),
        if (_error != null && _suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTapDown: (_) => _select(_suggestions[i]),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _suggestions[i].primaryText,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (_suggestions[i].secondaryText.isNotEmpty)
                                    Text(
                                      _suggestions[i].secondaryText,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
