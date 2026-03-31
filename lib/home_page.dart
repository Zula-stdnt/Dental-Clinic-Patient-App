import 'package:flutter/material.dart';
import 'booking_page.dart';

class DentalService {
  final String name;
  final String description;
  final String priceRange;
  final String category;
  final String imagePath;

  DentalService({
    required this.name,
    required this.description,
    required this.priceRange,
    required this.category,
    required this.imagePath,
  });
}

class HomePage extends StatefulWidget {
  final String userName;
  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchQuery = "";
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Orthodontics",
    "Check-ups",
    "Dentures",
    "Root Canal",
    "Cleaning",
    "Extraction",
    "Whitening",
  ];

  final List<DentalService> _allServices = [
    DentalService(
      name: "Braces & Orthodontics",
      description:
          "Braces and orthodontic treatment are used to correct misaligned teeth and bite problems. Braces gradually move teeth into their proper position using brackets, wires, and adjustments over time.",
      priceRange: "₱35,000 – ₱50,000",
      category: "Orthodontics",
      imagePath: "assets/Braces & Orthodontics.jfif",
    ),
    DentalService(
      name: "Dental Check-ups & Exams",
      description:
          "A dental check-up and examination is a routine dental visit where the dentist inspects the overall health of the patient’s teeth and gums. Regular check-ups help detect dental problems early.",
      priceRange: "₱500 – ₱1,000",
      category: "Check-ups",
      imagePath: "assets/Dental Check-ups & Exams.jfif",
    ),
    DentalService(
      name: "Dentures (Full and Partial)",
      description:
          "Dentures are removable dental appliances used to replace missing teeth. Dentures help restore chewing ability, improve speech, and maintain facial structure.",
      priceRange: "₱5,000 – ₱15,000",
      category: "Dentures",
      imagePath: "assets/Dentures (Full and Partian).jfif",
    ),
    DentalService(
      name: "Root Canal Therapy",
      description:
          "Root canal therapy is a dental procedure used to treat infected or severely damaged tooth pulp. This treatment helps save the natural tooth and relieves pain caused by infection.",
      priceRange: "₱3,000 – ₱7,000",
      category: "Root Canal",
      imagePath: "assets/Root Canal Therapy.jfif",
    ),
    DentalService(
      name: "Tooth Cleaning",
      description:
          "Tooth cleaning, also known as dental prophylaxis, is a procedure that removes plaque, tartar, and stains from the teeth. Regular tooth cleaning helps prevent cavities.",
      priceRange: "₱800 – ₱1,500",
      category: "Cleaning",
      imagePath: "assets/Tooth Cleaning.jfif",
    ),
    DentalService(
      name: "Tooth Extraction",
      description:
          "Tooth extraction is the removal of a tooth that is severely damaged, decayed, or causing dental problems. The dentist carefully removes the tooth to relieve pain.",
      priceRange: "₱600 – ₱1,200",
      category: "Extraction",
      imagePath: "assets/Tooth Extraction.jfif",
    ),
    DentalService(
      name: "Teeth Whitening",
      description:
          "Teeth whitening is a cosmetic dental procedure that lightens the color of the teeth and removes stains or discoloration.",
      priceRange: "₱3,000 – ₱5,000",
      category: "Whitening",
      imagePath: "assets/Teeth Whitening.jfif",
    ),
  ];

  List<DentalService> get _filteredServices {
    return _allServices.where((service) {
      final matchesCategory =
          _selectedCategory == "All" || service.category == _selectedCategory;
      final matchesSearch =
          service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayedServices = _filteredServices;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // NEW: Entire page is a single scroll view. Header is no longer pinned!
      body: ListView(
        padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${widget.userName}! 👋",
                  style: TextStyle(
                    fontSize: 22, // NEW: Scaled down font
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4), // NEW: Tighter spacing
                Text(
                  "What dental service do you need today?",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // Compact Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: SizedBox(
              height: 46, // NEW: Thinner search bar
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: "Search for 'Cleaning', 'Braces'...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.blue.shade800,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue.shade800,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tightened Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.blue.shade900,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12, // NEW: Smaller chip text
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: Colors.blue.shade800,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.blue.shade800
                            : Colors.blue.shade100,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected)
                        setState(() => _selectedCategory = category);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12), // NEW: Tighter spacing before list
          // Service Catalog
          if (displayedServices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "No services found.",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...displayedServices
                .map(
                  (service) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ), // NEW: Tighter vertical gap
                    child: ServiceCardWidget(service: service),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }
}

// Stateful Service Card (Untouched logic, just tightened margins)
class ServiceCardWidget extends StatefulWidget {
  final DentalService service;
  const ServiceCardWidget({super.key, required this.service});

  @override
  State<ServiceCardWidget> createState() => _ServiceCardWidgetState();
}

class _ServiceCardWidgetState extends State<ServiceCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ), // NEW: Slightly sharper corners
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Image.asset(
              widget.service.imagePath,
              height: 140, // NEW: Thinner image
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 140,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey.shade400,
                  size: 30,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.topCenter,
                  child: Text(
                    widget.service.description,
                    maxLines: _isExpanded
                        ? null
                        : 2, // NEW: Show less by default
                    overflow: _isExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      _isExpanded ? "Read Less" : "Read More",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.service.priceRange,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BookingPage(),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    minimumSize: const Size(100, 45),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
