import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/payment_service.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/segmented_tabs.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _payments = PaymentService();
  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<Order> _purchases = [];
  List<Order> _sales = [];
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _payments.fetchMyOrders(asBuyer: true),
        _payments.fetchMyOrders(asBuyer: false),
      ]);
      if (!mounted) return;
      setState(() {
        _purchases = results[0];
        _sales = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _advance(Order order, OrderStatus next) async {
    setState(() => _busyOrderId = order.id);
    try {
      await _payments.advanceOrderStatus(orderId: order.id, newStatus: next);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stato aggiornato: ${next.label}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = _tab == 0 ? _purchases : _sales;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'I miei ordini',
            subtitle: 'Dal pagamento alla consegna: conferma, preparazione, spedizione',
          ),
          const SizedBox(height: 20),
          SegmentedTabs(
            labels: const ['Acquisti', 'Vendite'],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _load, child: const Text('Riprova')),
                  ],
                ),
              ),
            )
          else if (orders.isEmpty)
            Expanded(
              child: Center(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Nessun ordine',
                  subtitle: _tab == 0
                      ? 'Paga da una chat annuncio per vedere gli acquisti qui'
                      : 'Quando un acquirente paga, le vendite compaiono qui',
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _OrderTile(
                    order: orders[i],
                    asBuyer: _tab == 0,
                    busy: _busyOrderId == orders[i].id,
                    onAdvance: (status) => _advance(orders[i], status),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;
  final bool asBuyer;
  final bool busy;
  final ValueChanged<OrderStatus> onAdvance;

  const _OrderTile({
    required this.order,
    required this.asBuyer,
    required this.busy,
    required this.onAdvance,
  });

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.completed:
      case OrderStatus.confirmed:
      case OrderStatus.paid:
        return AppColors.green;
      case OrderStatus.preparing:
      case OrderStatus.shipped:
      case OrderStatus.pendingPayment:
        return AppColors.blue;
      case OrderStatus.disputed:
      case OrderStatus.refunded:
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return AppColors.danger;
      case OrderStatus.draft:
        return AppColors.textGrey;
    }
  }

  String _money(double v) => '€ ${v.toStringAsFixed(2)}';

  String _date(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year} $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    final sellerPrimary = !asBuyer ? order.sellerPrimaryAction() : null;
    final buyerComplete =
        asBuyer && order.status == OrderStatus.shipped ? OrderStatus.completed : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                _money(order.amountEuros),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Qtà ${order.quantity} · ${asBuyer ? 'Acquisto' : 'Vendita'} · Commissione ${_money(order.feeEuros)} · ${_date(order.createdAt)}',
            style: TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              order.status.label,
              style: TextStyle(
                color: _statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          if (sellerPrimary != null || buyerComplete != null || order.canDispute) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (sellerPrimary != null)
                  ElevatedButton(
                    onPressed: busy ? null : () => onAdvance(sellerPrimary),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: Text(order.nextActionLabel(asBuyer: false) ?? 'Avanti'),
                  ),
                if (buyerComplete != null)
                  ElevatedButton(
                    onPressed: busy ? null : () => onAdvance(buyerComplete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    child: const Text('Conferma ricezione'),
                  ),
                if (order.canDispute)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: Text(
                                  'Aprire una disputa?',
                                  style: TextStyle(color: AppColors.textPrimary),
                                ),
                                content: Text(
                                  'L\'altra parte verrà notificata. Usa la disputa solo in caso di problemi sull\'ordine.',
                                  style: TextStyle(color: AppColors.textGrey),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annulla'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text(
                                      'Apri disputa',
                                      style: TextStyle(color: AppColors.danger),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) onAdvance(OrderStatus.disputed);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Disputa'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
