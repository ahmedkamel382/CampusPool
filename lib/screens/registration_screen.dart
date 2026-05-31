import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/car_selection_widget.dart';
import '../constants/app_locations.dart';
import '../widgets/location_picker_map.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_buttons.dart';
import '../widgets/custom_textfield.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _carMakeController = TextEditingController();
  final TextEditingController _carModelController = TextEditingController();
  final TextEditingController _carColorController = TextEditingController();
  final TextEditingController _carPlateController = TextEditingController();

  bool hasCar = false;
  bool isLoading = false;
  String? selectedGender;
  String? selectedNeighborhood;
  String? selectedCarMake;
  String? selectedCarModel;
  String? selectedCarColor;

  bool _isValidPlate(String plate) {
    return RegExp(r'^[\u0600-\u06FFa-zA-Z]{1,4}\s?\d{1,4}$').hasMatch(plate.trim());
  }

  // MAP STATE VARIABLES
  LatLng? _homeCoordinates;
  bool _showMap = false;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Profile Photo',
            toolbarColor: AppColors.navy,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Adjust Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _profileImage = File(croppedFile.path);
        });
      }
    }
  }

  void _removeImage() {
    setState(() {
      _profileImage = null;
    });
  }

  void _handleRegistration() async {
    if (_nameController.text.trim().isEmpty ||
        _idController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all mandatory fields.')));
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
      return;
    }

    if (hasCar) {
      if (_carMakeController.text.trim().isEmpty ||
          _carModelController.text.trim().isEmpty ||
          _carColorController.text.trim().isEmpty ||
          _carPlateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill out all car details.')));
        return;
      }
      if (!_isValidPlate(_carPlateController.text)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid plate. Use format: ABC 1234 or أبج 1234')));
        return;
      }
    }

    if (selectedGender == null || selectedNeighborhood == null || _homeCoordinates == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your Neighborhood and pin your location on the map.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      // --- NEW DUPLICATION CHECKS ---
      // 1. Check if Student ID is already taken
      final idCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('studentId', isEqualTo: _idController.text.trim())
          .get();

      if (idCheck.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This Student ID is already registered.')));
          setState(() => isLoading = false);
        }
        return;
      }

      // 2. Check if Email is already taken
      final emailCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (emailCheck.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This University Email is already registered.')));
          setState(() => isLoading = false);
        }
        return;
      }

      String formattedPhone = _phoneController.text.trim();
      if (formattedPhone.startsWith('0')) {
        formattedPhone = formattedPhone.substring(1);
      }

      if (formattedPhone.length != 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid phone number. Please enter a valid 11-digit Egyptian mobile number.'))
          );
          setState(() => isLoading = false);
        }
        return;
      }

      String finalDatabasePhone = '+20$formattedPhone';

      await AuthService().registerUser(
        email: _emailController.text.trim(), // Added .trim() for safety
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
        studentId: _idController.text.trim(),
        phone: finalDatabasePhone,
        gender: selectedGender!,
        defaultNeighborhood: selectedNeighborhood!,
        homeLocation: _homeCoordinates,
        hasCar: hasCar,
        carMake: _carMakeController.text.trim(),
        carModel: _carModelController.text.trim(),
        carColor: _carColorController.text.trim(),
        carPlate: _carPlateController.text.trim(),
        profileImage: _profileImage,
      );

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Upload your\npersonal photo\n(Optional)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: _profileImage != null
                          ? ClipOval(
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                          : const Icon(Icons.add_a_photo, color: Colors.white54, size: 40),
                    ),
                  ),
                  if (_profileImage != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.navy, width: 2),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text('Student Info', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            CustomTextField(controller: _nameController, hintText: 'Student Full Name', darkTheme: true),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _idController,
              hintText: 'Student ID',
              darkTheme: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            CustomTextField(
              controller: _phoneController,
              hintText: 'Mobile Number (e.g. 101234...)',
              darkTheme: true,
              keyboardType: TextInputType.phone,
              prefixText: '+20 ',
            ),
            const SizedBox(height: 12),

            CustomTextField(controller: _emailController, hintText: 'University Email (@student.aast.edu)', darkTheme: true, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            CustomTextField(controller: _passwordController, hintText: 'Create Password', isPassword: true, darkTheme: true),
            const SizedBox(height: 12),
            CustomTextField(controller: _confirmPasswordController, hintText: 'Confirm Password', isPassword: true, darkTheme: true),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Gender',
                labelStyle: const TextStyle(color: AppColors.greyText),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              dropdownColor: AppColors.navy,
              style: const TextStyle(color: AppColors.white),
              initialValue: selectedGender,
              items: ['Male', 'Female'].map((String gender) => DropdownMenuItem(value: gender, child: Text(gender))).toList(),
              onChanged: (value) => setState(() => selectedGender = value),
            ),
            const SizedBox(height: 12),

            // MAP TRIGGER: The Neighborhood Dropdown (UPDATED)
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Default Home Neighborhood',
                labelStyle: const TextStyle(color: AppColors.greyText),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              dropdownColor: AppColors.navy,
              style: const TextStyle(color: AppColors.white),
              initialValue: selectedNeighborhood,
              // NEW: Pulls dynamically from AppLocations
              items: AppLocations.neighborhoodCoordinates.keys.map((String hood) => DropdownMenuItem(value: hood, child: Text(hood))).toList(),
              onChanged: (value) {
                setState(() {
                  selectedNeighborhood = value;
                  if (value != null) {
                    _homeCoordinates = AppLocations.neighborhoodCoordinates[value];
                    _showMap = true;
                  }
                });
              },
            ),

            // THE MAP WIDGET (UPDATED WITH MISSING PARAMETER)
            if (_showMap && _homeCoordinates != null && selectedNeighborhood != null) ...[
              const SizedBox(height: 16),
              LocationPickerMap(
                initialLocation: _homeCoordinates!,
                currentNeighborhood: selectedNeighborhood!,
                // NEW: Listens for GPS geofence changes to update the dropdown!
                onNeighborhoodChanged: (newNeighborhood) {
                  setState(() {
                    selectedNeighborhood = newNeighborhood;
                  });
                },
                onLocationSelected: (newCoords) {
                  _homeCoordinates = newCoords;
                },
              ),
            ],

            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I have a car', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              value: hasCar,
              onChanged: (bool? value) => setState(() => hasCar = value ?? false),
              activeColor: AppColors.white,
              checkColor: AppColors.navy,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (hasCar) ...[
              const SizedBox(height: 16),
              const Text('Car Information', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CarSelectionWidget(
                initialMake: selectedCarMake,
                initialModel: selectedCarModel,
                initialColor: selectedCarColor,
                isDarkTheme: true,
                onChanged: (make, model, color) {
                  setState(() {
                    selectedCarMake = make;
                    selectedCarModel = model;
                    selectedCarColor = color;
                    _carMakeController.text = make ?? '';
                    _carModelController.text = model ?? '';
                    _carColorController.text = color ?? '';
                  });
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(controller: _carPlateController, hintText: 'License Plate Number', darkTheme: true),
            ],
            const SizedBox(height: 48),

            isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : CustomGoldButton(text: 'Register', onPressed: _handleRegistration),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}