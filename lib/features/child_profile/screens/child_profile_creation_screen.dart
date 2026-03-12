import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ChildProfileCreationScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;

  const ChildProfileCreationScreen({
    super.key,
    this.sessionData = const {},
  });

  @override
  State<ChildProfileCreationScreen> createState() => _ChildProfileCreationScreenState();
}

class _ChildProfileCreationScreenState extends State<ChildProfileCreationScreen> {
  late TextEditingController _nameController;
  DateTime? _dob;
  String? _gender;
  final TextEditingController _historyController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.sessionData['childName'] ?? '');
    _dob = widget.sessionData['dob'];
    _gender = widget.sessionData['gender'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty || _dob == null || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required child info fields.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Mock backend save delay
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    if (mounted) {
      // Mock generated child ID
      const childId = 'child_12345';
      context.go('/child/profile', extra: {
        'childId': childId,
        'viewerRole': 'hcw',
      });
    }
  }

  Widget _buildGenderChip(String label) {
    final isSelected = _gender == label;
    return ChoiceChip(
      label: Text(label, style: AppTheme.bodyText.copyWith(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _gender = label;
          });
        }
      },
      selectedColor: AppTheme.primaryTeal,
      backgroundColor: AppTheme.primaryPale,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      showCheckmark: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Create Child Profile', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPale,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primaryLight, width: 2),
                        ),
                        child: const Icon(Icons.person, size: 50, color: AppTheme.primaryTeal),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Name
                Text("Child's Full Name *", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Liam Smith',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                // DOB
                Text("Date of Birth *", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365)),
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dob = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dob == null 
                            ? 'Select Date' 
                            : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
                          style: AppTheme.bodyText,
                        ),
                        const Icon(Icons.calendar_today, color: AppTheme.primaryTeal, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Gender
                Text("Gender *", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildGenderChip('Male'),
                    const SizedBox(width: 12),
                    _buildGenderChip('Female'),
                  ],
                ),
                const SizedBox(height: 24),

                // Medical History
                Text("Medical History Notes", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _historyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Premature birth, recurrent ear infections, etc.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),

                // Parent Link
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.family_restroom, color: AppTheme.primaryTeal),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Link Parent Profile", style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text("Search by email or phone", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Search parent modal
                        }, 
                        child: const Text("LINK", style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('CREATE PROFILE', style: AppTheme.buttonText.copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
