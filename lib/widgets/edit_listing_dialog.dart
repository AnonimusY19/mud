import 'package:flutter/material.dart';
import '../models/address.dart';
import '../models/listing.dart';
import '../theme/app_colors.dart';
import 'address_autocomplete_field.dart';
import 'form_fields.dart';

class EditListingDialog extends StatefulWidget {
  final Listing? listing;
  const EditListingDialog({super.key, this.listing});

  @override
  State<EditListingDialog> createState() => _EditListingDialogState();
}

class _EditListingDialogState extends State<EditListingDialog> {
  late String _type;
  late String _category;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _imageCtrl;
  late Address _address;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _type = l?.type ?? 'Vendo';
    _category = l?.category ?? kCategories.first;
    _titleCtrl = TextEditingController(text: l?.title ?? '');
    _descCtrl = TextEditingController(text: l?.description ?? '');
    _locationCtrl = TextEditingController(text: l?.location ?? '');
    _priceCtrl = TextEditingController(text: l != null ? l.price.toStringAsFixed(2) : '');
    _unitCtrl = TextEditingController(text: l?.unit ?? '');
    _qtyCtrl = TextEditingController(text: l != null ? l.quantity.toString() : '');
    _imageCtrl = TextEditingController(text: l?.imageUrl ?? '');
    _address = l?.address ?? Address(formattedAddress: l?.location ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _qtyCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titolo e prezzo sono obbligatori')),
      );
      return;
    }

    final address = _address.formattedAddress.trim().isNotEmpty
        ? _address
        : Address(formattedAddress: _locationCtrl.text.trim());

    final result = Listing(
      id: widget.listing?.id ?? '',
      userId: widget.listing?.userId ?? '',
      type: _type,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _category,
      location: address.formattedAddress,
      price: double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0,
      unit: _unitCtrl.text.trim(),
      quantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
      imageUrl: _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
      address: address,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.listing == null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isNew ? 'Nuovo annuncio' : 'Modifica annuncio',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textGrey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              formLabel('Tipo'),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      label: 'Vendo',
                      selected: _type == 'Vendo',
                      onTap: () => setState(() => _type = 'Vendo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeButton(
                      label: 'Cerco',
                      selected: _type == 'Cerco',
                      onTap: () => setState(() => _type = 'Cerco'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              formLabel('Titolo *'),
              formTextField(controller: _titleCtrl, hint: 'Es. Olio EVO extravergine toscano'),
              const SizedBox(height: 16),
              formLabel('Descrizione'),
              formTextField(controller: _descCtrl, maxLines: 3, hint: 'Descrivi il prodotto o servizio...'),
              const SizedBox(height: 16),
              formLabel('Categoria'),
              DropdownButtonFormField<String>(
                value: _category,
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              formLabel('Indirizzo'),
              AddressAutocompleteField(
                controller: _locationCtrl,
                initialAddress: _address,
                hint: 'Es. Via Roma 10, Milano',
                onAddressSelected: (address) => setState(() => _address = address),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        formLabel('Prezzo € *'),
                        formTextField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [formLabel('Unità'), formTextField(controller: _unitCtrl, hint: 'kg, pezzo...')],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [formLabel('Quantità'), formTextField(controller: _qtyCtrl, keyboardType: TextInputType.number)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              formLabel('URL Immagine'),
              formTextField(controller: _imageCtrl, hint: 'https://...'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(isNew ? 'Crea annuncio' : 'Salva modifiche', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceElevated,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}
