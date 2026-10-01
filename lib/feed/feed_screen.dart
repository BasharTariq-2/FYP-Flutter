import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

class FeedDashboardScreen extends StatefulWidget {
  final int farmId;

  const FeedDashboardScreen({
    super.key,
    required this.farmId,
  });

  @override
  State<FeedDashboardScreen> createState() =>
      _FeedDashboardScreenState();
}

class _FeedDashboardScreenState
    extends State<FeedDashboardScreen> {

  final repo = ApiRepository();

  List<dynamic> stock = [];

  bool loading = true;

  String error = "";

  // ---------------- FEED TYPES ----------------

  final List<Map<String, dynamic>> feedTypes = [
    {
      "id": 1,
      "name": "Starter Feed",
    },
    {
      "id": 2,
      "name": "Grower Feed",
    },
    {
      "id": 3,
      "name": "Finisher Feed",
    },
  ];

  int selectedFeedType = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------- LOAD STOCK ----------------

  Future<void> _load() async {

    setState(() {
      loading = true;
      error = "";
    });

    try {

      final response =
      await repo.feedStock(widget.farmId);

      debugPrint("FINAL STOCK: $response");

      stock = response;

      if (stock.isEmpty) {
        error = "No feed stock found";
      }

    } catch (e) {

      stock = [];

      error = e.toString();
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ---------------- ADD USAGE ----------------

  Future<void> _addUsage() async {

    final batchId = TextEditingController();

    final qty = TextEditingController();

    int selectedUsageFeed = 1;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(

        title: const Text("Add Feed Usage"),

        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: batchId,
                decoration: const InputDecoration(
                  labelText: "Batch ID",
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<int>(

                value: selectedUsageFeed,

                decoration: const InputDecoration(
                  labelText: "Feed Type",
                ),

                items: feedTypes.map((feed) {

                  return DropdownMenuItem<int>(
                    value: feed['id'],
                    child: Text(feed['name']),
                  );

                }).toList(),

                onChanged: (value) {
                  selectedUsageFeed = value!;
                },
              ),

              const SizedBox(height: 10),

              TextField(
                controller: qty,
                decoration: const InputDecoration(
                  labelText: "Quantity KG",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),

        actions: [

          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(qty.text) ?? 0.0;
              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a valid quantity")),
                );
                return;
              }

              final stockItem = stock.firstWhere(
                (s) => s is Map && s['feed_type_id'] == selectedUsageFeed,
                orElse: () => null,
              );
              final availableStock = stockItem != null ? safeDouble(stockItem['quantity_kg']) : 0.0;
              if (quantity > availableStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Insufficient stock! Available: ${availableStock.toStringAsFixed(1)} KG")),
                );
                return;
              }

              try {
                await repo.recordFeedUsage(
                  batchId: int.tryParse(batchId.text) ?? 0,
                  feedTypeId: selectedUsageFeed,
                  quantityUsedKg: quantity,
                );
                Navigator.pop(context);
                _load();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------- ADD PURCHASE ----------------

  Future<void> _addPurchase() async {

    final qty = TextEditingController();

    final price = TextEditingController();

    final supplier = TextEditingController();

    int selectedPurchaseFeed = 1;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(

        title: const Text("Add Purchase"),

        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              DropdownButtonFormField<int>(

                value: selectedPurchaseFeed,

                decoration: const InputDecoration(
                  labelText: "Feed Type",
                ),

                items: feedTypes.map((feed) {

                  return DropdownMenuItem<int>(
                    value: feed['id'],
                    child: Text(feed['name']),
                  );

                }).toList(),

                onChanged: (value) {
                  selectedPurchaseFeed = value!;
                },
              ),

              const SizedBox(height: 10),

              TextField(
                controller: qty,
                decoration: const InputDecoration(
                  labelText: "Quantity KG",
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),

              TextField(
                controller: price,
                decoration: const InputDecoration(
                  labelText: "Price Per KG",
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 10),

              TextField(
                controller: supplier,
                decoration: const InputDecoration(
                  labelText: "Supplier",
                ),
              ),
            ],
          ),
        ),

        actions: [

          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(

            onPressed: () async {

              await repo.createFeedPurchase(

                farmId: widget.farmId,

                feedTypeId:
                selectedPurchaseFeed,

                quantityKg:
                double.tryParse(qty.text) ?? 0,

                pricePerKg:
                double.tryParse(price.text) ?? 0,

                supplier: supplier.text,
              );

              Navigator.pop(context);

              _load();
            },

            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ---------------- SAFE DOUBLE ----------------

  double safeDouble(dynamic value) {

    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    if (value is String) {
      return double.tryParse(value) ?? 0;
    }

    return 0;
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Feed Management"),
      ),

      body: loading

          ? const Center(
        child: CircularProgressIndicator(),
      )

          : RefreshIndicator(

        onRefresh: _load,

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            if (error.isNotEmpty)

              Container(

                padding: const EdgeInsets.all(12),

                margin: const EdgeInsets.only(
                  bottom: 10,
                ),

                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(
                    color: Colors.red,
                  ),
                  borderRadius:
                  BorderRadius.circular(8),
                ),

                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),

            const Text(

              "Feed Stock Overview",

              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            if (stock.isEmpty)

              const Text(
                "No feed stock found",
                style: TextStyle(
                  color: Colors.grey,
                ),
              )

            else

              ...stock.map((s) {

                if (s is! Map) {
                  return const SizedBox();
                }

                final map =
                Map<String, dynamic>.from(s);
                String name = "Unknown Feed";

                final feedTypeId = map['feed_type_id'];

                if (feedTypeId == 1) {
                  name = "Starter Feed";
                }
                else if (feedTypeId == 2) {
                  name = "Grower Feed";
                }
                else if (feedTypeId == 3) {
                  name = "Finisher Feed";
                }

                final qty =
                safeDouble(map['quantity_kg']);

                final isLow = qty < 100;

                return AppCard(

                  child: Column(

                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [

                      Text(

                        name,

                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        "Stock: ${qty.toStringAsFixed(1)} KG",
                      ),

                      const SizedBox(height: 6),

                      LinearProgressIndicator(
                        value:
                        (qty / 1000)
                            .clamp(0.0, 1.0),
                      ),

                      if (isLow)

                        const Padding(

                          padding:
                          EdgeInsets.only(
                            top: 6,
                          ),

                          child: Text(

                            "⚠ Low Stock Alert",

                            style: TextStyle(
                              color: Colors.red,
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),

            PrimaryButton(
              text: "Add Feed Usage",
              onPressed: _addUsage,
            ),

            const SizedBox(height: 10),

            PrimaryButton(
              text: "Add Purchase",
              onPressed: _addPurchase,
            ),
          ],
        ),
      ),
    );
  }
}