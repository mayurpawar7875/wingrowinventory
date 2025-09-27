import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class MyItemRequestsScreen extends StatefulWidget {
  final ApiService api;
  const MyItemRequestsScreen({super.key, required this.api});

  @override
  State<MyItemRequestsScreen> createState() => _MyItemRequestsScreenState();
}

class _MyItemRequestsScreenState extends State<MyItemRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await widget.api.myIssueRequests();
      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}: ${r.body}');
      }

      final data = jsonDecode(r.body);

      // Defensive parsing: accept only Map -> List -> Map
      final rawList = (data is Map && data['requests'] is List)
          ? (data['requests'] as List)
          : const <dynamic>[];

      _requests = rawList.where((e) => e is Map).map<Map<String, dynamic>>((e) {
        final m = (e as Map);
        // make sure keys are Strings
        return m.map((k, v) => MapEntry(k.toString(), v));
      }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _chipBg(String s) {
    switch (s) {
      case 'APPROVED':
        return Colors.green.shade100;
      case 'REJECTED':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100; // PENDING
    }
  }

  Color _chipFg(String s) {
    switch (s) {
      case 'APPROVED':
        return Colors.green.shade800;
      case 'REJECTED':
        return Colors.red.shade800;
      default:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Item Requests'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _requests.isEmpty
                  ? const Center(child: Text('No requests yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = _requests[i];

                          // Name can come from itemName OR from a populated itemId.name
                          final itemName = (r['itemName'] ??
                                  (r['itemId'] is Map
                                      ? (r['itemId'] as Map)['name']
                                      : null) ??
                                  'Item')
                              .toString();

                          final qty = (r['qty'] as num?)?.toInt() ?? 0;
                          final issued = (r['issuedQty'] as num?)?.toInt() ?? 0;
                          final status = (r['status'] ?? 'PENDING').toString();

                          // Requester note; manager note might be called decisionNote OR note depending on your controller
                          final requesterNote = (r['note'] ?? '').toString();
                          final managerNote = (r['decisionNote'] ??
                                  r['managerNote'] ??
                                  r['noteManager'] ??
                                  '')
                              .toString();

                          final createdRaw = (r['createdAt'] ?? '').toString();
                          final created = createdRaw.length >= 10
                              ? createdRaw.substring(0, 10)
                              : createdRaw;

                          return Card(
                            child: ListTile(
                              title: Text('$itemName  •  Qty: $qty'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (issued > 0) Text('Issued: $issued'),
                                  if (requesterNote.isNotEmpty)
                                    Text('Note: $requesterNote'),
                                  if (managerNote.isNotEmpty)
                                    Text('Manager note: $managerNote'),
                                  if (created.isNotEmpty)
                                    Text('Requested: $created'),
                                ],
                              ),
                              trailing: Chip(
                                backgroundColor: _chipBg(status),
                                label: Text(
                                  status,
                                  style: TextStyle(
                                    color: _chipFg(status),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
