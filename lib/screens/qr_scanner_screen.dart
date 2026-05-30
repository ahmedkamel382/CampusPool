import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../services/ride_service.dart';

class QrScannerScreen extends StatefulWidget {
  final String rideId;
  final String passengerId;
  final String passengerName;

  const QrScannerScreen({
    super.key,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;
  bool _hasSucceeded = false;
  String? _errorMessage;
  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _hasSucceeded) return;

    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null) return;

    // Expected format: campuspool:{rideId}:{passengerId}
    final parts = rawValue.split(':');
    if (parts.length != 3 || parts[0] != 'campuspool') {
      setState(() => _errorMessage = 'Invalid QR code. Not a CampusPool ticket.');
      return;
    }

    final scannedRideId = parts[1];
    final scannedPassengerId = parts[2];

    if (scannedRideId != widget.rideId) {
      setState(() => _errorMessage = 'This ticket is for a different ride.');
      return;
    }

    if (scannedPassengerId != widget.passengerId) {
      setState(() => _errorMessage =
      'This ticket belongs to a different rider. Make sure ${widget.passengerName} scans their own code.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    await _controller.stop();

    try {
      await RideService().scanPassengerQR(
        rideId: widget.rideId,
        passengerId: widget.passengerId,
      );

      if (!mounted) return;

      setState(() {
        _hasSucceeded = true;
        _isProcessing = false;
      });

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Rider QR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.passengerName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // --- APP UPDATE: RepaintBoundary isolates Camera Feed ---
          RepaintBoundary(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            ),
          ),

          // --- APP UPDATE: RepaintBoundary isolates Custom Overlay ---
          RepaintBoundary(
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ScanOverlayPainter(),
            ),
          ),

          // Scan frame corners
          const Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                children: [
                  _Corner(top: 0, left: 0, alignment: Alignment.topLeft),
                  _Corner(top: 0, right: 0, alignment: Alignment.topRight),
                  _Corner(bottom: 0, left: 0, alignment: Alignment.bottomLeft),
                  _Corner(bottom: 0, right: 0, alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // Status area at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasSucceeded) ...[
                    const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 56),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.passengerName} is on board!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else if (_isProcessing) ...[
                    const CircularProgressIndicator(color: AppColors.gold),
                    const SizedBox(height: 12),
                    const Text(
                      'Verifying...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ] else ...[
                    Text(
                      'Point camera at ${widget.passengerName}\'s QR code',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha:0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _errorMessage = null),
                              child: const Text('Dismiss',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Darkened overlay with a transparent square cut out
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    const cutSize = 240.0;
    final left = (size.width - cutSize) / 2;
    final top = (size.height - cutSize) / 2;
    final cutRect = Rect.fromLTWH(left, top, cutSize, cutSize);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(cutRect, const Radius.circular(12))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// Corner bracket widget
class _Corner extends StatelessWidget {
  final double? top, bottom, left, right;
  final Alignment alignment;

  const _Corner({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top != null
                ? const BorderSide(color: AppColors.gold, width: 3)
                : BorderSide.none,
            bottom: bottom != null
                ? const BorderSide(color: AppColors.gold, width: 3)
                : BorderSide.none,
            left: left != null
                ? const BorderSide(color: AppColors.gold, width: 3)
                : BorderSide.none,
            right: right != null
                ? const BorderSide(color: AppColors.gold, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}