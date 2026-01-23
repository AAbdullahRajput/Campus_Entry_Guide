import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  final List<Map<String, dynamic>> _reportedItems = [];
  List<Map<String, dynamic>> _searchResults = [];

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _reportItem() {
    if (_itemNameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _pickedImage == null) {
      _showSnack("Please complete all fields");
      return;
    }

    setState(() {
      _reportedItems.add({
        "name": _itemNameController.text,
        "description": _descriptionController.text,
        "image": _pickedImage!,
        "verified": false,
      });
      _searchResults = List.from(_reportedItems);
      _itemNameController.clear();
      _descriptionController.clear();
      _pickedImage = null;
    });

    _showSnack("Item reported successfully");
  }

  void _searchItems(String query) {
    setState(() {
      _searchResults = _reportedItems.where((item) {
        return item['name'].toLowerCase().contains(query.toLowerCase()) ||
            item['description'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _verifyItem(int index) {
    setState(() {
      _reportedItems[index]['verified'] = true;
      _searchResults[index]['verified'] = true;
    });
    _showSnack("Item verified by admin");
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Lost & Found"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Report Item"),
            _reportCard(),
            const SizedBox(height: 25),

            _sectionTitle("Search Items"),
            _searchField(),
            const SizedBox(height: 15),

            _sectionTitle("Reported Items"),
            _searchResults.isEmpty
                ? const Center(child: Text("No items found"))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _searchResults.length,
                    itemBuilder: (_, index) =>
                        _itemCard(_searchResults[index], index),
                  ),
          ],
        ),
      ),
    );
  }

  // ---------- UI Components ----------

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );

  Widget _reportCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _inputField("Item Name", _itemNameController),
            const SizedBox(height: 12),
            _inputField("Description", _descriptionController),
            const SizedBox(height: 12),

            Row(
              children: [
              ElevatedButton.icon(
  onPressed: _pickImage,
  icon: const Icon(Icons.image, color: Colors.green),
  label: const Text(
    "Upload Image",
    style: TextStyle(
      color: Colors.green,
      fontWeight: FontWeight.bold,
    ),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Colors.green),
    ),
  ),
),

                const SizedBox(width: 12),
                _pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _pickedImage!,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Text("No image"),
              ],
            ),
            const SizedBox(height: 15),

          SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: _reportItem,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.green),
      ),
    ),
    child: const Text(
      "Report Item",
      style: TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  ),
),

 

          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: _searchItems,
      decoration: InputDecoration(
        hintText: "Search by name or description",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item, int index) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(item['image'], width: 55, height: 55, fit: BoxFit.cover),
        ),
        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item['description']),
        trailing: item['verified']
            ? const Chip(
                label: Text("Verified"),
                backgroundColor: Color(0xFFD4EDDA),
                avatar: Icon(Icons.verified, color: Colors.green),
              )
            : IconButton(
                icon: const Icon(Icons.verified_outlined),
                onPressed: () => _verifyItem(index),
                tooltip: "Verify (Admin)",
              ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
