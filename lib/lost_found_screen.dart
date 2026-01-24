import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Import your ApiConfig file
// import 'api_config.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  // Controllers
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();

  // User data
  int? userId;
  String? userName;
  String? userEmail;
  String? userPhone;
  String? userRole;

  // Report form data
  String selectedType = 'found';
  String selectedCategory = 'Electronics (Laptop, Phone, Charger)';
  String selectedLocation = 'Library - 1st Floor';
  File? _image1;
  File? _image2;
  final ImagePicker _picker = ImagePicker();

  // Search & Filter
  String searchQuery = '';
  String filterType = 'all';
  String filterStatus = 'all';
  String filterCategory = 'all';
  String filterLocation = 'all';

  // Data lists
  List<String> categories = [];
  List<String> locations = [];
  List<Map<String, dynamic>> items = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadOptions();
    _loadItems();
  }

 Future<void> _loadUserData() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    userId = prefs.getInt('userId');
    userName = prefs.getString('full_name'); // ✅ Change from 'userName' to 'full_name'
    userEmail = prefs.getString('email');
    userPhone = prefs.getString('phone_number');
    userRole = prefs.getString('role');
  });
  
  // ✅ ADD DEBUG LOGGING
  print('📱 Loaded user data from SharedPreferences:');
  print('userId: $userId');
  print('userName: $userName');
  print('userEmail: $userEmail');
  print('userPhone: $userPhone');
  print('userRole: $userRole');
}

  Future<void> _loadOptions() async {
    try {
      // Replace with: ApiConfig.getLostFoundOptions
      final response = await http.get(
        Uri.parse('http://192.168.100.63:3000/get-lost-found-options'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = List<String>.from(data['categories']);
          locations = List<String>.from(data['locations']);
          if (categories.isNotEmpty) selectedCategory = categories[0];
          if (locations.isNotEmpty) selectedLocation = locations[0];
        });
      }
    } catch (e) {
      _showSnack('Failed to load options: $e');
    }
  }

  Future<void> _loadItems() async {
    if (userId == null || userRole == null) return;

    setState(() => isLoading = true);

    try {
      // Replace with: ApiConfig.getLostFoundItems
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/get-lost-found-items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'userRole': userRole,
          'searchQuery': searchQuery,
          'type': filterType,
          'status': filterStatus,
          'category': filterCategory,
          'location': filterLocation,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          items = List<Map<String, dynamic>>.from(data['items']);
        });
      } else {
        _showSnack('Failed to load items');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage(int imageNumber) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        if (imageNumber == 1) {
          _image1 = File(picked.path);
        } else {
          _image2 = File(picked.path);
        }
      });
    }
  }

  Future<String?> _imageToBase64(File? image) async {
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _reportItem() async {
  if (_itemNameController.text.isEmpty ||
      _descriptionController.text.isEmpty ||
      _image1 == null) {
    _showSnack('Please fill all required fields and upload at least one image');
    return;
  }

  // ✅ ADD THIS DEBUG LOGGING
  print('🔍 DEBUG - User Data:');
  print('userId: $userId');
  print('userName: $userName');
  print('userEmail: $userEmail');
  print('userRole: $userRole');
  print('selectedType: $selectedType');
  print('selectedCategory: $selectedCategory');
  print('selectedLocation: $selectedLocation');

  // Check if user data is loaded
  if (userId == null || userName == null || userEmail == null || userRole == null) {
    _showSnack('User data not loaded. Please restart the app.');
    return;
  }

  setState(() => isLoading = true);

  try {
    final image1Base64 = await _imageToBase64(_image1);
    final image2Base64 = await _imageToBase64(_image2);

    // ✅ ADD THIS TO SEE THE REQUEST BODY
    final requestBody = {
      'item_name': _itemNameController.text,
      'description': _descriptionController.text,
      'image1': image1Base64,
      'image2': image2Base64,
      'type': selectedType,
      'category': selectedCategory,
      'location': selectedLocation,
      'reported_by_id': userId,
      'reported_by_name': userName,
      'reported_by_email': userEmail,
      'reported_by_phone': userPhone,
      'reported_by_role': userRole,
    };

    print('📤 Sending request body: ${json.encode(requestBody)}');

    final response = await http.post(
      Uri.parse('http://192.168.100.63:3000/report-lost-found-item'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestBody),
    );

    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');

    if (response.statusCode == 201) {
      _showSnack('Item reported successfully! Email confirmation sent.');
      _clearForm();
      _loadItems();
    } else {
      final data = json.decode(response.body);
      _showSnack(data['message'] ?? 'Failed to report item');
    }
  } catch (e) {
    print('❌ Error: $e');
    _showSnack('Error: $e');
  } finally {
    setState(() => isLoading = false);
  }
}

  void _clearForm() {
    _itemNameController.clear();
    _descriptionController.clear();
    setState(() {
      _image1 = null;
      _image2 = null;
      selectedType = 'found';
      if (categories.isNotEmpty) selectedCategory = categories[0];
      if (locations.isNotEmpty) selectedLocation = locations[0];
    });
  }

  Future<void> _claimItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim This Item?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ Important Warning:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            const Text(
              'By claiming this item, your contact information (name and email) will be shared with the admin and the person who reported this item.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'If the real owner contacts the admin, your information may be shared with them. False claims may result in consequences.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure this item belongs to you?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Claim It'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      // Replace with: ApiConfig.claimItem
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/claim-item'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'itemId': item['id'],
          'claimed_by_id': userId,
          'claimed_by_name': userName,
          'claimed_by_email': userEmail,
          'claimed_by_phone': userPhone,
          'claimed_by_role': userRole,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showContactDialog(
          data['reporterName'],
          data['reporterEmail'],
          item,
        );
        _loadItems();
      } else {
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to claim item');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showContactDialog(String name, String email, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Claimed Successfully!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ You have claimed this item. Here is the contact information of the person who reported it:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $name',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Email: $email', style: const TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '📧 Please contact them via email to arrange pickup.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            const Text(
              '✔️ After receiving the item, click "Verify Received" in the item card to mark it as returned.',
              style: TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Item Received?'),
        content: const Text(
          'Please confirm that you have successfully received this item. This action will mark the item as returned and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      // Replace with: ApiConfig.verifyItem
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/verify-item'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'itemId': item['id'],
          'userId': userId,
          'userRole': userRole,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Item verified as returned successfully!');
        _loadItems();
      } else {
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to verify item');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _editItem(Map<String, dynamic> item) async {
    // Pre-fill form with item data
    _itemNameController.text = item['item_name'];
    _descriptionController.text = item['description'];
    setState(() {
      selectedType = item['type'];
      selectedCategory = item['category'];
      selectedLocation = item['location'];
      // Note: Images cannot be pre-loaded from Base64 easily, user must re-upload
    });

    // Scroll to top to show form
    _showSnack('Edit the form above and submit to update');
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (item['claimed_by_id'] != null) {
      _showSnack('Cannot delete: Item has been claimed');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isLoading = true);

    try {
      // Replace with: ApiConfig.deleteLostFoundItem
      final response = await http.post(
        Uri.parse('http://192.168.100.63:3000/delete-lost-found-item'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'itemId': item['id'],
          'userId': userId,
          'userRole': userRole,
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Report deleted successfully');
        _loadItems();
      } else {
        final data = json.decode(response.body);
        _showSnack(data['message'] ?? 'Failed to delete report');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _highlightText(String text, String query) {
    if (query.isEmpty) return text;
    return text.replaceAll(
      RegExp(query, caseSensitive: false),
      '**$query**',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Lost & Found",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReportSection(),
                  const SizedBox(height: 25),
                  _buildSearchSection(),
                  const SizedBox(height: 15),
                  _buildFilterSection(),
                  const SizedBox(height: 15),
                  _buildItemsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildReportSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Item",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Type Selection
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Found Item'),
                    value: 'found',
                    groupValue: selectedType,
                    onChanged: (val) => setState(() => selectedType = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Lost Item'),
                    value: 'lost',
                    groupValue: selectedType,
                    onChanged: (val) => setState(() => selectedType = val!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildTextField("Item Name*", _itemNameController),
            const SizedBox(height: 12),
            _buildTextField("Description*", _descriptionController, maxLines: 3),
            const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category*',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87, // ✅ ADD COLOR
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat, 
                      child: Text(
                        cat,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
                ),

            const SizedBox(height: 12),

                            // Location Dropdown
                DropdownButtonFormField<String>(
                  value: selectedLocation,
                  decoration: const InputDecoration(
                    labelText: 'Location*',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                  ),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87, // ✅ ADD COLOR
                  ),
                  items: locations.map((loc) {
                    return DropdownMenuItem(
                      value: loc, 
                      child: Text(
                        loc,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedLocation = val!),
                ),

            const SizedBox(height: 16),

            // Image Upload
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(1),
                    icon: const Icon(Icons.image, color: Colors.green),
                    label: Text(
                      _image1 == null ? 'Upload Image 1*' : 'Image 1 ✓',
                      style: const TextStyle(color: Colors.green),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(2),
                    icon: const Icon(Icons.image, color: Colors.green),
                    label: Text(
                      _image2 == null ? 'Upload Image 2' : 'Image 2 ✓',
                      style: const TextStyle(color: Colors.green),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),

            if (_image1 != null || _image2 != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_image1 != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_image1!, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                  if (_image1 != null && _image2 != null) const SizedBox(width: 8),
                  if (_image2 != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_image2!, height: 100, fit: BoxFit.cover),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reportItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Submit Report",
                  style: TextStyle(
                    color: Colors.white,
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

  Widget _buildSearchSection() {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() => searchQuery = val);
        _loadItems();
      },
      decoration: InputDecoration(
        hintText: "Search by item name or description...",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => searchQuery = '');
                  _loadItems();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', 'all', filterType, (val) {
            setState(() => filterType = val);
            _loadItems();
          }),
          _buildFilterChip('Lost', 'lost', filterType, (val) {
            setState(() => filterType = val);
            _loadItems();
          }),
          _buildFilterChip('Found', 'found', filterType, (val) {
            setState(() => filterType = val);
            _loadItems();
          }),
          _buildFilterChip('Pending', 'pending', filterStatus, (val) {
            setState(() => filterStatus = val);
            _loadItems();
          }),
          _buildFilterChip('Returned', 'returned', filterStatus, (val) {
            setState(() => filterStatus = val);
            _loadItems();
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, String value, String currentFilter, Function(String) onTap) {
    final isSelected = currentFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(value),
        selectedColor: Colors.green.shade100,
        checkmarkColor: Colors.green,
      ),
    );
  }

  Widget _buildItemsList() {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No items found matching your search.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemCard(items[index]),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final bool isOwnReport = item['isOwnReport'] ?? false;
    final bool hasClaimed = item['hasClaimed'] ?? false;
    final bool canEdit = item['canEdit'] ?? false;
    final bool canClaim = item['canClaim'] ?? false;
    final bool canVerify = item['canVerify'] ?? false;
    final bool isReturned = item['status'] == 'returned';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item['type'] == 'lost'
                  ? Colors.orange.shade50
                  : Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item['type'] == 'lost' ? Icons.search_off : Icons.search,
                  color: item['type'] == 'lost' ? Colors.orange : Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${item['type'] == 'lost' ? 'Lost' : 'Found'} Item',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isReturned ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isReturned ? 'Returned' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: isReturned ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Images
          if (item['image1'] != null || item['image2'] != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (item['image1'] != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(item['image1']),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (item['image1'] != null && item['image2'] != null)
                    const SizedBox(width: 8),
                  if (item['image2'] != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(item['image2']),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['description'],
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.category, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item['category'],
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item['location'],
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(item['reported_at']),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Own Report Actions
                if (isOwnReport && canEdit) ...[
                  TextButton.icon(
                    onPressed: () => _editItem(item),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteItem(item),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],

                // Cannot edit/delete after claiming
                if (isOwnReport && !canEdit && item['claimed_by_id'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'Cannot edit/delete (item claimed)',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),

                // Claim Button
                if (canClaim)
                  ElevatedButton.icon(
                    onPressed: () => _claimItem(item),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Claim This Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),

                // Verify Button
                if (canVerify)
                  ElevatedButton.icon(
                    onPressed: () => _verifyItem(item),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),

                // View Only (for returned items you claimed)
                if (hasClaimed && isReturned)
                  const Chip(
                    avatar: Icon(Icons.check_circle, color: Colors.green, size: 18),
                    label: Text('You verified this'),
                    backgroundColor: Color(0xFFD4EDDA),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes} min ago';
        }
        return '${diff.inHours} hours ago';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}