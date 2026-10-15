import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import '../core/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _unreadOnly = false;
  late AnimationController _controller;

  // Use the shared ApiClient base URL so all screens stay in sync

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadNotifications();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _getToken() => ApiClient.getToken();

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final token = await _getToken();
      final uri = Uri.parse(
          '${ApiClient.baseUrl}/notifications?unreadOnly=$_unreadOnly&pageSize=50');
      final resp = await http.get(uri,
          headers: {'Authorization': 'Bearer $token'}).timeout(
        const Duration(seconds: 10),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _notifications =
              List<Map<String, dynamic>>.from(data['notifications']);
          _loading = false;
        });
        _controller.forward(from: 0);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiClient.baseUrl}/notifications/$id/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() {
      final idx = _notifications.indexWhere((n) => n['id'] == id);
      if (idx >= 0) _notifications[idx]['isRead'] = true;
    });
  }

  Future<void> _markAllRead() async {
    final token = await _getToken();
    await http.post(
      Uri.parse('${ApiClient.baseUrl}/notifications/read-all'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  Future<void> _delete(int id) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('${ApiClient.baseUrl}/notifications/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    setState(() => _notifications.removeWhere((n) => n['id'] == id));
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'live':
        return Icons.live_tv_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'success':
        return const Color(0xFF10B981);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'live':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isRead'] == false).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF6366F1), fontSize: 13),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadNotifications,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: !_unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = false);
                    _loadNotifications();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  selected: _unreadOnly,
                  onTap: () {
                    setState(() => _unreadOnly = true);
                    _loadNotifications();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF6366F1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _NotificationCard(
                        notification: n,
                        typeIcon: _typeIcon(n['type'] ?? 'info'),
                        typeColor: _typeColor(n['type'] ?? 'info'),
                        onMarkRead: () => _markRead(n['id']),
                        onDelete: () => _delete(n['id']),
                        animationDelay: index * 50,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: Color(0xFF6366F1),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _unreadOnly
                ? "You're all caught up!"
                : 'Notifications will appear here',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF6366F1)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final Map<String, dynamic> notification;
  final IconData typeIcon;
  final Color typeColor;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;
  final int animationDelay;

  const _NotificationCard({
    required this.notification,
    required this.typeIcon,
    required this.typeColor,
    required this.onMarkRead,
    required this.onDelete,
    required this.animationDelay,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.animationDelay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    try {
      return timeago.format(DateTime.parse(isoDate));
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final isRead = n['isRead'] == true;

    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Dismissible(
          key: Key('notif_${n['id']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: GestureDetector(
            onTap: isRead ? null : widget.onMarkRead,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isRead
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFF1E1E3F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead
                      ? Colors.white.withOpacity(0.05)
                      : widget.typeColor.withOpacity(0.3),
                  width: isRead ? 1 : 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.typeIcon,
                        color: widget.typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n['title'] ?? '',
                                style: TextStyle(
                                  color: isRead
                                      ? Colors.white60
                                      : Colors.white,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.typeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['message'] ?? '',
                          style: TextStyle(
                            color:
                                isRead ? Colors.white38 : Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _timeAgo(n['createdAt']),
                          style: const TextStyle(
                            color: Colors.white30,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
