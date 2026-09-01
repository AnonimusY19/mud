import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = [];

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
      final items = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _markAll() async {
    await _service.markAllRead();
    await _load();
  }

  Future<void> _open(AppNotification n) async {
    if (n.isUnread) {
      await _service.markRead(n.id);
      if (!mounted) return;
      setState(() {
        final i = _items.indexWhere((e) => e.id == n.id);
        if (i >= 0) {
          _items[i] = AppNotification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            data: n.data,
            createdAt: n.createdAt,
            readAt: DateTime.now(),
          );
        }
      });
    }
  }

  String _date(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year} $hh:$mi';
  }

  IconData _icon(String type) {
    if (type.contains('paid')) return Icons.payments_outlined;
    if (type.contains('shipped')) return Icons.local_shipping_outlined;
    if (type.contains('completed')) return Icons.check_circle_outline;
    if (type.contains('disputed')) return Icons.report_outlined;
    if (type.contains('chat')) return Icons.chat_bubble_outline;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifiche'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (_items.any((e) => e.isUnread))
            TextButton(onPressed: _markAll, child: const Text('Segna tutte')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      TextButton(onPressed: _load, child: const Text('Riprova')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.notifications_none,
                        title: 'Nessuna notifica',
                        subtitle:
                            'Qui vedrai pagamenti, nuovi ordini e aggiornamenti di stato. I messaggi chat restano nella sezione Chat.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          const SectionHeader(
                            title: 'Attività',
                            subtitle: 'Aggiornamenti su ordini e pagamenti',
                          ),
                          const SizedBox(height: 16),
                          ..._items.map((n) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: n.isUnread
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _open(n),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(_icon(n.type), color: AppColors.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                n.title,
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: n.isUnread
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                n.body,
                                                style: TextStyle(
                                                  color: AppColors.textGrey,
                                                  fontSize: 13,
                                                  height: 1.35,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _date(n.createdAt),
                                                style: TextStyle(
                                                  color: AppColors.textLightGrey,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (n.isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(top: 6, left: 8),
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }
}
