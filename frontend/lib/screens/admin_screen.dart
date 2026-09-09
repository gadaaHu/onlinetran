import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/models.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).fetchUsers());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String value) {
    ref.read(adminProvider.notifier).fetchUsers(search: value);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin': return const Color(0xFFE040FB);
      case 'Instructor': return Theme.of(context).colorScheme.primary;
      default: return const Color(0xFF43B97F);
    }
  }

  Future<void> _showRoleDialog(UserManagementModel user) async {
    final roles = ['Student', 'Instructor', 'Admin'];
    String selected = user.primaryRole;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Role — ${user.fullName}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: roles.map((role) => RadioListTile<String>(
              value: role,
              groupValue: selected,
              onChanged: (v) => setDialogState(() => selected = v!),
              title: Text(role, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              activeColor: _roleColor(role),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(adminProvider.notifier).setUserRole(user.id, selected);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Role updated to $selected' : 'Failed to update role'),
                  backgroundColor: ok ? const Color(0xFF43B97F) : Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(UserManagementModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${user.fullName}?',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text(
          'This will permanently delete the user account and all their data. This cannot be undone.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final ok = await ref.read(adminProvider.notifier).deleteUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? 'User deleted.' : 'Failed to delete user.'),
          backgroundColor: ok ? Colors.orange : Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Management',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text('Manage all registered users, roles, and access.',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.38)),
                  prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withValues(alpha: 0.38)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colorScheme.onSurface.withValues(alpha: 0.38)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _search('');
                          },
                        )
                      : null,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        // User list
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text('Failed to load users.\nCheck that you are logged in as Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(adminProvider.notifier).fetchUsers(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary),
                  ),
                ],
              ),
            ),
            data: (users) => users.isEmpty
                ? Center(child: Text('No users found.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))))
                : RefreshIndicator(
                    onRefresh: () => ref.read(adminProvider.notifier).fetchUsers(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: users.length,
                      itemBuilder: (ctx, i) => _UserTile(
                        user: users[i],
                        roleColor: _roleColor(users[i].primaryRole),
                        onChangeRole: () => _showRoleDialog(users[i]),
                        onToggleStatus: () async {
                          final ok = await ref
                              .read(adminProvider.notifier)
                              .toggleUserStatus(users[i].id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(ok
                                  ? users[i].isActive
                                      ? 'Account disabled.'
                                      : 'Account enabled.'
                                  : 'Failed to update status.'),
                              backgroundColor: ok ? Colors.orange : Colors.red,
                            ));
                          }
                        },
                        onDelete: () => _confirmDelete(users[i]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserManagementModel user;
  final Color roleColor;
  final VoidCallback onChangeRole;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.roleColor,
    required this.onChangeRole,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: roleColor.withValues(alpha: 0.2),
              radius: 24,
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '?',
                style: TextStyle(
                    color: roleColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user.fullName,
                          style: TextStyle(
                              color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (!user.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Disabled',
                              style: TextStyle(color: Colors.red, fontSize: 10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      // Role chip
                      GestureDetector(
                        onTap: onChangeRole,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(user.primaryRole,
                                  style: TextStyle(color: roleColor, fontSize: 11)),
                              const SizedBox(width: 4),
                              Icon(Icons.edit, size: 10, color: roleColor),
                            ],
                          ),
                        ),
                      ),
                      // Enrollment count chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${user.enrollmentCount} courses',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons
            Column(
              children: [
                // Enable/Disable toggle
                Tooltip(
                  message: user.isActive ? 'Disable account' : 'Enable account',
                  child: IconButton(
                    icon: Icon(
                      user.isActive ? Icons.lock_open : Icons.lock,
                      color: user.isActive ? Colors.orange : const Color(0xFF43B97F),
                      size: 20,
                    ),
                    onPressed: onToggleStatus,
                  ),
                ),
                // Delete
                Tooltip(
                  message: 'Delete user',
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
