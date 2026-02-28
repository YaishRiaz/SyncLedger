import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late TextEditingController _serverUrlController;
  String? _savedServerUrl;
  bool _expandServerConfig = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _loadServerUrl();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('sync_server_url') ?? 'http://127.0.0.1:8742';
    if (mounted) {
      setState(() {
        _savedServerUrl = url;
        _serverUrlController.text = url;
      });
    }
  }

  Future<void> _saveServerUrl() async {
    final input = _serverUrlController.text.trim();
    if (input.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a server URL')),
        );
      }
      return;
    }

    try {
      // Save directly to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final (isValid, normalizedUrl) = _normalizeServerUrl(input);

      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid server URL format')),
          );
        }
        return;
      }

      await prefs.setString('sync_server_url', normalizedUrl);

      // Reload the URL from SharedPreferences
      await _loadServerUrl();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server URL saved: $normalizedUrl')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving server URL: $e')),
        );
      }
    }
  }

  /// Normalize server URL: add http:// prefix and port if needed
  (bool, String) _normalizeServerUrl(String input) {
    if (input.trim().isEmpty) {
      return (false, '');
    }

    String url = input.trim();

    // Add http:// if no protocol specified
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Check if port is specified
    if (!url.contains(':') || url.lastIndexOf(':') <= url.lastIndexOf('/')) {
      // No port found, add default port
      if (url.endsWith('/')) {
        url = '${url}8742';
      } else {
        url = '$url:8742';
      }
    }

    return (true, url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Pairing')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Server URL Configuration Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Server Configuration',
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (_savedServerUrl != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Current: $_savedServerUrl',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _expandServerConfig
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                            onPressed: () =>
                                setState(() =>
                                    _expandServerConfig = !_expandServerConfig),
                          ),
                        ],
                      ),
                      if (_expandServerConfig) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            hintText: 'e.g., 192.168.1.100 or 192.168.1.100:8742',
                            prefixIcon: const Icon(Icons.storage),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _saveServerUrl,
                          child: const Text('Save Server URL'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                        try {
                          final data = await ref
                              .read(syncStateProvider.notifier)
                              .createPairingQr();
                          setState(() => _qrData = data);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('QR code generated successfully!'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to generate QR: $e'),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
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
      ),
    );
  }

  Future<void> _joinGroup(String qrPayload) async {
    try {
      final success =
          await ref.read(syncStateProvider.notifier).joinWithQr(qrPayload);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paired successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pairing failed - check server connection'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pairing error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
