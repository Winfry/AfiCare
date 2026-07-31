import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';

class NotificationsScreen extends StatefulWidget {
  final String userRole; // 'patient', 'provider', 'admin'

  const NotificationsScreen({super.key, required this.userRole});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final supabase = Supabase.instance.client;
    final items = <NotificationItem>[];
    final now = DateTime.now();

    if (widget.userRole == 'patient') {
      try {
        final res = await supabase
            .from('appointments')
            .select('id, scheduled_at, status, chief_complaint')
            .eq('patient_id', user.id)
            .order('scheduled_at', ascending: true)
            .limit(20);
        for (final a in res as List) {
          final when = DateTime.tryParse(a['scheduled_at'] as String);
          if (when != null &&
              when.isAfter(now) &&
              (a['status'] == 'pending' || a['status'] == 'confirmed')) {
            items.add(NotificationItem(
              id: 'appt-${a['id']}',
              type: NotificationType.appointment,
              title: 'Upcoming appointment',
              message: '${a['status'] == 'confirmed' ? 'Confirmed' : 'Pending'} '
                  'appointment on ${_fmtDateTime(when)}.',
              timestamp: when,
            ));
          }
        }
      } catch (_) {}

      try {
        final res = await supabase
            .from('lab_orders')
            .select('id, test_name, ordered_at, lab_results(result_flag)')
            .eq('patient_id', user.id)
            .eq('status', 'completed')
            .order('ordered_at', ascending: false)
            .limit(10);
        for (final l in res as List) {
          final results = l['lab_results'] as List? ?? [];
          final flag = results.isNotEmpty
              ? (results.first as Map)['result_flag']
              : 'normal';
          items.add(NotificationItem(
            id: 'lab-${l['id']}',
            type: NotificationType.labResult,
            title: 'Lab results ready',
            message: 'Results for ${l['test_name']} are available'
                '${flag == 'abnormal' || flag == 'critical' ? ' — flagged as $flag' : ''}.',
            timestamp: DateTime.tryParse(l['ordered_at'] as String) ?? now,
          ));
        }
      } catch (_) {}

      try {
        final res = await supabase
            .from('consultations')
            .select('id, chief_complaint, follow_up_date')
            .eq('patient_id', user.id)
            .eq('follow_up_required', true)
            .not('follow_up_date', 'is', null)
            .order('follow_up_date', ascending: true)
            .limit(10);
        for (final c in res as List) {
          final followUp = DateTime.tryParse(c['follow_up_date'] as String);
          if (followUp != null && followUp.isAfter(now)) {
            items.add(NotificationItem(
              id: 'fu-${c['id']}',
              type: NotificationType.followUp,
              title: 'Follow-up scheduled',
              message: 'Follow-up for "${c['chief_complaint'] ?? 'your visit'}" '
                  'is due on ${_fmtDateTime(followUp)}.',
              timestamp: followUp,
            ));
          }
        }
      } catch (_) {}

      try {
        final res = await supabase
            .from('access_codes')
            .select('id, created_at, used_at')
            .eq('patient_id', user.id)
            .not('used_by', 'is', null)
            .order('used_at', ascending: false)
            .limit(10);
        for (final a in res as List) {
          final usedAt = DateTime.tryParse(a['used_at'] as String);
          items.add(NotificationItem(
            id: 'acc-${a['id']}',
            type: NotificationType.access,
            title: 'Record access granted',
            message: 'A healthcare provider accessed your medical records.',
            timestamp: usedAt ?? now,
          ));
        }
      } catch (_) {}
    } else if (widget.userRole == 'provider') {
      try {
        final res = await supabase
            .from('triage_queue')
            .select('id, chief_complaint, triage_level, check_in_time')
            .eq('status', 'waiting')
            .order('priority_score', ascending: false)
            .limit(10);
        for (final t in res as List) {
          final level = t['triage_level'] ?? 'non_urgent';
          items.add(NotificationItem(
            id: 'tri-${t['id']}',
            type: NotificationType.emergency,
            title: 'Patient in triage queue',
            message: '${t['chief_complaint'] ?? 'A patient'} is waiting'
                ' (${(level as String).replaceAll('_', ' ')}).',
            timestamp: DateTime.tryParse(t['check_in_time'] as String) ?? now,
          ));
        }
      } catch (_) {}

      try {
        final res = await supabase
            .from('messages')
            .select('id, content, created_at')
            .eq('receiver_id', user.id)
            .eq('read', false)
            .order('created_at', ascending: false)
            .limit(10);
        for (final m in res as List) {
          items.add(NotificationItem(
            id: 'msg-${m['id']}',
            type: NotificationType.consultation,
            title: 'New message',
            message: m['content'] ?? 'You have a new message.',
            timestamp: DateTime.tryParse(m['created_at'] as String) ?? now,
          ));
        }
      } catch (_) {}

      try {
        final res = await supabase
            .from('appointments')
            .select('id, scheduled_at, status, chief_complaint')
            .eq('provider_id', user.id)
            .order('scheduled_at', ascending: true)
            .limit(20);
        for (final a in res as List) {
          final when = DateTime.tryParse(a['scheduled_at'] as String);
          final isToday = when != null &&
              when.year == now.year &&
              when.month == now.month &&
              when.day == now.day &&
              when.isAfter(now);
          if (isToday) {
            items.add(NotificationItem(
              id: 'pappt-${a['id']}',
              type: NotificationType.appointment,
              title: 'Appointment today',
              message: '${a['chief_complaint'] ?? 'Appointment'} at '
                  '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}.',
              timestamp: when,
            ));
          }
        }
      } catch (_) {}
    } else {
      try {
        final res = await supabase
            .from('audit_log')
            .select('id, action, timestamp')
            .order('timestamp', ascending: false)
            .limit(10);
        for (final l in res as List) {
          items.add(NotificationItem(
            id: 'log-${l['id']}',
            type: NotificationType.system,
            title: 'System activity',
            message: (l['action'] as String).replaceAll('_', ' '),
            timestamp: DateTime.tryParse(l['timestamp'] as String) ?? now,
          ));
        }
      } catch (_) {}
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) {
      setState(() {
        _notifications
          ..clear()
          ..addAll(items.take(30));
        _isLoading = false;
      });
    }
  }

  String _fmtDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24 && diff.inHours >= 0) {
      return 'today at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final roleColor = widget.userRole == 'patient'
        ? AfiCareTheme.primaryGreen
        : widget.userRole == 'provider'
            ? AfiCareTheme.primaryBlue
            : AfiCareTheme.adminColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: roleColor,
        foregroundColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(_notifications[index], roleColor);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification, Color roleColor) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        setState(() {
          _notifications.remove(notification);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification dismissed')),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: notification.isRead ? null : roleColor.withOpacity(0.05),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotificationIcon(notification),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Semantics(
                              label: 'Unread',
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: roleColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(notification.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          if (notification.actionLabel != null) ...[
                            const Spacer(),
                            TextButton(
                              onPressed: () => _handleAction(notification),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(48, 48),
                                tapTargetSize: MaterialTapTargetSize.padded,
                              ),
                              child: Text(
                                notification.actionLabel!,
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationItem notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.appointment:
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case NotificationType.medication:
        icon = Icons.medication;
        color = Colors.purple;
        break;
      case NotificationType.access:
        icon = Icons.visibility;
        color = Colors.orange;
        break;
      case NotificationType.labResult:
        icon = Icons.science;
        color = Colors.teal;
        break;
      case NotificationType.followUp:
        icon = Icons.event_repeat;
        color = Colors.indigo;
        break;
      case NotificationType.emergency:
        icon = Icons.emergency;
        color = Colors.red;
        break;
      case NotificationType.consultation:
        icon = Icons.medical_services;
        color = Colors.green;
        break;
      case NotificationType.system:
        icon = Icons.system_update;
        color = Colors.grey;
        break;
      case NotificationType.alert:
        icon = Icons.notifications;
        color = Colors.amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: ${notification.title}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleAction(NotificationItem notification) {
    setState(() {
      notification.isRead = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: ${notification.actionLabel}'),
        backgroundColor: AfiCareTheme.primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

enum NotificationType {
  appointment,
  medication,
  access,
  labResult,
  followUp,
  emergency,
  consultation,
  system,
  alert,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final String? actionLabel;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.actionLabel,
  });
}
