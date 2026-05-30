import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../widgets/car_selection_widget.dart';
import '../constants/app_locations.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/location_picker_map.dart';
import '../providers/user_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  String? _selectedGender;
  String? _selectedNeighborhood;

  LatLng? _homeCoordinates;

  bool _hasCar = false;

  String? _selectedCarMake;
  String? _selectedCarModel;
  String? _selectedCarColor;

  final List<String> _genderOptions = [
    'Male',
    'Female',
  ];

  late TextEditingController _carMakeController;
  late TextEditingController _carColorController;
  late TextEditingController _carModelController;
  late TextEditingController _carPlateController;

  File? _newProfileImage;
  bool _removeExistingImage = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _nameController.dispose();
    _phoneController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
  }

  void _initControllers() {
    // Read from the Provider instead of constructor arguments
    final userData = context.read<UserProvider>().userData ?? {};

    _nameController = TextEditingController(
      text: userData['fullName'] ?? '',
    );

    _phoneController = TextEditingController(
      text: _phoneForEditing(userData['phone']),
    );

    _selectedGender = _genderForDropdown(userData['gender']);
    _selectedNeighborhood = userData['defaultNeighborhood'];

    if (userData['homeLocation'] != null) {
      _homeCoordinates = LatLng(
        (userData['homeLocation']['lat'] as num).toDouble(),
        (userData['homeLocation']['lng'] as num).toDouble(),
      );
    } else if (_selectedNeighborhood != null) {
      _homeCoordinates = AppLocations.neighborhoodCoordinates[_selectedNeighborhood];
    } else {
      _homeCoordinates = null;
    }

    _newProfileImage = null;
    _removeExistingImage = false;

    _hasCar = userData['hasCar'] ?? false;

    _carMakeController = TextEditingController();
    _carModelController = TextEditingController();
    _carColorController = TextEditingController();
    _carPlateController = TextEditingController();

    _selectedCarMake = null;
    _selectedCarModel = null;
    _selectedCarColor = null;

    if (_hasCar && userData['carInfo'] != null) {
      final savedMake = userData['carInfo']['make'] ?? '';
      final savedModel = userData['carInfo']['model'] ?? '';
      final savedColor = userData['carInfo']['color'] ?? '';

      // Initialize selected values based on DB
      _selectedCarMake = savedMake.isNotEmpty ? savedMake : null;
      _selectedCarModel = savedModel.isNotEmpty ? savedModel : null;

      _selectedCarColor = carColorsList.firstWhere(
            (c) => c.toLowerCase() == savedColor.toString().toLowerCase(),
        orElse: () => carColorsList.first,
      );

      _carMakeController.text = _selectedCarMake ?? '';
      _carModelController.text = _selectedCarModel ?? '';
      _carColorController.text = _selectedCarColor ?? '';
      _carPlateController.text = userData['carInfo']['plate'] ?? '';
    }
  }

  String? _genderForDropdown(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.startsWith('m')) return 'Male';
    if (text.startsWith('f')) return 'Female';
    return null;
  }

  String _displayGender(dynamic value) {
    return _genderForDropdown(value) ?? 'Not set';
  }

  String _phoneForEditing(dynamic value) {
    String phone = value?.toString().trim() ?? '';
    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (phone.startsWith('+20')) {
      phone = phone.substring(3);
    } else if (phone.startsWith('0020')) {
      phone = phone.substring(4);
    } else if (phone.startsWith('20') && phone.length >= 12) {
      phone = phone.substring(2);
    }

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    return phone;
  }

  String _displayPhone(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Not set';
    return raw;
  }

  String? _formattedPhoneForFirebase() {
    String phone = _phoneController.text.trim();
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0020')) {
      phone = phone.substring(4);
    } else if (phone.startsWith('20') && phone.length >= 12) {
      phone = phone.substring(2);
    }

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    if (!RegExp(r'^1[0-9]{9}$').hasMatch(phone)) {
      return null;
    }

    return '+20$phone';
  }

  bool _isValidPlate(String plate) {
    return RegExp(r'^[\u0600-\u06FFa-zA-Z]{1,4}\s?\d{1,4}$').hasMatch(plate.trim());
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Profile Photo',
          toolbarColor: AppColors.navy,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Adjust Profile Photo',
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _newProfileImage = File(croppedFile.path);
        _removeExistingImage = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _newProfileImage = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _saveProfileChanges() async {
    final String fullName = _nameController.text.trim();

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name.')));
      return;
    }

    final String? formattedPhone = _formattedPhoneForFirebase();
    if (formattedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Egyptian phone number.')));
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your gender.')));
      return;
    }

    if (_hasCar) {
      if (_carMakeController.text.trim().isEmpty || _carModelController.text.trim().isEmpty || _carColorController.text.trim().isEmpty || _carPlateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all car details or uncheck the box.')));
        return;
      }

      if (!_isValidPlate(_carPlateController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid plate. Use format: ABC 1234 or أبج 1234')));
        return;
      }
    }

    if (_selectedNeighborhood != null && _homeCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pin your location on the map.')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updates = {
        'fullName': fullName,
        'phone': formattedPhone,
        'gender': _selectedGender,
        'defaultNeighborhood': _selectedNeighborhood,
        'homeLocation': _homeCoordinates != null ? {
          'lat': _homeCoordinates!.latitude,
          'lng': _homeCoordinates!.longitude,
        } : null,
        'hasCar': _hasCar,
      };

      if (_hasCar) {
        updates['carInfo'] = {
          'make': _carMakeController.text.trim(),
          'model': _carModelController.text.trim(),
          'color': _carColorController.text.trim(),
          'plate': _carPlateController.text.trim(),
        };
      } else {
        updates['carInfo'] = null;
      }

      await AuthService().updateUserData(
        updates,
        newProfileImage: _newProfileImage,
        removeImage: _removeExistingImage,
      );

      // Force provider to update and UI will react naturally
      if (mounted) {
        context.read<UserProvider>().fetchUserData();
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account?', style: TextStyle(color: Colors.redAccent)),
          content: const Text('This action is permanent and will wipe all your data. Are you absolutely sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.navy)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                try {
                  await AuthService().deleteUserAccount();
                  if (context.mounted) {
                    context.read<UserProvider>().clearUserData();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log out and log back in before deleting your account for security.')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    String? prefixText,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        helperText: helperText,
        filled: true,
        fillColor: AppColors.bgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [bool isEditable = true]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.greyText, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: (!isEditable && _isEditing) ? AppColors.greyText : AppColors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Read actively from provider so screen updates automatically
    final userData = context.watch<UserProvider>().userData ?? {};
    final String studentId = userData['studentId'] ?? 'No ID';
    final String email = userData['email'] ?? 'No Email';
    final String profileImageUrl = userData['profileImageUrl'] ?? '';
    final bool hasCarSaved = userData['hasCar'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.black)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy)),
            )
          else if (_isEditing)
            IconButton(icon: const Icon(Icons.check, color: Colors.green, size: 28), onPressed: _saveProfileChanges)
          else
            IconButton(icon: const Icon(Icons.edit_square, color: AppColors.navy), onPressed: () => setState(() => _isEditing = true)),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  context.read<UserProvider>().clearUserData();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  if (_isEditing)
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: AppColors.bgLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.navy.withValues(alpha:0.1), width: 2),
                            ),
                            child: _newProfileImage != null
                                ? ClipOval(child: Image.file(_newProfileImage!, fit: BoxFit.cover, width: 120, height: 120))
                                : (!_removeExistingImage && profileImageUrl.isNotEmpty)
                                ? ClipOval(child: Image.network(profileImageUrl, fit: BoxFit.cover, width: 120, height: 120))
                                : const Icon(Icons.add_a_photo, color: AppColors.greyText, size: 40),
                          ),
                        ),
                        if (_newProfileImage != null || (!_removeExistingImage && profileImageUrl.isNotEmpty))
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _removeImage,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 2)),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.bgLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.navy.withValues(alpha:0.1), width: 2),
                      ),
                      child: profileImageUrl.isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          profileImageUrl,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 60, color: AppColors.greyText),
                        ),
                      )
                          : const Icon(Icons.person, size: 60, color: AppColors.greyText),
                    ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (_) {
                      final int ratingSum = (userData['ratingSum'] ?? 0).toInt();
                      final int ratingCount = (userData['ratingCount'] ?? 0).toInt();
                      final String ratingText = ratingCount == 0
                          ? 'No ratings yet'
                          : '${(ratingSum / ratingCount).toStringAsFixed(1)} / 5.0  ($ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'})';
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) {
                              final filled = ratingCount > 0 && (i + 1) <= (ratingSum / ratingCount).round();
                              return Icon(filled ? Icons.star : Icons.star_border, color: AppColors.gold, size: 20);
                            }),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ratingCount == 0 ? 'No ratings yet' : 'Trust Rating: $ratingText',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black)),
            const SizedBox(height: 16),
            _buildInfoRow('Student ID', studentId, false),
            _buildInfoRow('University Email', email, false),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              CustomTextField(controller: _nameController, hintText: 'Full Name', darkTheme: false),
              const SizedBox(height: 12),
              _buildEditTextField(
                controller: _phoneController,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
                prefixText: '+20 ',
                helperText: 'Example: 1012345678',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Gender', filled: true, fillColor: AppColors.bgLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                initialValue: _selectedGender,
                items: _genderOptions.map((gender) => DropdownMenuItem(value: gender, child: Text(gender))).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Default Home Neighborhood', filled: true, fillColor: AppColors.bgLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                initialValue: _selectedNeighborhood,
                items: AppLocations.neighborhoodCoordinates.keys.map((hood) => DropdownMenuItem(value: hood, child: Text(hood))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedNeighborhood = value;
                    if (value != null) _homeCoordinates = AppLocations.neighborhoodCoordinates[value];
                  });
                },
              ),
              if (_selectedNeighborhood != null && _homeCoordinates != null) ...[
                const SizedBox(height: 16),
                LocationPickerMap(
                  darkTheme: false,
                  initialLocation: _homeCoordinates!,
                  currentNeighborhood: _selectedNeighborhood!,
                  onNeighborhoodChanged: (newNeighborhood) => setState(() => _selectedNeighborhood = newNeighborhood),
                  onLocationSelected: (newCoords) => setState(() => _homeCoordinates = newCoords),
                ),
              ],
            ] else ...[
              _buildInfoRow('Full Name', userData['fullName'] ?? 'Not set'),
              _buildInfoRow('Phone', _displayPhone(userData['phone'])),
              _buildInfoRow('Gender', _displayGender(userData['gender'])),
              _buildInfoRow('Neighborhood', userData['defaultNeighborhood'] ?? 'Not set'),
              if (_homeCoordinates != null) ...[
                const SizedBox(height: 8),
                const Text('Saved Location', style: TextStyle(color: AppColors.greyText, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  height: 180,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.navy.withValues(alpha:0.1))),
                  child: FlutterMap(
                    options: MapOptions(initialCenter: _homeCoordinates!, initialZoom: 15.0),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.aastmt.campuspool'),
                      MarkerLayer(markers: [Marker(point: _homeCoordinates!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40))]),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
            if (_isEditing) ...[
              const Text('Car Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black)),
              CheckboxListTile(
                title: const Text('I have a car', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                value: _hasCar,
                onChanged: (bool? value) => setState(() => _hasCar = value ?? false),
                activeColor: AppColors.navy,
                checkColor: AppColors.white,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_hasCar) ...[
                const SizedBox(height: 8),
                CarSelectionWidget(
                  initialMake: _selectedCarMake,
                  initialModel: _selectedCarModel,
                  initialColor: _selectedCarColor,
                  isDarkTheme: false,
                  onChanged: (make, model, color) {
                    setState(() {
                      _selectedCarMake = make;
                      _selectedCarModel = model;
                      _selectedCarColor = color;
                      _carMakeController.text = make ?? '';
                      _carModelController.text = model ?? '';
                      _carColorController.text = color ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                CustomTextField(controller: _carPlateController, hintText: 'License Plate', darkTheme: false),
              ],
            ] else if (hasCarSaved) ...[
              const Text('Car Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.black)),
              const SizedBox(height: 16),
              _buildInfoRow('Make', userData['carInfo']?['make'] ?? 'Not set'),
              _buildInfoRow('Model', userData['carInfo']?['model'] ?? 'Not set'),
              _buildInfoRow('Color', userData['carInfo']?['color'] ?? 'Not set'),
              _buildInfoRow('Plate', userData['carInfo']?['plate'] ?? 'Not set'),
            ],
            if (_isEditing) ...[
              const SizedBox(height: 48),
              const Divider(color: Colors.redAccent, thickness: 0.5),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _showDeleteConfirmation,
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  label: const Text('Delete Account Permanently', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => setState(() { _disposeControllers(); _initControllers(); _isEditing = false; }),
                  child: const Text('Cancel Edit', style: TextStyle(color: AppColors.greyText)),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}