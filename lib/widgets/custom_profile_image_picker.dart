import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../theme/app_colors.dart';

class CustomProfileImagePicker extends StatefulWidget {
  final File? currentImage;
  final String? existingImageUrl;
  final bool isEditing;
  final bool darkTheme;
  final Function(File) onImagePicked;
  final VoidCallback onImageRemoved;

  const CustomProfileImagePicker({
    super.key,
    required this.currentImage,
    this.existingImageUrl,
    this.isEditing = true,
    this.darkTheme = true,
    required this.onImagePicked,
    required this.onImageRemoved,
  });

  @override
  State<CustomProfileImagePicker> createState() => _CustomProfileImagePickerState();
}

class _CustomProfileImagePickerState extends State<CustomProfileImagePicker> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    // Only allow picking an image if the form is in edit mode
    if (!widget.isEditing) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Adjust Profile Photo',
              // Dynamically swap the cropper UI colors based on the theme!
              toolbarColor: widget.darkTheme ? AppColors.navy : AppColors.white,
              toolbarWidgetColor: widget.darkTheme ? Colors.white : AppColors.black,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: false, // The high-res image fix
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
          // Send the new file back to the parent screen
          widget.onImagePicked(File(croppedFile.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load this image. Please try another one.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if there is ANY image to display (local file or network URL)
    final bool hasImage = widget.currentImage != null ||
        (widget.existingImageUrl != null && widget.existingImageUrl!.isNotEmpty);

    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.darkTheme ? Colors.white10 : AppColors.bgLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.darkTheme ? Colors.white24 : AppColors.navy.withValues(alpha:0.1),
                  width: 2,
                ),
              ),
              child: _buildImageContent(),
            ),
          ),

          // Only show the RED 'X' if they are editing AND there is an image to delete
          if (widget.isEditing && hasImage)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: widget.onImageRemoved,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.darkTheme ? AppColors.navy : AppColors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // A helper function to figure out exactly what to show inside the circle
  Widget _buildImageContent() {
    if (widget.currentImage != null) {
      // 1. Show the brand new file they just picked
      return ClipOval(child: Image.file(widget.currentImage!, fit: BoxFit.cover, width: 120, height: 120));

    } else if (widget.existingImageUrl != null && widget.existingImageUrl!.isNotEmpty) {
      // 2. Show their saved Firestore picture
      return ClipOval(
        child: Image.network(
          widget.existingImageUrl!,
          fit: BoxFit.cover,
          width: 120,
          height: 120,
          errorBuilder: (c, e, s) => Icon(Icons.person, size: 60, color: widget.darkTheme ? Colors.white54 : AppColors.greyText),
        ),
      );

    } else {
      // 3. Show the empty placeholder icon
      return Icon(
        widget.isEditing ? Icons.add_a_photo : Icons.person,
        color: widget.darkTheme ? Colors.white54 : AppColors.greyText,
        size: widget.isEditing ? 40 : 60,
      );
    }
  }
}