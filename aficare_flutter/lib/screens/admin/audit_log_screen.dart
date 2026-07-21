import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/audit_log_provider.dart';
import '../../utils/theme.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _userFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuditLogProvider>().loadLogs();
    });
  }

  @override
  void dispose() {
    _userFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditLogProvider>();
    final filtered = provider.filteredLogs;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        backgroundColor: AfiCareTheme.adminColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(provider, filtered),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.loadLogs(),
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
                        child: TextField(
                          controller: _userFilterController,
                          decoration: const InputDecoration(
                            hintText: 'Filter by User ID...',
                            prefixIcon: Icon(Icons.person_search),
                            isDense: true,
                          ),
                          onChanged: (v) => provider.setUserFilter(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: _buildActionFilter(provider),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: () => _pickDateRange(context, provider),
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          provider.dateRange != null
                              ? '${DateFormat.Md().format(provider.dateRange!.start)} - ${DateFormat.Md().format(provider.dateRange!.end)}'
                              : 'Date Range',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (provider.dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => provider.setDateRange(null),
                        ),
                    ],
                  );
                }
                return Column(
                  children: [
                    TextField(
                      controller: _userFilterController,
                      decoration: const InputDecoration(
                        hintText: 'Filter by User ID...',
                        prefixIcon: Icon(Icons.person_search),
                        isDense: true,
                      ),
                      onChanged: (v) => provider.setUserFilter(v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildActionFilter(provider)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _pickDateRange(context, provider),
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text(
                              provider.dateRange != null
                                  ? '${DateFormat.Md().format(provider.dateRange!.start)}-${DateFormat.Md().format(provider.dateRange!.end)}'
                                  : 'Dates',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          if (isWide) _buildTableHeader(provider),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)))
                    : filtered.isEmpty
                        ? const Center(child: Text('No audit log entries'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => isWide
                                ? _buildWideRow(context, filtered[i], provider)
                                : _buildNarrowCard(context, filtered[i], provider),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFilter(AuditLogProvider provider) {
    final actions = provider.uniqueActions;
    return DropdownButtonFormField<String>(
      value: provider.actionFilter,
      isDense: true,
      decoration: const InputDecoration(labelText: 'Action', isDense: true),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All Actions')),
        ...actions.map((a) => DropdownMenuItem(
          value: a,
          child: Text(provider.getActionLabel(a) ?? a, style: const TextStyle(fontSize: 13)),
        )),
      ],
      onChanged: (v) => provider.setActionFilter(v ?? 'all'),
    );
  }

  Widget _buildTableHeader(AuditLogProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Resource', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('IP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildWideRow(BuildContext context, Map<String, dynamic> log, AuditLogProvider provider) {
    final ts = DateTime.parse(log['timestamp'] as String);
    final userName = (log['users'] as Map<String, dynamic>?)?['full_name'] as String? ?? (log['user_id'] as String? ?? '-');
    final details = log['details'] as Map<String, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: InkWell(
        onTap: details.isNotEmpty
            ? () => _showDetail(context, log, provider)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(DateFormat('yyyy-MM-dd HH:mm').format(ts), style: const TextStyle(fontSize: 12))),
              Expanded(flex: 2, child: Text(userName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
              Expanded(flex: 2, child: _actionChip(log['action'] as String, provider)),
              Expanded(flex: 2, child: Text(details.containsKey('resource_type')
                  ? '${details['resource_type']}:${details['resource_id']}'
                  : '-', style: const TextStyle(fontSize: 12))),
              Expanded(flex: 1, child: Text(log['ip_address'] as String? ?? '-', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowCard(BuildContext context, Map<String, dynamic> log, AuditLogProvider provider) {
    final ts = DateTime.parse(log['timestamp'] as String);
    final userName = (log['users'] as Map<String, dynamic>?)?['full_name'] as String? ?? (log['user_id'] as String? ?? '-');
    final details = log['details'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: details.isNotEmpty ? () => _showDetail(context, log, provider) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('MMM d, HH:mm').format(ts), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  _actionChip(log['action'] as String, provider),
                ],
              ),
              const SizedBox(height: 4),
              Text(userName, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (details.isNotEmpty)
                Text('${details['resource_type'] ?? ''} ${details['resource_id'] ?? ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionChip(String action, AuditLogProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AfiCareTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        provider.getActionLabel(action) ?? action,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _pickDateRange(BuildContext context, AuditLogProvider provider) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: provider.dateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (range != null) provider.setDateRange(range);
  }

  void _showDetail(BuildContext context, Map<String, dynamic> log, AuditLogProvider provider) {
    final details = log['details'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.getActionLabel(log['action'] as String) ?? 'Event Detail'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: details.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text('${e.key}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(child: Text('${e.value}', style: const TextStyle(fontSize: 12))),
                ],
              ),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _exportCsv(AuditLogProvider provider, List<Map<String, dynamic>> logs) {
    final lines = <String>['Timestamp,User,Action,Resource Type,Resource ID,IP Address'];
    for (final log in logs) {
      final ts = log['timestamp'] as String? ?? '';
      final userName = (log['users'] as Map<String, dynamic>?)?['full_name'] as String? ?? '';
      final action = log['action'] as String? ?? '';
      final details = log['details'] as Map<String, dynamic>? ?? {};
      final resType = details['resource_type'] as String? ?? '';
      final resId = details['resource_id'] as String? ?? '';
      final ip = log['ip_address'] as String? ?? '';
      lines.add('"$ts","$userName","$action","$resType","$resId","$ip"');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${logs.length} log entries')),
    );
  }
}