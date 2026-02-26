abstract final class AppConstants {
  static const appName = 'SyncLedger';
  static const defaultCurrency = 'LKR';
  static const transferMatchWindowHours = 48;
  static const transferFeeAmount = 25.0;
  static const syncServerDefaultPort = 8742;

  static const knownSmsSenders = {
    'HNB',
    'NDB ALERT',
    'NDB+ALERT',
    'CDS-Alerts',
    'CDS+Alerts',
  };
}

abstract final class PrefKeys {
  static const hasOnboarded = 'has_onboarded';
  static const debugMode = 'debug_mode';
  static const appLockEnabled = 'app_lock_enabled';
  static const profileId = 'profile_id';
  static const deviceId = 'device_id';
  static const displayName = 'display_name';
  static const familyGroupId = 'family_group_id';
  static const syncServerUrl = 'sync_server_url';
  static const lastSyncSeq = 'last_sync_seq';
  static const profiles = 'profiles';
}
