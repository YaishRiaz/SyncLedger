import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sync_ledger/presentation/providers/sync_providers.dart';

class PairDeviceScreen extends ConsumerStatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  ConsumerState<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends ConsumerState<PairDeviceScreen> {
  bool _isCreator = true;
  String? _qrData;
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Pairing')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Create Group')),
                ButtonSegment(value: false, label: Text('Join Group')),
              ],
              selected: {_isCreator},
              onSelectionChanged: (s) =>
                  setState(() => _isCreator = s.first),
            ),
            const SizedBox(height: 24),
            if (_isCreator) ...[
              Text(
                'Show this QR code to the other device:',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (_qrData == null)
                Center(
                  child: FilledButton(
                    onPressed: () async {
                      final data = await ref
                          .read(syncStateProvider.notifier)
                          .createPairingQr();
                      setState(() => _qrData = data);
                    },
                    child: const Text('Generate QR Code'),
                  ),
                )
              else
                Center(
                  child: QrImageView(
                    data: _qrData!,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
            ] else ...[
              Text(
                'Scan the QR code from the other device:',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (!_scanning)
                Center(
                  child: FilledButton(
                    onPressed: () => setState(() => _scanning = true),
                    child: const Text('Start Scanning'),
                  ),
                )
              else
                SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: MobileScanner(
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null) {
                            setState(() => _scanning = false);
                            _joinGroup(code);
                          }
                        }
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(String qrPayload) async {
    final success =
        await ref.read(syncStateProvider.notifier).joinWithQr(qrPayload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(success ? 'Paired successfully!' : 'Pairing failed'),
        ),
      );
      if (success) Navigator.of(context).pop();
    }
  }
}
