import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/listing_service.dart';
import '../services/payment_service.dart';
import '../services/stream_chat_service.dart';
import '../theme/app_colors.dart';

/// Conversazione Stream a schermo intero (+ pagamento Stripe sull'annuncio).
class ChannelPage extends StatelessWidget {
  final Channel channel;

  const ChannelPage({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final content = StreamChannel(
      channel: channel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: StreamChannelHeader(
          trailing: _PayListingButton(channel: channel),
        ),
        body: Column(
          children: [
            const Expanded(child: StreamMessageListView()),
            StreamMessageComposer(),
          ],
        ),
      ),
    );

    if (StreamChat.maybeOf(context) != null) {
      return content;
    }

    final stream = StreamChatService.instance;
    if (!stream.isReady) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: Text('Chat non disponibile')),
      );
    }

    return StreamChat(
      client: stream.client,
      themeData: StreamChatThemeData(),
      child: content,
    );
  }
}

class _PayListingButton extends StatefulWidget {
  final Channel channel;

  const _PayListingButton({required this.channel});

  @override
  State<_PayListingButton> createState() => _PayListingButtonState();
}

class _PayListingButtonState extends State<_PayListingButton> {
  bool _busy = false;
  bool _isSeller = false;
  bool _ready = false;

  String? get _listingId {
    final raw = widget.channel.extraData['listing_id'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return id.isEmpty ? null : id;
  }

  String? get _sellerIdFromChannel {
    final raw = widget.channel.extraData['seller_id'];
    if (raw == null) return null;
    final id = raw.toString().trim();
    return id.isEmpty ? null : id;
  }

  @override
  void initState() {
    super.initState();
    _resolveSeller();
  }

  Future<void> _resolveSeller() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null || _listingId == null) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    final fromChannel = _sellerIdFromChannel;
    if (fromChannel != null) {
      if (mounted) {
        setState(() {
          _isSeller = fromChannel == me;
          _ready = true;
        });
      }
      return;
    }

    // Chat create prima di seller_id: ricava dal listing.
    try {
      final listing = await ListingService().fetchById(_listingId!);
      if (!mounted) return;
      setState(() {
        _isSeller = listing?.userId == me;
        _ready = true;
      });
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _onPayPressed() async {
    final listingId = _listingId;
    if (listingId == null) {
      _toast('Questa chat non è collegata a un annuncio');
      return;
    }

    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) {
      _toast('Sessione non valida');
      return;
    }

    setState(() => _busy = true);
    try {
      final listing = await ListingService().fetchById(listingId);
      if (!mounted) return;
      if (listing == null) {
        _toast('Annuncio non trovato');
        return;
      }
      if (listing.userId == me) {
        setState(() => _isSeller = true);
        return;
      }

      final qty = await showDialog<int>(
        context: context,
        builder: (ctx) => _PayQuantityDialog(
          title: listing.displayTitle,
          unitPrice: listing.price,
          unit: listing.unit,
          maxQuantity: listing.quantity < 1 ? 1 : listing.quantity,
        ),
      );
      if (qty == null || !mounted) return;

      final checkout = await PaymentService().createCheckout(
        listingId: listingId,
        quantity: qty,
        streamChannelId: widget.channel.id,
      );

      final uri = Uri.parse(checkout.checkoutUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _toast('Impossibile aprire Stripe Checkout');
        return;
      }

      try {
        await widget.channel.sendMessage(
          Message(
            text:
                'Ho avviato un pagamento Stripe per "${listing.displayTitle}" '
                '(qtà $qty, € ${(checkout.amountCents / 100).toStringAsFixed(2)}).',
          ),
        );
      } catch (_) {
        // Il pagamento è già aperto: messaggio chat non bloccante.
      }
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_listingId == null || !_ready || _isSeller) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Paga con Stripe',
      onPressed: _busy ? null : _onPayPressed,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.payments_outlined),
    );
  }
}

class _PayQuantityDialog extends StatefulWidget {
  final String title;
  final double unitPrice;
  final String unit;
  final int maxQuantity;

  const _PayQuantityDialog({
    required this.title,
    required this.unitPrice,
    required this.unit,
    required this.maxQuantity,
  });

  @override
  State<_PayQuantityDialog> createState() => _PayQuantityDialogState();
}

class _PayQuantityDialogState extends State<_PayQuantityDialog> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = 1;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.unitPrice * _qty;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Paga con Stripe', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '€ ${widget.unitPrice.toStringAsFixed(2)} / ${widget.unit}',
            style: TextStyle(color: AppColors.textGrey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Quantità', style: TextStyle(color: AppColors.textPrimary)),
              const Spacer(),
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_qty', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: _qty < widget.maxQuantity ? () => setState(() => _qty++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Totale: € ${total.toStringAsFixed(2)}',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _qty),
          child: const Text('Vai a Stripe'),
        ),
      ],
    );
  }
}
