// lib/screens/request_item_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class RequestItemScreen extends StatefulWidget {
  final ApiService api;
  const RequestItemScreen({super.key, required this.api});

  @override
  State<RequestItemScreen> createState() => _RequestItemScreenState();
}

class _RequestItemScreenState extends State<RequestItemScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  String? _error;

  // inventory
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _selected;
  int _qty = 1;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.listInventoryItems();
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _items = (data['items'] as List? ?? [])
            .cast<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        // Do NOT auto-select; keep the "Please select item" hint.
        _selected = null;
        _qty = 1;
      } else {
        _error = 'Failed: ${r.statusCode}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _available {
    final s = _selected?['stock'];
    return (s is num) ? s.toInt() : 0;
  }

  Future<void> _submit() async {
    // Validate form (ensures item selected).
    if (!_formKey.currentState!.validate()) return;

    if (_selected == null) return; // double-safety

    if (_qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1')),
      );
      return;
    }
    if (_qty > _available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity exceeds available stock')),
      );
      return;
    }

    final r = await widget.api.createIssueRequest(
      itemId: _selected!['_id'] as String,
      qty: _qty,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${r.body}')),
      );
    }
  }

  Widget _spacer([double h = 12]) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    const maxContentWidth = 560.0;
    final onSurfaceVar = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Item'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Card container for form
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    // Item dropdown (with hint + validation)
                                    DropdownButtonFormField<
                                        Map<String, dynamic>>(
                                      value: _selected, // may be null
                                      isExpanded: true,
                                      hint: const Text('Please select item'),
                                      items: _items
                                          .map(
                                            (it) => DropdownMenuItem(
                                              value: it,
                                              child: Text(
                                                it['name']?.toString() ??
                                                    'Item',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() {
                                          _selected = v;
                                          // reset / clamp qty when item changes
                                          final avail = _available;
                                          if (avail <= 0) {
                                            _qty = 1;
                                          } else if (_qty > avail) {
                                            _qty = avail;
                                          } else if (_qty < 1) {
                                            _qty = 1;
                                          }
                                        });
                                      },
                                      validator: (v) => v == null
                                          ? 'Please select an item'
                                          : null,
                                      decoration: const InputDecoration(
                                        labelText: 'Item',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(14)),
                                        ),
                                      ),
                                    ),

                                    _spacer(),

                                    // Qty row with stepper + available
                                    LayoutBuilder(builder: (context, c) {
                                      final isNarrow = c.maxWidth < 440;

                                      final canChangeQty = _selected != null;

                                      final qtyField = Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Decrease',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(Icons.remove),
                                              onPressed: !canChangeQty
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        if (_qty > 1) _qty--;
                                                      });
                                                    },
                                            ),
                                            SizedBox(
                                              width: 64,
                                              child: Center(
                                                child: Text(
                                                  '$_qty',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Increase',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(Icons.add),
                                              onPressed: !canChangeQty
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        final avail =
                                                            _available;
                                                        if (avail <= 0) return;
                                                        if (_qty < avail) {
                                                          _qty++;
                                                        }
                                                      });
                                                    },
                                            ),
                                          ],
                                        ),
                                      );

                                      final availStr = _selected == null
                                          ? '-'
                                          : _available.toString();

                                      final availableLabel = Padding(
                                        padding: isNarrow
                                            ? const EdgeInsets.only(top: 10)
                                            : EdgeInsets.zero,
                                        child: Text(
                                          'Available: $availStr',
                                          style: TextStyle(color: onSurfaceVar),
                                        ),
                                      );

                                      if (isNarrow) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding:
                                                    EdgeInsets.only(bottom: 6),
                                                child: Text('Qty'),
                                              ),
                                            ),
                                            qtyField,
                                            availableLabel,
                                          ],
                                        );
                                      }
                                      return Row(
                                        children: [
                                          const Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                      left: 4, bottom: 6),
                                                  child: Text('Qty'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          qtyField,
                                          const SizedBox(width: 16),
                                          availableLabel,
                                        ],
                                      );
                                    }),

                                    _spacer(),

                                    // Note
                                    TextField(
                                      controller: _noteCtrl,
                                      minLines: 3,
                                      maxLines: 5,
                                      decoration: const InputDecoration(
                                        labelText: 'Note (optional)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(14)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Bottom primary/secondary actions
                            LayoutBuilder(builder: (context, c) {
                              final isNarrow = c.maxWidth < 480;
                              final primary = ElevatedButton.icon(
                                onPressed: _submit,
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Submit Request'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              );

                              final secondary = OutlinedButton.icon(
                                onPressed: () => Navigator.pushNamed(
                                    context, '/my-item-requests'),
                                icon: const Icon(Icons.receipt_long),
                                label: const Text('My Item Requests'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              );

                              if (isNarrow) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    primary,
                                    const SizedBox(height: 10),
                                    secondary,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: primary),
                                  const SizedBox(width: 12),
                                  Expanded(child: secondary),
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
