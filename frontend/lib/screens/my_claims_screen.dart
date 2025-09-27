// lib/screens/my_claims_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class MyClaimsScreen extends StatefulWidget {
  final ApiService api;
  const MyClaimsScreen({super.key, required this.api});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _claims = [];

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
      final r = await widget.api.myClaims(); // GET /api/claims?mine=true
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _claims = (data['claims'] as List?) ?? [];
      } else {
        _error = 'Failed: ${r.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return Colors.grey;
      case 'SUBMITTED':
        return Colors.blue;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PAID':
        return Colors.purple;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Claims'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _claims.isEmpty
                  ? const Center(child: Text('No claims yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _claims.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = _claims[i] as Map<String, dynamic>;
                          final id = c['_id'].toString();
                          final date = (c['createdAt'] ?? '')
                              .toString()
                              .substring(0, 10);
                          final total = (c['totalAmount'] ?? 0).toString();
                          final status = (c['status'] ?? '').toString();

                          return Card(
                            child: ListTile(
                              title: Text(
                                  'Claim #${id.substring(0, 6)} • ₹$total'),
                              subtitle: Text('Created: $date'),
                              trailing: Chip(
                                label: Text(status),
                                backgroundColor:
                                    _statusColor(status).withOpacity(0.12),
                                labelStyle:
                                    TextStyle(color: _statusColor(status)),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClaimDetailScreen(
                                    api: widget.api,
                                    claimId: id,
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

class ClaimDetailScreen extends StatefulWidget {
  final ApiService api;
  final String claimId;
  const ClaimDetailScreen({
    super.key,
    required this.api,
    required this.claimId,
  });

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _claim;

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
      final r =
          await widget.api.getClaim(widget.claimId); // GET /api/claims/:id
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _claim = data['claim'] as Map<String, dynamic>?;
      } else {
        _error = 'Failed: ${r.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _claim;
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : c == null
                  ? const Center(child: Text('Not found'))
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${c['_id']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Status: ${c['status']}'),
                          Text('Total: ₹${c['totalAmount'] ?? 0}'),
                          const Divider(),
                          const Text('Items:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: (c['items'] as List?)?.length ?? 0,
                              itemBuilder: (_, i) {
                                final it = (c['items'] as List)[i]
                                    as Map<String, dynamic>;
                                final date = (it['date'] ?? '')
                                    .toString()
                                    .substring(0, 10);
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                      '${it['category']} - ₹${it['amount']}'),
                                  subtitle: Text('$date  ${it['notes'] ?? ''}'),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
