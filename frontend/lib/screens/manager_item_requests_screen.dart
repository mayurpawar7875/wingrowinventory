// lib/screens/manager_item_requests_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class ManagerItemRequestsScreen extends StatefulWidget {
  final ApiService api;
  const ManagerItemRequestsScreen({super.key, required this.api});

  @override
  State<ManagerItemRequestsScreen> createState() =>
      _ManagerItemRequestsScreenState();
}

class _ManagerItemRequestsScreenState extends State<ManagerItemRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _requests = [];

  // PENDING | APPROVED | REJECTED
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    // pick optional initial status from route arguments, then load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['status'] is String) {
        final s = (args['status'] as String).toUpperCase();
        if (['PENDING', 'APPROVED', 'REJECTED'].contains(s)) {
          _status = s;
        }
      }
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.issueRequestsByStatus(_status);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _requests = (data['requests'] as List?) ?? [];
      } else {
        _error = 'Failed: ${r.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askText({
    required String title,
    String? initial,
    String hint = 'Type here…',
    bool numeric = false,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return (res != null && res.isEmpty) ? null : res;
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    // Optional: override qty to issue; leave blank to use requested qty
    final requested = (req['qty'] is num) ? (req['qty'] as num).toInt() : 1;
    final qtyText = await _askText(
      title: 'Issue quantity (blank = $requested)',
      initial: requested.toString(),
      hint: '$requested',
      numeric: true,
    );

    int? issueQty;
    if (qtyText != null && qtyText.isNotEmpty) {
      final n = int.tryParse(qtyText);
      if (n == null || n <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a positive integer')),
        );
        return;
      }
      issueQty = n;
    } else {
      issueQty = null; // backend will use requested qty
    }

    final note = await _askText(
      title: 'Note (optional)',
      initial: req['decisionNote']?.toString() ?? '',
    );

    final r = await widget.api.approveIssueRequest(
      req['_id'] as String,
      issueQty: issueQty,
      note: (note == null || note.isEmpty) ? null : note,
    );

    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Approved')));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${r.body}')));
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final note = await _askText(
      title: 'Reason (optional)',
      initial: req['decisionNote']?.toString() ?? '',
    );
    final r = await widget.api.rejectIssueRequest(
      req['_id'] as String,
      note: (note == null || note.isEmpty) ? null : note,
    );

    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rejected')));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${r.body}')));
    }
  }

  Color _chipColor(String s) {
    switch (s) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _emptyText(String s) {
    switch (s) {
      case 'APPROVED':
        return 'No approved requests';
      case 'REJECTED':
        return 'No rejected requests';
      default:
        return 'No pending requests';
    }
  }

  Widget _trailingFor(Map<String, dynamic> r) {
    if (_status == 'PENDING') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.close),
            onPressed: () => _reject(r),
          ),
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check),
            onPressed: () => _approve(r),
          ),
        ],
      );
    }
    final s = (r['status'] ?? 'PENDING').toString();
    return Chip(
      label: Text(s),
      backgroundColor: _chipColor(s).withOpacity(0.15),
      labelStyle: TextStyle(color: _chipColor(s), fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Requests'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _status = v);
                _load();
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _requests.isEmpty
                  ? Center(child: Text(_emptyText(_status)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _requests[i] as Map<String, dynamic>;

                          final name = (r['itemName'] ?? 'Item').toString();
                          final qty = (r['qty'] is num)
                              ? (r['qty'] as num).toInt()
                              : int.tryParse('${r['qty'] ?? 0}') ?? 0;
                          final userId = (r['userId'] ?? r['requestedBy'] ?? '')
                              .toString();
                          final issued = (r['issuedQty'] is num)
                              ? (r['issuedQty'] as num).toInt()
                              : 0;
                          final noteReq = (r['note'] ?? '').toString();
                          final noteMgr = (r['decisionNote'] ?? '').toString();
                          final created = (r['createdAt'] ?? '').toString();

                          return Card(
                            child: ListTile(
                              title: Text('$name • Qty: $qty'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Requested by: $userId'),
                                  if (issued > 0) Text('Issued: $issued'),
                                  if (noteReq.isNotEmpty)
                                    Text('Note: $noteReq'),
                                  if (noteMgr.isNotEmpty)
                                    Text('Manager note: $noteMgr'),
                                  if (created.isNotEmpty)
                                    Text('Date: ${created.substring(0, 10)}'),
                                ],
                              ),
                              trailing: _trailingFor(r),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
