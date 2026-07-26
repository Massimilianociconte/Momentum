library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';

class InviteQrScannerScreen extends StatefulWidget {
  const InviteQrScannerScreen({super.key});

  @override
  State<InviteQrScannerScreen> createState() => _InviteQrScannerScreenState();
}

class _InviteQrScannerScreenState extends State<InviteQrScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _manual = TextEditingController();
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.barcodes.listen(_onCapture);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _subscription ??= _controller.barcodes.listen(_onCapture);
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_subscription?.cancel());
        _subscription = null;
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _manual.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onCapture(BarcodeCapture capture) {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value != null) _open(value);
  }

  void _open(String raw) {
    if (_handled) return;
    final secret = _secretFrom(raw);
    if (secret == null || secret.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QR Padelandia non valido.')));
      return;
    }
    _handled = true;
    unawaited(_controller.stop());
    context.pushReplacement('/invite/${Uri.encodeComponent(secret)}');
  }

  String? _secretFrom(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      if (uri.scheme == 'rallymate' && uri.host == 'invite') {
        return uri.pathSegments.firstOrNull;
      }
      final segments = uri.pathSegments;
      final inviteIndex = segments.indexOf('invite');
      if (uri.scheme == 'https' &&
          inviteIndex >= 0 &&
          inviteIndex + 1 < segments.length) {
        return segments[inviteIndex + 1];
      }
    }
    if (RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(trimmed.toUpperCase())) {
      return trimmed.toUpperCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scansiona invito'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
            tooltip: 'Torcia',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller),
                Center(
                  child: Container(
                    width: 238,
                    height: 238,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: RallyColors.lime, width: 3),
                    ),
                  ),
                ),
                const Positioned(
                  left: 24,
                  right: 24,
                  bottom: 26,
                  child: Text(
                    'Inquadra un QR Padelandia. Nessuna immagine viene salvata.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: RallyColors.night,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'Codice invito',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _open(_manual.text),
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Apri invito',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
