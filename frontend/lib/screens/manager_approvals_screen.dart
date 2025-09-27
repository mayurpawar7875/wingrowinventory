// lib/screens/manager_approvals_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_service.dart';

class ManagerApprovalsScreen extends StatefulWidget {
  final ApiService api;
  const ManagerApprovalsScreen({super.key, required this.api});

  @override
  State<ManagerApprovalsScreen> createState() => _ManagerApprovalsScreenState();
}

class _ManagerApprovalsScreenState extends State<ManagerApprovalsScreen> {
  bool _loading = true;
  List<dynamic> _claims = [];
  String? _error;

  /// Page filter: SUBMITTED | APPROVED | REJECTED
  String _status = 'SUBMITTED';

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
      final r = await widget.api.approvalsByStatus(_status);
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

  Future<void> _approve(String id) async {
    final comment = await _askText('Approve comment (optional)');
    final r = await widget.api.approveClaim(id, comment: comment);
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Approved')));
      _load();
    } else {
      _showErr(r.body);
    }
  }

  Future<void> _reject(String id) async {
    final comment = await _askText('Reason for rejection (optional)');
    final r = await widget.api.rejectClaim(id, comment: comment);
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rejected')));
      _load();
    } else {
      _showErr(r.body);
    }
  }

  Future<void> _markPaid(String id) async {
    final ref = await _askText('Payment reference (optional)');
    final r = await widget.api.markPaid(id, paymentRef: ref);
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Marked as PAID')));
      _load();
    } else {
      _showErr(r.body);
    }
  }

  Future<String?> _askText(String title) async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Type here…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    return (res != null && res.isEmpty) ? null : res;
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  num _computeTotal(Map<String, dynamic> claim) {
    final t = claim['totalAmount'];
    if (t is num) return t;
    final items = (claim['items'] as List?) ?? [];
    return items.fold<num>(0, (p, it) => p + (it['amount'] ?? 0));
  }

  String _emptyText() {
    switch (_status) {
      case 'APPROVED':
        return 'No approved claims';
      case 'REJECTED':
        return 'No rejected claims';
      default:
        return 'No submitted claims';
    }
  }

  void _showItemsDialog(Map<String, dynamic> claim) {
    final items = (claim['items'] as List?) ?? [];
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title:
            Text('Items • Claim #${claim['_id'].toString().substring(0, 6)}'),
        content: SizedBox(
          width: 460,
          child: items.isEmpty
              ? const Text('No items')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final it = (items[i] as Map).cast<String, dynamic>();
                    final receipt = (it['receiptUrl'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${it['category']} • ₹${it['amount']}'),
                      subtitle: Text(
                        '${(it['date'] ?? '').toString().substring(0, 10)}   ${it['notes'] ?? ''}',
                      ),
                      trailing: receipt.isNotEmpty
                          ? IconButton(
                              tooltip: 'Open receipt',
                              icon: const Icon(Icons.receipt_long),
                              onPressed: () => _openUrl(receipt),
                            )
                          : null,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // ---------- UI bits ----------

  Widget _statusChip(String value, String label, IconData icon) {
    final selected = _status == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        if (_status != value) {
          setState(() => _status = value);
          _load();
        }
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(.12),
      labelStyle: TextStyle(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _filtersBar() {
    // Left: status chips, Right: inventory buttons; wraps nicely on small widths
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 520;
        final left = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusChip('SUBMITTED', 'Submitted', Icons.check),
            _statusChip('APPROVED', 'Approved', Icons.verified),
            _statusChip('REJECTED', 'Rejected', Icons.cancel),
          ],
        );

        final right = Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Stock'),
              onPressed: () => Navigator.pushNamed(context, '/stock'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.list_alt),
              label: const Text('Item Requests'),
              onPressed: () =>
                  Navigator.pushNamed(context, '/mgr-item-requests'),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const SizedBox(height: 10),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            right,
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Buttons shown on each card
    Widget actionsRowFor(Map<String, dynamic> c) {
      if (_status == 'SUBMITTED') {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                onPressed: () => _reject(c['_id']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
                onPressed: () => _approve(c['_id']),
              ),
            ),
          ],
        );
      }

      if (_status == 'APPROVED') {
        final claimStatus = (c['status'] ?? '').toString();
        if (claimStatus == 'PAID') {
          // Already paid → show a chip
          return Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              label: const Text('Paid'),
              backgroundColor: Colors.green.withOpacity(0.15),
              labelStyle: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        } else {
          // Approved but not yet paid → show action button
          return ElevatedButton.icon(
            icon: const Icon(Icons.payments),
            label: const Text('Mark Paid'),
            onPressed: () => _markPaid(c['_id']),
          );
        }
      }
      // REJECTED
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          _filtersBar(), // <-- new responsive header
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _claims.isEmpty
                        ? Center(child: Text(_emptyText()))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _claims.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final c =
                                    (_claims[i] as Map).cast<String, dynamic>();
                                final items = (c['items'] as List?) ?? [];
                                final total = _computeTotal(c);

                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Claim #${c['_id'].toString().substring(0, 6)} • by ${c['userId']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(Icons.list_alt),
                                              label: const Text('View items'),
                                              onPressed: () =>
                                                  _showItemsDialog(c),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Items: ${items.length}    Total: ₹$total',
                                        ),
                                        const SizedBox(height: 10),
                                        actionsRowFor(c),
                                      ],
                                    ),
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

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $msg')),
    );
  }
}
