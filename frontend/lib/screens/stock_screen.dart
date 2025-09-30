// lib/screens/stock_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_service.dart';

class StockScreen extends StatefulWidget {
  final ApiService api;
  const StockScreen({super.key, required this.api});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = [];

  // separate controllers: stock & price per item id
  final Map<String, TextEditingController> _stockCtrls = {};
  final Map<String, TextEditingController> _priceCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _stockCtrls.values) {
      c.dispose();
    }
    for (final c in _priceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- helpers ----------

  // Read price from any common key returned by backend
  double _readUnitPrice(Map<String, dynamic> it) {
    final v = it['unitPrice'] ?? it['price'] ?? it['unit_price'];
    if (v is num) return v.toDouble();
    if (v is String) {
      final d = double.tryParse(v);
      if (d != null) return d;
    }
    return 0.0;
  }

  TextEditingController _stockCtrlFor(String id, int stock) {
    return _stockCtrls.putIfAbsent(
      id,
      () => TextEditingController(text: stock.toString()),
    );
  }

  TextEditingController _priceCtrlFor(String id, double price) {
    final txt = price == 0
        ? ''
        : price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
    return _priceCtrls.putIfAbsent(id, () => TextEditingController(text: txt));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await widget.api.listInventoryItems();
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _items = (data['items'] as List? ?? [])
            .cast<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

        // Sync controllers with latest server values
        for (final it in _items) {
          final id = it['_id'] as String;
          final stock = (it['stock'] is num) ? (it['stock'] as num).toInt() : 0;
          final price = _readUnitPrice(it);

          final sc = _stockCtrls[id];
          if (sc == null) {
            _stockCtrls[id] = TextEditingController(text: stock.toString());
          } else {
            sc.text = stock.toString();
          }

          final pc = _priceCtrls[id];
          final txt = price == 0
              ? ''
              : price
                  .toStringAsFixed(price.truncateToDouble() == price ? 0 : 2);
          if (pc == null) {
            _priceCtrls[id] = TextEditingController(text: txt);
          } else {
            pc.text = txt;
          }
        }
      } else {
        _err = 'Failed: ${r.statusCode}';
      }
    } catch (e) {
      _err = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bumpStock(String id, int delta) {
    final c = _stockCtrls[id];
    if (c == null) return;
    final cur = int.tryParse(c.text.trim()) ?? 0;
    final next = (cur + delta).clamp(0, 1 << 31);
    c.text = next.toString();
  }

  Future<void> _saveItem(Map<String, dynamic> item) async {
    final id = item['_id'] as String;

    // stock
    final stockText = _stockCtrls[id]?.text.trim() ?? '0';
    final n = int.tryParse(stockText);
    if (n == null || n < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative stock')),
      );
      return;
    }

    // price
    final priceText = _priceCtrls[id]?.text.trim() ?? '';
    double p = 0;
    if (priceText.isNotEmpty) {
      final parsed = double.tryParse(priceText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid non-negative price')),
        );
        return;
      }
      p = parsed;
    }

    final r = await widget.api.updateInventoryItem(
      id,
      stock: n,
      unitPrice: p,
    );

    if (!mounted) return;

    if (r.statusCode == 200) {
      setState(() {
        item['stock'] = n;
        item['unitPrice'] = p; // keep a canonical key locally
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${r.body}')),
      );
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Stock'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(
            onPressed: () async {
              final r = await widget.api.seedInventory();
              if (!mounted) return;
              if (r.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inventory seeded')),
                );
                _load();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Seed failed: ${r.body}')),
                );
              }
            },
            child: const Text('Seed Items'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : _items.isEmpty
                  ? const Center(child: Text('No items. Tap "Seed Items".'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final it = _items[i];
                        final id = it['_id'] as String;
                        final name = it['name']?.toString() ?? '';
                        final uom = it['uom']?.toString() ?? 'pcs';
                        final stockCtrl = _stockCtrlFor(
                          id,
                          (it['stock'] is num)
                              ? (it['stock'] as num).toInt()
                              : 0,
                        );
                        final priceCtrl = _priceCtrlFor(id, _readUnitPrice(it));

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unit: $uom',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final narrow = c.maxWidth < 420;

                                  Widget controlsRow(
                                      {required bool withPrice}) {
                                    return Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: () => _bumpStock(id, -1),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: TextField(
                                            controller: stockCtrl,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: () => _bumpStock(id, 1),
                                        ),
                                        const SizedBox(width: 12),
                                        if (withPrice)
                                          Expanded(
                                            child: TextField(
                                              controller: priceCtrl,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                isDense: true,
                                                labelText: 'Price / unit (₹)',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Save',
                                          icon: const Icon(Icons.save),
                                          onPressed: () => _saveItem(it),
                                        ),
                                      ],
                                    );
                                  }

                                  if (!narrow) {
                                    return controlsRow(withPrice: true);
                                  }

                                  // Narrow: stepper + save on first row, price below
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      controlsRow(withPrice: false),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: priceCtrl,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          labelText: 'Price / unit (₹)',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
