import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../core/models.dart';

enum UserRoleFilter { all, students, instructors, admins, suspended }

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchCtrl = TextEditingController();
  UserRoleFilter _currentFilter = UserRoleFilter.all;

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
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF9333EA);
      case 'instructor':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _showCreateUserDialog() async {
    final formKey = GlobalKey<FormState>();
    final fNameCtrl = TextEditingController();
    final lNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'Student';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_add_rounded, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text('Create New User', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: fNameCtrl,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: lNameCtrl,
                              style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                        decoration: const InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                        validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                        decoration: const InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: Icon(Icons.lock_outline, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Assigned Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.8))),
                      const SizedBox(height: 6),
                      Row(
                        children: ['Student', 'Instructor', 'Admin'].map((role) {
                          final isSelected = selectedRole == role;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: ChoiceChip(
                                label: Text(role, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : colorScheme.onSurface)),
                                selected: isSelected,
                                selectedColor: _roleColor(role),
                                onSelected: (val) {
                                  if (val) setDialogState(() => selectedRole = role);
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Create User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(ctx);
                    final err = await ref.read(adminProvider.notifier).createUser(
                          fNameCtrl.text.trim(),
                          lNameCtrl.text.trim(),
                          emailCtrl.text.trim(),
                          passCtrl.text,
                          selectedRole,
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(err == null ? 'Account created for ${emailCtrl.text}!' : 'Error: $err'),
                        backgroundColor: err == null ? const Color(0xFF10B981) : Colors.red,
                      ));
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
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
                  backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
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
        // Header & Quick Action Row
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('👥 ', style: TextStyle(fontSize: 24)),
                          Text('User Management',
                              style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Full lifecycle control over accounts, roles, and platform permissions.',
                          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh list',
                        onPressed: () => ref.read(adminProvider.notifier).fetchUsers(search: _searchCtrl.text),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('New User'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _showCreateUserDialog,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI Stats Cards (when data loaded)
              usersAsync.when(
                data: (users) {
                  final total = users.length;
                  final active = users.countWhere((u) => u.isActive);
                  final instructors = users.countWhere((u) => u.roles.any((r) => r.toLowerCase() == 'instructor'));
                  final admins = users.countWhere((u) => u.roles.any((r) => r.toLowerCase() == 'admin'));

                  return Row(
                    children: [
                      _StatCard(title: 'Total Users', value: '$total', color: colorScheme.primary),
                      const SizedBox(width: 10),
                      _StatCard(title: 'Active Accounts', value: '$active', color: const Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      _StatCard(title: 'Instructors', value: '$instructors', color: const Color(0xFF0284C7)),
                      const SizedBox(width: 10),
                      _StatCard(title: 'Admins', value: '$admins', color: const Color(0xFF9333EA)),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 14),

              // Search bar
              TextField(
                controller: _searchCtrl,
                onChanged: _search,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or role...',
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

              const SizedBox(height: 12),

              // Role Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipItem(
                      label: 'All Users',
                      selected: _currentFilter == UserRoleFilter.all,
                      onSelected: () => setState(() => _currentFilter = UserRoleFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Students',
                      selected: _currentFilter == UserRoleFilter.students,
                      onSelected: () => setState(() => _currentFilter = UserRoleFilter.students),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Instructors',
                      selected: _currentFilter == UserRoleFilter.instructors,
                      onSelected: () => setState(() => _currentFilter = UserRoleFilter.instructors),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Admins',
                      selected: _currentFilter == UserRoleFilter.admins,
                      onSelected: () => setState(() => _currentFilter = UserRoleFilter.admins),
                    ),
                    const SizedBox(width: 8),
                    _FilterChipItem(
                      label: 'Suspended / Locked',
                      selected: _currentFilter == UserRoleFilter.suspended,
                      onSelected: () => setState(() => _currentFilter = UserRoleFilter.suspended),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
            data: (allUsers) {
              final users = allUsers.where((u) {
                switch (_currentFilter) {
                  case UserRoleFilter.all:
                    return true;
                  case UserRoleFilter.students:
                    return u.roles.any((r) => r.toLowerCase() == 'student');
                  case UserRoleFilter.instructors:
                    return u.roles.any((r) => r.toLowerCase() == 'instructor');
                  case UserRoleFilter.admins:
                    return u.roles.any((r) => r.toLowerCase() == 'admin');
                  case UserRoleFilter.suspended:
                    return !u.isActive;
                }
              }).toList();

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔍', style: TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text('No users found in this view.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(adminProvider.notifier).fetchUsers(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                  ? 'Account locked: ${users[i].email}'
                                  : 'Account unlocked: ${users[i].email}'
                              : 'Failed to update status.'),
                          backgroundColor: ok ? const Color(0xFF10B981) : Colors.red,
                        ));
                      }
                    },
                    onDelete: () => _confirmDelete(users[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChipItem({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      selected: selected,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : colorScheme.onSurface.withValues(alpha: 0.8)),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3)),
      ),
      onSelected: (_) => onSelected(),
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
    final isLocked = !user.isActive;

    final initials = user.firstName.isNotEmpty && user.lastName.isNotEmpty
        ? '${user.firstName[0]}${user.lastName[0]}'.toUpperCase()
        : user.email.isNotEmpty
            ? user.email.substring(0, 2).toUpperCase()
            : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isLocked ? Colors.red.withValues(alpha: 0.4) : colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor, roleColor.withValues(alpha: 0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
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
                      Text(user.fullName.isEmpty ? user.email.split('@')[0] : user.fullName,
                          style: TextStyle(
                              color: colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 8),
                      // Active/Locked indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (user.isActive ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (user.isActive ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(user.isActive ? 'Active' : 'Locked',
                            style: TextStyle(
                              color: user.isActive ? const Color(0xFF10B981) : Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
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
                            color: roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(user.primaryRole,
                                  style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${user.enrollmentCount} enrolled',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Change Role button
                OutlinedButton.icon(
                  onPressed: onChangeRole,
                  icon: const Icon(Icons.badge_outlined, size: 14),
                  label: const Text('Role', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                // Lock / Unlock button
                OutlinedButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(user.isActive ? Icons.lock_outline : Icons.lock_open, size: 14),
                  label: Text(user.isActive ? 'Lock' : 'Unlock', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: user.isActive ? Colors.amber[800] : const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 4),
                // Delete
                IconButton(
                  tooltip: 'Delete user',
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  int countWhere(bool Function(T) test) {
    var c = 0;
    for (final element in this) {
      if (test(element)) c++;
    }
    return c;
  }
}
