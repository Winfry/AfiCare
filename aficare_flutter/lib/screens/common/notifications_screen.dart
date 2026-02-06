import 'package:flutter/material.dart';

import '../../utils/theme.dart';

class NotificationsScreen extends StatefulWidget {
  final String userRole; // 'patient', 'provider', 'admin'

  const NotificationsScreen({super.key, required this.userRole});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    // Mock notifications based on user role
    if (widget.userRole == 'patient') {
      _notifications.addAll([
        NotificationItem(
          id: '1',
          type: NotificationType.appointment,
          title: 'Upcoming Appointment',
          message: 'Your appointment with Dr. Sarah Mwangi is tomorrow at 10:00 AM',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          actionLabel: 'View Details',
        ),
        NotificationItem(
          id: '2',
          type: NotificationType.medication,
          title: 'Medication Reminder',
          message: 'Time to take your Metformin 500mg',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          isRead: false,
          actionLabel: 'Mark as Taken',
        ),
        NotificationItem(
          id: '3',
          type: NotificationType.access,
          title: 'Record Accessed',
          message: 'Dr. James Ochieng viewed your medical history',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
        NotificationItem(
          id: '4',
          type: NotificationType.labResult,
          title: 'Lab Results Ready',
          message: 'Your blood test results from Jan 25 are now available',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          actionLabel: 'View Results',
        ),
        NotificationItem(
          id: '5',
          type: NotificationType.followUp,
          title: 'Follow-up Due',
          message: 'Your follow-up visit for hypertension is due in 3 days',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
        ),
      ]);
    } else if (widget.userRole == 'provider') {
      _notifications.addAll([
        NotificationItem(
          id: '1',
          type: NotificationType.emergency,
          title: 'Emergency Alert',
          message: 'Patient Jane Wanjiku (ML-NBO-847291) has critical blood pressure reading',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          isRead: false,
          actionLabel: 'View Patient',
        ),
        NotificationItem(
          id: '2',
          type: NotificationType.consultation,
          title: 'New Consultation Request',
          message: 'Peter Omondi is requesting a consultation',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isRead: false,
          actionLabel: 'Accept',
        ),
        NotificationItem(
          id: '3',
          type: NotificationType.labResult,
          title: 'Lab Results Available',
          message: 'Lab results for Mary Njeri are ready for review',
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          isRead: true,
          actionLabel: 'Review',
        ),
        NotificationItem(
          id: '4',
          type: NotificationType.followUp,
          title: 'Patient Follow-up Due',
          message: '5 patients have follow-ups due this week',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
      ]);
    } else {
      _notifications.addAll([
        NotificationItem(
          id: '1',
          type: NotificationType.system,
          title: 'System Update',
          message: 'AfiCare MediLink v2.1 is now available',
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          isRead: false,
        ),
        NotificationItem(
          id: '2',
          type: NotificationType.alert,
          title: 'New User Registration',
          message: '12 new users registered today',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: true,
        ),
      ]);
    }
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
      body: _notifications.isEmpty
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
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: roleColor,
                                shape: BoxShape.circle,
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
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
