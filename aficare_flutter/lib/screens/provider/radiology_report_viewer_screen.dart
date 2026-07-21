import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/theme.dart';

class RadiologyReportViewerScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const RadiologyReportViewerScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<RadiologyReportViewerScreen> createState() =>
      _RadiologyReportViewerScreenState();
}

class _RadiologyReportViewerScreenState
    extends State<RadiologyReportViewerScreen> {
  List<Map<String, dynamic>> _studies = [];
  bool _isLoading = true;
  String _filter = 'All';
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStudies());
  }

  Future<void> _loadStudies() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('radiology_orders')
          .select('*, radiology_reports(*)')
          .eq('patient_id', widget.patientId)
          .order('ordered_at', ascending: false);

      _studies = List<Map<String, dynamic>>.from(response as List);
      _isLoading = false;
      if (mounted) setState(() {});
    } catch (e) {
      _isLoading = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _studies
        : _studies.where((s) {
            final status = (s['status'] as String? ?? '');
            return _filter == 'Reported'
                ? status == 'reported'
                : status != 'reported';
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radiology Reports'),
        backgroundColor: AfiCareTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Patient name banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AfiCareTheme.primaryBlue.withOpacity(0.08),
            child: Text(
              '${widget.patientName}  •  ML-${widget.patientId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // Filter tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('All'),
                const SizedBox(width: 8),
                _filterChip('Reported'),
                const SizedBox(width: 8),
                _filterChip('Awaiting'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Studies list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.medical_services,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No imaging studies',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStudies,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final study = filtered[i];
                            final isExpanded =
                                _expandedIds.contains(study['id']);
                            final status =
                                study['status'] as String? ?? 'ordered';
                            final isReported = status == 'reported';
                            final reports = study['radiology_reports'];
                            final report = (reports is List &&
                                    reports.isNotEmpty)
                                ? reports.first as Map<String, dynamic>
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              clipBehavior: Clip.antiAlias,
                              child: ExpansionTile(
                                key: PageStorageKey(study['id']),
                                initiallyExpanded: isExpanded,
                                onExpansionChanged: (expanded) {
                                  setState(() {
                                    if (expanded) {
                                      _expandedIds.add(study['id']);
                                    } else {
                                      _expandedIds.remove(study['id']);
                                    }
                                  });
                                },
                                leading: _modalityIcon(
                                    study['study_type'] as String? ?? ''),
                                title: Text(
                                  '${study['study_type'] ?? 'Study'} — ${study['body_part'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      _formatDate(DateTime.parse(
                                          study['ordered_at'] as String)),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isReported
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.grey.withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isReported ? 'Reported' : 'Awaiting',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isReported
                                              ? Colors.green
                                              : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  if (isReported && report != null)
                                    _buildReport(report)
                                  else
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Icon(Icons.hourglass_empty,
                                              size: 18,
                                              color: Colors.grey[500]),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Report pending — check back later',
                                            style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(Map<String, dynamic> report) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Radiologist
          if (report['reported_by'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Reported by: ${report['reported_by']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          // Findings
          const Text('Findings',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Text(
            report['findings'] ?? 'No findings recorded.',
            style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4),
          ),
          const SizedBox(height: 16),
          // Impression — highlighted box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AfiCareTheme.primaryBlue.withOpacity(0.06),
              border: Border(
                left: BorderSide(
                    color: AfiCareTheme.primaryBlue, width: 3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Impression',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AfiCareTheme.primaryBlue)),
                const SizedBox(height: 4),
                Text(
                  report['impression'] ?? 'No impression recorded.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recommendations
          if (report['recommendations'] != null &&
              (report['recommendations'] as String).isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recommendations',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  report['recommendations'] as String,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4),
                ),
              ],
            ),
          const SizedBox(height: 8),
          // View Images stub
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PACS/DICOM integration coming soon')),
              );
            },
            icon: const Icon(Icons.image, size: 16),
            label: const Text('View Images', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.grey[700],
          )),
      selected: selected,
      selectedColor: AfiCareTheme.primaryBlue,
      backgroundColor: Colors.grey[100],
      onSelected: (_) => setState(() => _filter = label),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _modalityIcon(String studyType) {
    IconData icon;
    Color color;
    switch (studyType.toLowerCase()) {
      case 'x-ray':
        icon = Icons.image; color = Colors.blue;
        break;
      case 'ct':
        icon = Icons.view_in_ar; color = Colors.teal;
        break;
      case 'ultrasound':
        icon = Icons.waves; color = Colors.purple;
        break;
      case 'mri':
        icon = Icons.donut_large; color = Colors.orange;
        break;
      case 'pet-ct':
        icon = Icons.medical_services; color = Colors.red;
        break;
      case 'mammography':
        icon = Icons.visibility; color = Colors.pink;
        break;
      default:
        icon = Icons.medical_services; color = Colors.grey;
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.15),
      child: Icon(icon, size: 18, color: color),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
