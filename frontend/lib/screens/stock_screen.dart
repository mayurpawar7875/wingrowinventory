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

  // Keep controllers per item id
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id, int stock) {
    return _controllers.putIfAbsent(
      id,
      () => TextEditingController(text: stock.toString()),
    );
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

        // Sync controllers to server values
        for (final it in _items) {
          final id = it['_id'] as String;
          final stock = (it['stock'] ?? 0) as int;
          final ctrl = _controllers[id];
          if (ctrl == null) {
            _controllers[id] = TextEditingController(text: stock.toString());
          } else {
            ctrl.text = stock.toString();
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

  Future<void> _seed() async {
    final r = await widget.api.seedInventory();
    if (!mounted) return;
    if (r.statusCode == 200) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Inventory seeded')));
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Seed failed: ${r.body}')));
    }
  }

  Future<void> _saveStock(Map<String, dynamic> item, String text) async {
    final n = int.tryParse(text);
    if (n == null || n < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a non-negative integer')),
      );
      return;
    }
    final id = item['_id'] as String;
    final r = await widget.api.updateItemStock(id, n);
    if (!mounted) return;
    if (r.statusCode == 200) {
      setState(() => item['stock'] = n);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${r.body}')));
    }
  }

  Widget _qtyControls({
    required TextEditingController ctrl,
    required VoidCallback onSave,
    required VoidCallback onInc,
    required VoidCallback onDec,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Decrease',
          icon: const Icon(Icons.remove),
          onPressed: onDec,
        ),
        SizedBox(
          width: 88, // keeps a stable field width
          child: TextField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase',
          icon: const Icon(Icons.add),
          onPressed: onInc,
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Save',
          icon: const Icon(Icons.save),
          onPressed: onSave,
        ),
      ],
    );
  }

  Widget _responsiveRow(Map<String, dynamic> it) {
    final id = it['_id'] as String;
    final name = (it['name'] ?? '').toString();
    final ctrl = _controllerFor(id, (it['stock'] ?? 0) as int);

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 460;

        final title = Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

        final unit = Text(
          'Unit: pcs',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        );

        final controls = _qtyControls(
          ctrl: ctrl,
          onSave: () => _saveStock(it, ctrl.text),
          onInc: () {
            final v = int.tryParse(ctrl.text) ?? 0;
            ctrl.text = (v + 1).toString();
          },
          onDec: () {
            final v = int.tryParse(ctrl.text) ?? 0;
            if (v > 0) ctrl.text = (v - 1).toString();
          },
        );

        if (isNarrow) {
          // Stack name/unit on first line; controls on second line.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 4),
                unit,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: controls,
                ),
              ],
            ),
          );
        }

        // Wide: name/unit left, controls right
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 4),
                    unit,
                  ],
                ),
              ),
              controls,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Stock'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          TextButton(onPressed: _seed, child: const Text('Seed Items')),
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
                      itemBuilder: (_, i) => _responsiveRow(_items[i]),
                    ),
    );
  }
}
