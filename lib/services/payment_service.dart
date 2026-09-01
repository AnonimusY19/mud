import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class StripeConnectStatus {
  final String? stripeAccountId;
  final bool chargesEnabled;
  final bool detailsSubmitted;
  final bool ready;

  const StripeConnectStatus({
    this.stripeAccountId,
    required this.chargesEnabled,
    required this.detailsSubmitted,
    required this.ready,
  });

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    return StripeConnectStatus(
      stripeAccountId: json['stripeAccountId'] as String?,
      chargesEnabled: json['chargesEnabled'] == true,
      detailsSubmitted: json['detailsSubmitted'] == true,
      ready: json['ready'] == true,
    );
  }
}

class CheckoutResult {
  final String orderId;
  final String checkoutUrl;
  final int amountCents;

  const CheckoutResult({
    required this.orderId,
    required this.checkoutUrl,
    required this.amountCents,
  });
}

class PaymentService {
  PaymentService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  String _friendlyError(Object e) {
    Map? details;
    if (e is FunctionException) {
      final d = e.details;
      if (d is Map) {
        details = d;
      } else if (d is String) {
        return d;
      }
    }
    final raw = (details?['error'] ?? e).toString();
    if (raw.contains('signed up for Connect') || raw.contains('dashboard.stripe.com/connect')) {
      return 'Attiva Stripe Connect sul tuo account piattaforma: '
          'apri https://dashboard.stripe.com/connect e completa la registrazione, '
          'poi riprova.';
    }
    return raw.replaceFirst('Bad state: ', '').replaceFirst('Exception: ', '');
  }

  Map<String, dynamic> _requireMap(FunctionResponse res, String label) {
    final data = res.data;
    if (data is! Map) {
      throw StateError('Risposta $label non valida');
    }
    final map = Map<String, dynamic>.from(data);
    if (map['error'] != null) {
      throw StateError(map['error'].toString());
    }
    return map;
  }

  Future<StripeConnectStatus> fetchConnectStatus() async {
    try {
      final res = await _client.functions.invoke(
        'stripe-connect',
        body: {'action': 'status'},
      );
      return StripeConnectStatus.fromJson(_requireMap(res, 'stripe-connect'));
    } catch (e) {
      throw StateError(_friendlyError(e));
    }
  }

  Future<String> startConnectOnboarding() async {
    try {
      final res = await _client.functions.invoke(
        'stripe-connect',
        body: {
          'action': 'onboard',
          // Fallback se APP_URL secret è assente/invalido (es. localhost:XXXX).
          'appUrl': (dotenv.env['SUPABASE_URL'] ?? '').trim(),
        },
      );
      final data = _requireMap(res, 'stripe-connect');
      final url = data['url']?.toString();
      if (url == null || url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
        throw StateError('URL onboarding Stripe mancante o non valido');
      }
      return url;
    } catch (e) {
      throw StateError(_friendlyError(e));
    }
  }

  Future<CheckoutResult> createCheckout({
    required String listingId,
    required int quantity,
    String? streamChannelId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'stripe-checkout',
        body: {
          'listingId': listingId,
          'quantity': quantity,
          if (streamChannelId != null && streamChannelId.isNotEmpty)
            'streamChannelId': streamChannelId,
        },
      );
      final data = _requireMap(res, 'stripe-checkout');
      final url = data['checkoutUrl']?.toString();
      final orderId = data['orderId']?.toString();
      if (url == null || url.isEmpty || orderId == null || orderId.isEmpty) {
        throw StateError('Checkout incompleto');
      }
      return CheckoutResult(
        orderId: orderId,
        checkoutUrl: url,
        amountCents: (data['amountCents'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      throw StateError(_friendlyError(e));
    }
  }

  Future<List<Order>> fetchMyOrders({required bool asBuyer}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    final col = asBuyer ? 'buyer_id' : 'seller_id';
    final rows = await _client
        .from('orders')
        .select()
        .eq(col, uid)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Order> advanceOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
  }) async {
    try {
      final res = await _client.rpc(
        'advance_order_status',
        params: {
          'p_order_id': orderId,
          'p_new_status': newStatus.dbValue,
        },
      );
      if (res is Map) {
        return Order.fromJson(Map<String, dynamic>.from(res));
      }
      if (res is List && res.isNotEmpty && res.first is Map) {
        return Order.fromJson(Map<String, dynamic>.from(res.first as Map));
      }
      throw StateError('Risposta stato ordine non valida');
    } catch (e) {
      throw StateError(_friendlyError(e));
    }
  }
}
