# SyncLedger - Complete Implementation Guide

Due to the extensive changes required, here's the complete list of files that need updates and the exact changes for each. Implement these in order:

## Phase 1: Core Fixes (Priority 1)

### 1. Add Profile Provider
**File:** `lib/presentation/providers/app_providers.dart`
**Add after `debugModeProvider`:**
```dart
import 'package:uuid/uuid.dart';

final activeProfileIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  String? profileId = prefs.getString(PrefKeys.profileId);
  if (profileId == null) {
    profileId = const Uuid().v4();
    await prefs.setString(PrefKeys.profileId, profileId);
  }
  return profileId;
});
```

### 2. Fix SMS Providers profileId
**File:** `lib/presentation/providers/sms_providers.dart`
**Line 72-76:** Change to:
```dart
final profileId = await _ref.read(activeProfileIdProvider.future);
final result = await service.ingestSms(msg, profileId: profileId);
```

**Line 102-106:** Change to:
```dart
final profileId = await _ref.read(activeProfileIdProvider.future);
await service.ingestSms(msg, profileId: profileId);
```

### 3. Auto-Start SMS Listener
**New File:** `lib/domain/services/auto_start_service.dart`
```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_ledger/core/constants.dart';
import 'package:sync_ledger/data/sms/sms_plugin.dart';
import 'package:sync_ledger/core/logger.dart';

class AutoStartService {
  static Future<void> initializeOnAppStart() async {
    final prefs = await SharedPreferences.getInstance();
    final autoStartEnabled = prefs.getBool('sms_auto_start') ?? true;
    
    if (autoStartEnabled) {
      final granted = await SmsPlugin.requestSmsPermission();
      if (granted) {
        await SmsPlugin.startSmsListener();
        AppLogger.i('SMS listener auto-started');
      }
    }
  }
}
```

**Update:** `lib/main.dart`
```dart
import 'package:sync_ledger/domain/services/auto_start_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  
  // Auto-start SMS listener
  await AutoStartService.initializeOnAppStart();
  
  runApp(const ProviderScope(child: SyncLedgerApp()));
}
```

## Phase 2: Stock Holdings Filter

### 4. Filter Holdings by qty > 0
**File:** `lib/data/db/app_database.dart`
**Update `getAllPositions` method:**
```dart
Future<List<Position>> getAllPositions() async {
  return (select(positions)
        ..where((t) => t.qty.isBiggerThanValue(0))
        ..orderBy([(t) => OrderingTerm.desc(t.qty)]))
      .get();
}
```

### 5. Improve Stock Activity Date Display
**File:** `lib/presentation/screens/stocks/stocks_screen.dart`
**Replace the activity ListTile subtitle with:**
```dart
subtitle: Container(
  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
  decoration: BoxDecoration(
    color: theme.colorScheme.surfaceVariant,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    DateFormat('dd MMM yyyy').format(
      DateTime.fromMillisecondsSinceEpoch(ev.occurredAtMs),
    ),
    style: theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
  ),
),
```

## Phase 3: Analytics Improvements

### 6. Enhanced Pie Chart with Percentages
**New File:** `lib/presentation/widgets/enhanced_pie_chart.dart`
```dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class EnhancedPieChart extends StatelessWidget {
  const EnhancedPieChart({
    super.key,
    required this.data,
    required this.colors,
  });

  final Map<String, double> data;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (a, b) => a + b);
    
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: data.entries.map((e) {
                final idx = data.keys.toList().indexOf(e.key);
                final percentage = (e.value / total * 100).toStringAsFixed(1);
                return PieChartSectionData(
                  value: e.value,
                  title: '$percentage%',
                  color: colors[idx % colors.length],
                  radius: 60,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.entries.map((e) {
              final idx = data.keys.toList().indexOf(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[idx % colors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
```

### 7. Cashflow Chart with Legend
**File:** `lib/presentation/screens/analytics/analytics_screen.dart`
**Replace `BarChart` section with:**
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.green, label: 'Income'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.red, label: 'Expense'),
      ],
    ),
    const SizedBox(height: 12),
    SizedBox(
      height: 200,
      child: BarChart(...existing code...),
    ),
  ],
)

// Add at bottom of file:
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
```

**Replace pie chart section:**
```dart
EnhancedPieChart(
  data: cats,
  colors: [
    colorScheme.primary,
    colorScheme.secondary,
    colorScheme.tertiary,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ],
),
```

## Phase 4: Biometric Authentication

### 8. Biometric Service
**New File:** `lib/domain/services/biometric_service.dart`
```dart
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock SyncLedger',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(PrefKeys.appLockEnabled) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.appLockEnabled, enabled);
  }
}
```

### 9. Update Settings Screen
**File:** `lib/presentation/screens/settings/settings_screen.dart`
**Replace the "App Lock" SwitchListTile:**
```dart
FutureBuilder<bool>(
  future: BiometricService.canCheckBiometrics(),
  builder: (context, snapshot) {
    final canUseBiometrics = snapshot.data ?? false;
    return SwitchListTile(
      title: const Text('App Lock'),
      subtitle: Text(
        canUseBiometrics
            ? 'Require fingerprint/face to open'
            : 'Biometrics not available on this device',
      ),
      value: ref.watch(appLockEnabledProvider),
      onChanged: canUseBiometrics
          ? (v) async {
              await BiometricService.setEnabled(v);
              ref.invalidate(appLockEnabledProvider);
            }
          : null,
    );
  },
),
```

**Add provider in app_providers.dart:**
```dart
final appLockEnabledProvider = FutureProvider<bool>((ref) async {
  return BiometricService.isEnabled();
});
```

## Phase 5: Family QR Code with APK Download

### 10. Update Constants
**File:** `lib/core/constants.dart`
**Add:**
```dart
static const apkDownloadUrl = 'https://your-server.com/sync_ledger.apk';
```

### 11. Enhanced QR Generation
**File:** `lib/presentation/providers/sync_providers.dart`
**Update `createPairingQr` method:**
```dart
return jsonEncode({
  'serverUrl': serverUrl,
  'groupId': groupId,
  'pairingToken': pairingToken,
  'deviceId': deviceId,
  'apkUrl': AppConstants.apkDownloadUrl,
  'type': 'syncledger_pairing',
});
```

## Phase 6: Android Native Changes

### 12. Boot Receiver for Auto-Start
**New File:** `android/app/src/main/kotlin/com/syncledger/app/BootReceiver.kt`
```kotlin
package com.syncledger.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Restart SMS listener service
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val autoStart = prefs.getBoolean("flutter.sms_auto_start", true)
            if (autoStart) {
                // Start background service or WorkManager job
            }
        }
    }
}
```

**Update AndroidManifest.xml - Add:**
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<receiver
    android:name=".BootReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

## Phase 7: Build & Deployment

### 13. Build APK
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 14. Upload APK
Upload to:
- Google Drive (get shareable link)
- Dropbox
- Your own server
- GitHub Releases

Update `APK_DOWNLOAD_URL` in constants.dart with the download link.

### 15. Test QR Code Flow
1. Generate QR on Phone A
2. Scan with Phone B (no app) → should prompt to download
3. Install APK on Phone B
4. Open app, scan QR again → joins family

## Files to Remove Before Zipping

Delete these unnecessary files:
```
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
.metadata
.idea/
.vscode/
*.iml
android/.gradle/
android/local.properties
android/gradlew
android/gradlew.bat
ios/
linux/
macos/
web/
windows/
test/
server/node_modules/
server/data/
```

## Final Checklist

- [ ] All parser patterns added (HNB salary, adjustment, "You received")
- [ ] Deduplication with time window implemented
- [ ] Stock holdings filter qty > 0
- [ ] Stock activity dates larger & readable
- [ ] Enhanced pie chart with percentages
- [ ] Cashflow chart with legend
- [ ] Biometric authentication working
- [ ] Auto-start SMS listener on app launch
- [ ] Boot receiver for phone restart
- [ ] QR code includes APK download link
- [ ] APK built and uploaded
- [ ] Constants updated with APK URL
- [ ] Unnecessary files removed
- [ ] Ready to zip and send

