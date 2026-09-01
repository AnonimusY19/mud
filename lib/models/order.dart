enum OrderStatus {
  draft,
  pendingPayment,
  paid,
  confirmed,
  preparing,
  shipped,
  completed,
  disputed,
  cancelled,
  refunded,
  failed;

  static OrderStatus fromDb(String raw) {
    switch (raw) {
      case 'draft':
        return OrderStatus.draft;
      case 'pending_payment':
        return OrderStatus.pendingPayment;
      case 'paid':
        return OrderStatus.paid;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'completed':
        return OrderStatus.completed;
      case 'disputed':
        return OrderStatus.disputed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'failed':
        return OrderStatus.failed;
      default:
        return OrderStatus.failed;
    }
  }

  String get dbValue {
    switch (this) {
      case OrderStatus.draft:
        return 'draft';
      case OrderStatus.pendingPayment:
        return 'pending_payment';
      case OrderStatus.paid:
        return 'paid';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.disputed:
        return 'disputed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.failed:
        return 'failed';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.draft:
        return 'Bozza';
      case OrderStatus.pendingPayment:
        return 'In attesa di pagamento';
      case OrderStatus.paid:
        return 'Pagato';
      case OrderStatus.confirmed:
        return 'Confermato';
      case OrderStatus.preparing:
        return 'In preparazione';
      case OrderStatus.shipped:
        return 'Spedito';
      case OrderStatus.completed:
        return 'Completato';
      case OrderStatus.disputed:
        return 'In disputa';
      case OrderStatus.cancelled:
        return 'Annullato';
      case OrderStatus.refunded:
        return 'Rimborsato';
      case OrderStatus.failed:
        return 'Fallito';
    }
  }
}

class Order {
  final String id;
  final String listingId;
  final String buyerId;
  final String sellerId;
  final String? streamChannelId;
  final String title;
  final int quantity;
  final int unitPriceCents;
  final int amountCents;
  final String currency;
  final int applicationFeeCents;
  final OrderStatus status;
  final String? stripeCheckoutSessionId;
  final String? stripePaymentIntentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;

  const Order({
    required this.id,
    required this.listingId,
    required this.buyerId,
    required this.sellerId,
    this.streamChannelId,
    required this.title,
    required this.quantity,
    required this.unitPriceCents,
    required this.amountCents,
    required this.currency,
    required this.applicationFeeCents,
    required this.status,
    this.stripeCheckoutSessionId,
    this.stripePaymentIntentId,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
  });

  double get amountEuros => amountCents / 100.0;
  double get unitPriceEuros => unitPriceCents / 100.0;
  double get feeEuros => applicationFeeCents / 100.0;

  /// Prossima azione suggerita per buyer/seller (null = nessuna).
  OrderStatus? nextAction({required bool asBuyer}) {
    if (asBuyer) {
      if (status == OrderStatus.shipped) return OrderStatus.completed;
      if (status == OrderStatus.paid ||
          status == OrderStatus.confirmed ||
          status == OrderStatus.preparing ||
          status == OrderStatus.shipped) {
        return OrderStatus.disputed;
      }
      return null;
    }
    switch (status) {
      case OrderStatus.paid:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.shipped;
      case OrderStatus.shipped:
        return OrderStatus.disputed;
      default:
        if (status == OrderStatus.paid ||
            status == OrderStatus.confirmed ||
            status == OrderStatus.preparing) {
          return OrderStatus.disputed;
        }
        return null;
    }
  }

  String? nextActionLabel({required bool asBuyer}) {
    final next = nextAction(asBuyer: asBuyer);
    if (next == null) return null;
    if (asBuyer) {
      if (next == OrderStatus.completed) return 'Conferma ricezione';
      if (next == OrderStatus.disputed) return 'Apri disputa';
    } else {
      switch (next) {
        case OrderStatus.confirmed:
          return 'Conferma ordine';
        case OrderStatus.preparing:
          return 'Segna in preparazione';
        case OrderStatus.shipped:
          return 'Segna come spedito';
        case OrderStatus.disputed:
          return 'Apri disputa';
        default:
          break;
      }
    }
    return null;
  }

  /// Per il venditore: azione primaria + opzionale disputa separata.
  OrderStatus? sellerPrimaryAction() {
    switch (status) {
      case OrderStatus.paid:
        return OrderStatus.confirmed;
      case OrderStatus.confirmed:
        return OrderStatus.preparing;
      case OrderStatus.preparing:
        return OrderStatus.shipped;
      default:
        return null;
    }
  }

  bool get canDispute =>
      status == OrderStatus.paid ||
      status == OrderStatus.confirmed ||
      status == OrderStatus.preparing ||
      status == OrderStatus.shipped;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      streamChannelId: json['stream_channel_id'] as String?,
      title: (json['title'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceCents: (json['unit_price_cents'] as num?)?.toInt() ?? 0,
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] as String?) ?? 'eur',
      applicationFeeCents: (json['application_fee_cents'] as num?)?.toInt() ?? 0,
      status: OrderStatus.fromDb((json['status'] as String?) ?? 'failed'),
      stripeCheckoutSessionId: json['stripe_checkout_session_id'] as String?,
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
    );
  }
}
