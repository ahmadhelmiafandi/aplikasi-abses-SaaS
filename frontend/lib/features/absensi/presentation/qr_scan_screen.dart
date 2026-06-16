import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/translations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/location_service.dart';
import 'absensi_screen.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _cameraCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  bool _done = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  @override
  void dispose() {
    _cameraCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _processing = true);
    await _cameraCtrl.stop();

    try {
      // Ambil GPS — pakai showRationaleAndRequest jika belum ada izin
      // (fix Safari/iOS: Geolocation harus dipanggil dalam scope user gesture)
      LocationResult locationResult;
      if (await LocationService.shouldShowRationale()) {
        if (!mounted) return;
        locationResult = await LocationService.showRationaleAndRequest(
            context, lang: ref.read(langProvider));
      } else {
        locationResult = await LocationService.requestAndGet();
      }

      if (locationResult is! LocationSuccess) {
        if (mounted) {
          await LocationService.showLocationErrorDialog(
              context, locationResult,
              lang: ref.read(langProvider));
        }
        _showResult(false, Tr.get('location_required', ref.read(langProvider)));
        return;
      }

      final pos = locationResult.position;

      // Kirim ke backend
      await DioClient().dio.post('/absensi/scan-qr', data: {
        'qr_data':      barcode!.rawValue,
        'lat_karyawan': pos.latitude,
        'lng_karyawan': pos.longitude,
      });

      // Invalidate status hari ini
      ref.invalidate(todayStatusProvider);
      _showResult(true, Tr.get('check_in_success', ref.read(langProvider)));
    } on DioException catch (e) {
      _showResult(
          false, e.response?.data?['message'] ?? Tr.get('error', ref.read(langProvider)));
    } catch (_) {
      _showResult(false, Tr.get('error', ref.read(langProvider)));
    }
  }

  void _showResult(bool success, String message) {
    if (!mounted) return;
    setState(() {
      _processing    = false;
      _done          = true;
      _resultSuccess = success;
      _resultMessage = message;
    });
  }

  void _retry() {
    setState(() {
      _done          = false;
      _processing    = false;
      _resultMessage = null;
    });
    _cameraCtrl.start();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(Tr.get('scan_qr', lang),
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _cameraCtrl.toggleTorch(),
            tooltip: lang == 'id' ? 'Flash' : 'Flash',
          ),
        ],
      ),
      body: _done ? _buildResult() : _buildScanner(lang),
    );
  }

  // ── Scanner view ──────────────────────────────────────────────────────────
  Widget _buildScanner(String lang) {
    return Stack(
      children: [
        // Kamera
        MobileScanner(
          controller: _cameraCtrl,
          onDetect: _onDetect,
        ),

        // Overlay gelap + target frame
        _ScannerOverlay(),

        // Label bawah
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (_processing)
                const CircularProgressIndicator(color: AppColors.primary)
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    lang == 'id' ? 'Arahkan kamera ke QR Code' : 'Point camera at QR Code',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Result view ───────────────────────────────────────────────────────────
  Widget _buildResult() {
    final lang = ref.read(langProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_resultSuccess ? AppColors.success : AppColors.danger)
                    .withOpacity(0.15),
              ),
              child: Icon(
                _resultSuccess ? Icons.check_circle : Icons.cancel,
                color: _resultSuccess ? AppColors.success : AppColors.danger,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _resultSuccess
                  ? Tr.get('saved_success', lang).replaceAll(' ✓', '')
                  : Tr.get('error', lang),
              style: TextStyle(
                color: _resultSuccess ? AppColors.success : AppColors.danger,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _resultMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 40),
            if (_resultSuccess)
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_outlined),
                label: Text(lang == 'id' ? 'Kembali ke Beranda' : 'Back to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(lang == 'id' ? 'Scan Ulang' : 'Scan Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  minimumSize: const Size(200, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(Tr.get('cancel', lang)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Scanner Overlay ───────────────────────────────────────────────────────────
class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final frameS = size.width * 0.65;
    final frameX = (size.width - frameS) / 2;
    final frameY = (size.height - frameS) / 2 - 40;

    return CustomPaint(
      size: Size(size.width, size.height),
      painter: _OverlayPainter(
          frameRect: Rect.fromLTWH(frameX, frameY, frameS, frameS)),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect frameRect;
  _OverlayPainter({required this.frameRect});

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // Lapisan gelap
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(12)), clearPaint);
    canvas.restore();

    // Sudut-sudut frame
    const cornerLen = 24.0;
    const cornerW   = 3.5;
    final cornerPaint = Paint()
      ..color  = AppColors.primary
      ..strokeWidth = cornerW
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // TL
    canvas.drawLine(frameRect.topLeft, frameRect.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.topLeft, frameRect.topLeft + const Offset(0, cornerLen), cornerPaint);
    // TR
    canvas.drawLine(frameRect.topRight, frameRect.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.topRight, frameRect.topRight + const Offset(0, cornerLen), cornerPaint);
    // BL
    canvas.drawLine(frameRect.bottomLeft, frameRect.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.bottomLeft, frameRect.bottomLeft + const Offset(0, -cornerLen), cornerPaint);
    // BR
    canvas.drawLine(frameRect.bottomRight, frameRect.bottomRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(frameRect.bottomRight, frameRect.bottomRight + const Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
