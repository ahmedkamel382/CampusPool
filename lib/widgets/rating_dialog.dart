import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../services/ride_service.dart';

class RatingDialog extends StatefulWidget {
  final String rideId;
  final String driverUid;
  final String driverName;

  const RatingDialog({
    super.key,
    required this.rideId,
    required this.driverUid,
    required this.driverName,
  });

  /// Show the dialog and return true if a rating was submitted.
  static Future<bool> show({
    required BuildContext context,
    required String rideId,
    required String driverUid,
    required String driverName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        rideId: rideId,
        driverUid: driverUid,
        driverName: driverName,
      ),
    );
    return result == true;
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedStars = 0;
  bool _isSubmitting = false;
  bool _submitted = false;

  Future<void> _submit() async {
    if (_selectedStars == 0) return;

    setState(() => _isSubmitting = true);

    try {
      await RideService().submitDriverRating(
        rideId: widget.rideId,
        driverUid: widget.driverUid,
        stars: _selectedStars,
      );
      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ));
        Navigator.pop(context, false);
      }
    }
  }

  String get _starLabel {
    switch (_selectedStars) {
      case 1: return 'Poor';
      case 2: return 'Fair';
      case 3: return 'Good';
      case 4: return 'Great';
      case 5: return 'Excellent!';
      default: return 'Tap a star to rate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: _submitted ? _buildSuccess() : _buildRatingContent(),
      ),
    );
  }

  Widget _buildSuccess() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 56),
        SizedBox(height: 12),
        Text(
          'Thanks for your rating!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.navy,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star, color: AppColors.gold, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'Rate Your Driver',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How was your ride with ${widget.driverName}?',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.greyText,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Stars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _selectedStars = star),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedScale(
                  scale: _selectedStars >= star ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _selectedStars >= star ? Icons.star : Icons.star_border,
                    color: _selectedStars >= star
                        ? AppColors.gold
                        : const Color(0xFFCBD5E1),
                    size: 44,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        // Label
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _starLabel,
            key: ValueKey(_selectedStars),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _selectedStars > 0 ? AppColors.navy : AppColors.greyText,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_selectedStars == 0 || _isSubmitting) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.bgLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Submit Rating',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),

        const SizedBox(height: 10),

        // Skip
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.pop(context, false),
          child: const Text(
            'Skip for now',
            style: TextStyle(color: AppColors.greyText, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
