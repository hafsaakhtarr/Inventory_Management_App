import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ===== PHASE A: SETUP =====
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

// ===== PHASE B: DATA LAYER =====

// Item Model with strong typing
class Item {
  final String? id;
  final String name;
  final String description;
  final int quantity;
  final double price;

  Item({
    this.id,
    required this.name,
    required this.description,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'quantity': quantity,
      'price': price,
    };
  }

  factory Item.fromMap(String id, Map<String, dynamic> data) {
    return Item(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      quantity: data['quantity'] ?? 0,
      price: (data['price'] ?? 0.0).toDouble(),
    );
  }
}

// Firestore Service - typed API for the app
class FirestoreService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'items';

  static Stream<List<Item>> streamItems() {
    return _db.collection(_collection).snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => Item.fromMap(doc.id, doc.data()))
            .toList());
  }

  static Future<void> addItem(Item item) async {
    await _db.collection(_collection).add(item.toMap());
  }

  static Future<void> updateItem(String id, Item item) async {
    await _db.collection(_collection).doc(id).update(item.toMap());
  }

  static Future<void> deleteItem(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }
}

// ===== PHASE C: UI + UX =====

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: StreamBuilder<List<Item>>(
        stream: FirestoreService.streamItems(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Empty state
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No items yet'));
          }

          // List state
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text(item.description),
                trailing: SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Text('${item.quantity}x \$${item.price}'),
                      PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('Edit'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditScreen(item: item),
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            child: const Text('Delete'),
                            onTap: () => FirestoreService.deleteItem(item.id!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditScreen(item: null)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class EditScreen extends StatefulWidget {
  final Item? item;
  const EditScreen({Key? key, this.item}) : super(key: key);

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController descCtrl;
  late TextEditingController qtyCtrl;
  late TextEditingController priceCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.item?.name ?? '');
    descCtrl = TextEditingController(text: widget.item?.description ?? '');
    qtyCtrl = TextEditingController(text: widget.item?.quantity.toString() ?? '');
    priceCtrl = TextEditingController(text: widget.item?.price.toString() ?? '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    // Validate: empty fields
    if (nameCtrl.text.isEmpty || descCtrl.text.isEmpty || qtyCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
      _showError('All fields required');
      return;
    }

    // Validate: numeric fields
    final qty = int.tryParse(qtyCtrl.text);
    final prc = double.tryParse(priceCtrl.text);
    
    if (qty == null) {
      _showError('Quantity must be a number');
      return;
    }
    if (prc == null) {
      _showError('Price must be a number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final item = Item(
        name: nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        quantity: qty,
        price: prc,
      );

      if (widget.item == null) {
        await FirestoreService.addItem(item);
        _showError('Item added!');
      } else {
        await FirestoreService.updateItem(widget.item!.id!, item);
        _showError('Item updated!');
      }

      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'Add Item' : 'Edit Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              enabled: !_isLoading,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              enabled: !_isLoading,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              enabled: !_isLoading,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _save,
                    child: Text(widget.item == null ? 'Add' : 'Update'),
                  ),
          ],
        ),
      ),
    );
  }
}