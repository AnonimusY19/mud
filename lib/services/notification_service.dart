import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationService {
  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchMine({int limit = 50}) async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> unreadCount() async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  Future<void> markRead(String id) async {
    await _client.rpc('mark_notification_read', params: {'p_id': id});
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }
}
