import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_user_provider.dart';
import '../../models/user_model.dart';
import '../../utils/theme.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchController = TextEditingController();
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUserProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminUserProvider>();
    final filtered = provider.filteredUsers;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AfiCareTheme.adminColor,
        actions: [
          if (provider.selectedIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.playlist_remove),
              tooltip: 'Suspend Selected (${provider.selectedIds.length})',
              onPressed: () => _confirmBulkSuspend(context, provider),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Resend Invite (${provider.selectedIds.length})',
              onPressed: () => _bulkResendInvite(context, provider),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Invite User',
            onPressed: () => _showInviteDialog(context, provider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => provider.loadUsers(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by name, email, or MediLink ID...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) => provider.setSearchQuery(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildRoleFilter(provider),
                      const SizedBox(width: 12),
                      _buildStatusFilter(provider),
                    ],
                  );
                }
                return Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => provider.setSearchQuery(v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildRoleFilter(provider)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatusFilter(provider)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          // Table header
          if (filtered.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: isWide ? _buildWideHeader(context, provider, filtered) : _buildNarrowHeader(context, provider, filtered),
            ),
          // Table body
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
                    : filtered.isEmpty
                        ? const Center(child: Text('No users found'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => isWide
                                ? _buildWideRow(ctx, filtered[i], provider)
                                : _buildNarrowCard(ctx, filtered[i], provider),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleFilter(AdminUserProvider provider) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: provider.roleFilter,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Role', isDense: true),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Roles')),
          DropdownMenuItem(value: 'patient', child: Text('Patients')),
          DropdownMenuItem(value: 'doctor', child: Text('Doctors')),
          DropdownMenuItem(value: 'nurse', child: Text('Nurses')),
          DropdownMenuItem(value: 'admin', child: Text('Admins')),
        ],
        onChanged: (v) => provider.setRoleFilter(v ?? 'all'),
      ),
    );
  }

  Widget _buildStatusFilter(AdminUserProvider provider) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: provider.statusFilter,
        isDense: true,
        decoration: const InputDecoration(labelText: 'Status', isDense: true),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
          DropdownMenuItem(value: 'invited', child: Text('Invited')),
        ],
        onChanged: (v) => provider.setStatusFilter(v ?? 'all'),
      ),
    );
  }

  Widget _buildWideHeader(BuildContext context, AdminUserProvider provider, List<UserModel> filtered) {
    return Row(
      children: [
        Checkbox(
          value: _selectAll,
          onChanged: (v) {
            _selectAll = v ?? false;
            if (_selectAll) provider.selectAll(filtered);
            else provider.clearSelection();
          },
        ),
        const SizedBox(width: 8),
        _headerCell('Name', 2),
        _headerCell('Email', 2),
        _headerCell('Role', 1),
        _headerCell('Status', 1),
        _headerCell('Facility', 1.5),
        _headerCell('Actions', 1.5),
      ],
    );
  }

  Widget _buildNarrowHeader(BuildContext context, AdminUserProvider provider, List<UserModel> filtered) {
    return Row(
      children: [
        Checkbox(
          value: _selectAll,
          onChanged: (v) {
            _selectAll = v ?? false;
            if (_selectAll) provider.selectAll(filtered);
            else provider.clearSelection();
          },
        ),
        const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _headerCell(String label, double flex) {
    return Expanded(
      flex: flex.toInt(),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildWideRow(BuildContext context, UserModel user, AdminUserProvider provider) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: provider.selectedIds.contains(user.id),
            onChanged: (_) => provider.toggleSelection(user.id),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(user.fullName, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(user.email, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: _roleChip(user.role)),
          Expanded(flex: 1, child: _statusChip(user.status)),
          Expanded(flex: 1, child: Text(user.facilityId ?? '-', overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _showEditDialog(context, provider, user),
                ),
                IconButton(
                  icon: Icon(
                    Icons.block,
                    size: 18,
                    color: user.status == UserStatus.suspended ? Colors.green : Colors.orange,
                  ),
                  tooltip: user.status == UserStatus.suspended ? 'Unsuspend' : 'Suspend',
                  onPressed: () => _toggleSuspend(context, provider, user),
                ),
                IconButton(
                  icon: const Icon(Icons.lock_reset, size: 18),
                  tooltip: 'Reset Password',
                  onPressed: () => _resetPassword(context, provider, user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowCard(BuildContext context, UserModel user, AdminUserProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: provider.selectedIds.contains(user.id),
              onChanged: (_) => provider.toggleSelection(user.id),
            ),
            CircleAvatar(
              radius: 20,
              backgroundColor: AfiCareTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(user.email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _roleChip(user.role),
                      const SizedBox(width: 8),
                      _statusChip(user.status),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              onSelected: (v) {
                switch (v) {
                  case 'edit': _showEditDialog(context, provider, user);
                  case 'suspend': _toggleSuspend(context, provider, user);
                  case 'reset': _resetPassword(context, provider, user);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Role')),
                PopupMenuItem(
                  value: 'suspend',
                  child: Text(user.status == UserStatus.suspended ? 'Unsuspend' : 'Suspend'),
                ),
                const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(UserRole role) {
    final colors = {
      UserRole.patient: Colors.blue,
      UserRole.doctor: Colors.green,
      UserRole.nurse: Colors.purple,
      UserRole.admin: Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[role] ?? Colors.grey).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.name[0].toUpperCase() + role.name.substring(1),
        style: TextStyle(fontSize: 11, color: colors[role], fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _statusChip(UserStatus status) {
    final s = status == UserStatus.active
        ? const Color(0xFF43A047)
        : status == UserStatus.suspended
            ? const Color(0xFFE53935)
            : const Color(0xFFFB8C00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: s.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name[0].toUpperCase() + status.name.substring(1),
        style: TextStyle(fontSize: 11, color: s, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showEditDialog(BuildContext context, AdminUserProvider provider, UserModel user) {
    final roleController = TextEditingController(text: user.role.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit User: ${user.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: roleController.text,
              decoration: const InputDecoration(labelText: 'Role'),
              items: UserRole.values.map((r) => DropdownMenuItem(
                value: r.name,
                child: Text(r.name[0].toUpperCase() + r.name.substring(1)),
              )).toList(),
              onChanged: (v) => roleController.text = v ?? 'patient',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newRole = UserRole.values.firstWhere((r) => r.name == roleController.text);
              await provider.updateUserRole(user.id, newRole);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleSuspend(BuildContext context, AdminUserProvider provider, UserModel user) {
    final newStatus = user.status == UserStatus.suspended ? UserStatus.active : UserStatus.suspended;
    provider.updateUserStatus(user.id, newStatus);
  }

  void _resetPassword(BuildContext context, AdminUserProvider provider, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Send password reset email to ${user.email}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await provider.resetPassword(user.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reset email sent to ${user.email}')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, AdminUserProvider provider) {
    final nameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    String role = 'doctor';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Full Name', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Email', isDense: true)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              decoration: const InputDecoration(labelText: 'Role', isDense: true),
              items: const [
                DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) => role = v ?? 'doctor',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.isEmpty || emailCtl.text.isEmpty) return;
              await provider.inviteUser(
                email: emailCtl.text,
                fullName: nameCtl.text,
                role: UserRole.values.firstWhere((r) => r.name == role),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User invited successfully')),
              );
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkSuspend(BuildContext context, AdminUserProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Users'),
        content: Text('Suspend ${provider.selectedIds.length} selected users?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await provider.bulkUpdateStatus(provider.selectedIds, UserStatus.suspended);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  void _bulkResendInvite(BuildContext context, AdminUserProvider provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite resent to ${provider.selectedIds.length} users')),
    );
  }
}