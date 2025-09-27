// lib/screens/reimbursement_screen.dart
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';

class ReimbursementScreen extends StatefulWidget {
  final ApiService api;
  const ReimbursementScreen({super.key, required this.api});

  @override
  State<ReimbursementScreen> createState() => _ReimbursementScreenState();
}

class _ReimbursementScreenState extends State<ReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'Other';

  String? _attachedName;
  String? _attachedUrl;

  final List<Map<String, dynamic>> _items = [];
  bool _submitting = false;

  double get _runningTotal => _items.fold<double>(
        0,
        (sum, it) => sum + ((it['amount'] as num?)?.toDouble() ?? 0),
      );

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDate: _date,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _attachedName = file.name);

    final url = await widget.api.uploadReceiptBytes(
      bytes: bytes,
      filename: file.name,
    );

    if (url != null) {
      setState(() => _attachedUrl = url);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Receipt uploaded')));
    } else {
      setState(() {
        _attachedName = null;
        _attachedUrl = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Upload failed')));
    }
  }

  void _addItem() {
    if (!_formKey.currentState!.validate()) return;
    _items.add({
      'date': _date.toIso8601String(),
      'category': _category,
      'amount': double.parse(_amountCtrl.text),
      'notes': _notesCtrl.text.trim(),
      if (_attachedUrl != null) 'receiptUrl': _attachedUrl,
    });
    _amountCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _attachedName = null;
      _attachedUrl = null;
    });
  }

  Future<void> _submitClaim() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final claimId = await widget.api.createClaim();
      if (claimId == null) throw Exception('Create claim failed');

      for (final it in _items) {
        final ok = await widget.api.addClaimItem(claimId, it);
        if (!ok) throw Exception('Failed to add an item');
      }

      final ok = await widget.api.submitClaim(claimId);
      if (!ok) throw Exception('Submit failed');

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Claim submitted')));
      setState(() => _items.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final yes = await _confirmLogout(context);
    if (yes != true) return;
    await widget.api.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _openReceipt(String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open receipt')));
    }
  }

  Widget _spacer([double h = 12]) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    const maxContentWidth = 640.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reimbursement'),
        actions: [
          IconButton(
            tooltip: 'My Claims',
            icon: const Icon(Icons.list_alt),
            onPressed: () => Navigator.pushNamed(context, '/my-claims'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _category,
                    items: const [
                      DropdownMenuItem(value: 'Travel', child: Text('Travel')),
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(
                          value: 'Supplies', child: Text('Supplies')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  _spacer(),

                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || double.tryParse(v) == null)
                        ? 'Enter amount'
                        : null,
                  ),
                  _spacer(),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _pickDate,
                      child: Text(
                        'Date: ${_date.toIso8601String().substring(0, 10)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  _spacer(),

                  TextFormField(
                    controller: _notesCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  _spacer(),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            _attachedName == null
                                ? 'Attach receipt'
                                : 'Attached: $_attachedName',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _pickAndUpload,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _addItem,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Add Item'),
                      ),
                    ],
                  ),
                  _spacer(8),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total: ₹${_runningTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  _spacer(8),

                  if (_items.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final it = _items[i];
                        final receipt = it['receiptUrl'] as String?;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${it['category']} - ₹${it['amount']}'),
                          subtitle: Text(
                            '${(it['date'] as String).substring(0, 10)}  ${it['notes'] ?? ""}',
                          ),
                          trailing: Wrap(
                            spacing: 6,
                            children: [
                              if (receipt != null)
                                IconButton(
                                  tooltip: 'View receipt',
                                  icon: const Icon(Icons.receipt_long),
                                  onPressed: () => _openReceipt(receipt),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  _spacer(16),

                  // --- Submit Claim FIRST ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitClaim,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.6),
                            )
                          : const Text('Submit Claim'),
                    ),
                  ),

                  _spacer(14),

                  // --- Then Request Item / My Item Requests ---
                  LayoutBuilder(builder: (context, c) {
                    final isNarrow = c.maxWidth < 520;
                    final btnStyle = OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    );

                    final reqBtn = OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/request-item'),
                      icon: const Icon(Icons.tune),
                      label: const Text('Request Item'),
                      style: btnStyle,
                    );

                    final myReqBtn = OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/my-item-requests'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('My Item Requests'),
                      style: btnStyle,
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          reqBtn,
                          const SizedBox(height: 10),
                          myReqBtn,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: reqBtn),
                        const SizedBox(width: 12),
                        Expanded(child: myReqBtn),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
