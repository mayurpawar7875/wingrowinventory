// lib/screens/my_item_requests_screen.dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
      final rawList = (data is Map && data['requests'] is List)
          ? (data['requests'] as List)
          : const <dynamic>[];

      _requests = rawList
          .whereType<Map>()
          .map<Map<String, dynamic>>(
              (m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      // Show newest first if createdAt exists
      _requests.sort((a, b) {
        final as = (a['createdAt'] ?? '').toString();
        final bs = (b['createdAt'] ?? '').toString();
        return bs.compareTo(as);
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Payment helpers ----------

  Color _statusBg(String s) {
    switch (s) {
      case 'APPROVED':
        return Colors.green.shade100;
      case 'REJECTED':
        return Colors.red.shade100;
      default:
        return Colors.orange.shade100;
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'APPROVED':
        return Colors.green.shade800;
      case 'REJECTED':
        return Colors.red.shade800;
      default:
        return Colors.orange.shade800;
    }
  }

  Chip _settlementChip(String settle) {
    switch (settle.toUpperCase()) {
      case 'PAID':
        return Chip(
          label: const Text('Paid'),
          backgroundColor: Colors.green.withOpacity(.15),
          labelStyle:
              const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
        );
      case 'PARTIAL':
        return Chip(
          label: const Text('Partial'),
          backgroundColor: Colors.orange.withOpacity(.15),
          labelStyle: const TextStyle(
              color: Colors.orange, fontWeight: FontWeight.w600),
        );
      default:
        return Chip(
          label: const Text('Due'),
          backgroundColor: Colors.red.withOpacity(.12),
          labelStyle:
              const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addPayment(Map<String, dynamic> req) async {
    final amountCtrl = TextEditingController();
    String? proofUrl;
    String? note;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount received (₹)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => note = v.trim(),
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload),
                  label:
                      Text(proofUrl == null ? 'Upload screenshot' : 'Uploaded'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final f = result.files.first;
                      final bytes = f.bytes;
                      if (bytes != null) {
                        final url = await widget.api.uploadReceiptBytes(
                          bytes: bytes,
                          filename: f.name,
                        );
                        if (url != null) {
                          setS(() => proofUrl = url);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Uploaded')),
                          );
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload failed')),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        );
      }),
    );

    if (ok != true) return;

    final amt = double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (proofUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload the screenshot')));
      return;
    }

    final resp = await widget.api.addIssuePayment(
      requestId: (req['_id'] ?? '').toString(), // ALWAYS by id
      amount: amt,
      proofUrl: proofUrl ?? '',
      note: note,
    );

    if (!mounted) return;
    if (resp.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Payment added')));
      await _load(); // refresh so the payment shows on the correct card
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${resp.body}')));
    }
  }

  // ---------- UI ----------

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

                          final itemName = (r['itemName'] ??
                                  (r['itemId'] is Map
                                      ? (r['itemId'] as Map)['name']
                                      : null) ??
                                  'Item')
                              .toString();

                          final qty = (r['qty'] as num?)?.toInt() ?? 0;
                          final issued = (r['issuedQty'] as num?)?.toInt() ?? 0;
                          final status = (r['status'] ?? 'PENDING').toString();
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

                          // money tracking
                          final amountDue = ((r['amountDue'] is num)
                              ? (r['amountDue'] as num).toDouble()
                              : 0.0);
                          final amountReceived = ((r['amountReceived'] is num)
                              ? (r['amountReceived'] as num).toDouble()
                              : 0.0);
                          final settle = (r['settlementStatus'] ??
                                  (amountReceived <= 0 ? 'DUE' : 'PARTIAL'))
                              .toString();

                          final payments = (r['payments'] is List)
                              ? (r['payments'] as List)
                                  .whereType<Map>()
                                  .map<Map<String, dynamic>>(
                                      (m) => m.map((k, v) => MapEntry('$k', v)))
                                  .toList()
                              : const <Map<String, dynamic>>[];

                          return Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // header line
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$itemName  •  Qty: $qty',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Chip(
                                        backgroundColor: _statusBg(status),
                                        label: Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusFg(status),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (issued > 0) const SizedBox(height: 4),
                                  if (issued > 0) Text('Issued: $issued'),

                                  if (requesterNote.isNotEmpty)
                                    const SizedBox(height: 2),
                                  if (requesterNote.isNotEmpty)
                                    Text('Note: $requesterNote'),

                                  if (managerNote.isNotEmpty)
                                    const SizedBox(height: 2),
                                  if (managerNote.isNotEmpty)
                                    Text('Manager note: $managerNote'),

                                  if (created.isNotEmpty)
                                    const SizedBox(height: 2),
                                  if (created.isNotEmpty)
                                    Text('Requested: $created'),

                                  // Payment summary (only for approved)
                                  if (status == 'APPROVED') ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _settlementChip(settle),
                                        const SizedBox(width: 8),
                                        Text(
                                          amountDue > 0
                                              ? 'Received ₹${amountReceived.toStringAsFixed(2)} / ₹${amountDue.toStringAsFixed(2)}'
                                              : 'Received ₹${amountReceived.toStringAsFixed(2)}',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Add Payment'),
                                        onPressed: () => _addPayment(r),
                                      ),
                                    ),
                                    if (payments.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Payments:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      ...payments.map((p) {
                                        final amt = (p['amount'] is num)
                                            ? (p['amount'] as num).toDouble()
                                            : 0.0;
                                        final when =
                                            (p['uploadedAt'] ?? '').toString();
                                        final shortDate = when.length >= 10
                                            ? when.substring(0, 10)
                                            : when;
                                        final note =
                                            (p['note'] ?? '').toString();
                                        final proof =
                                            (p['proofUrl'] ?? '').toString();
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '• ₹${amt.toStringAsFixed(2)}  •  $shortDate'
                                                  '${note.isNotEmpty ? '  •  $note' : ''}',
                                                ),
                                              ),
                                              if (proof.isNotEmpty)
                                                TextButton.icon(
                                                  icon: const Icon(
                                                      Icons.visibility),
                                                  label:
                                                      const Text('View proof'),
                                                  onPressed: () =>
                                                      _openUrl(proof),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
