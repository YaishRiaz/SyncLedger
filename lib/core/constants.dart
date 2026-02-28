abstract final class AppConstants {
  static const appName = 'SyncLedger';
  static const defaultCurrency = 'LKR';
  static const transferMatchWindowHours = 48;
  static const transferFeeAmount = 25.0;
  static const syncServerDefaultPort = 8742;
  static const apkDownloadUrl = 'https://drive.google.com/file/d/1-aeQIHHJFf2evpfmOdnNNTtUq-OVVZnA/view?usp=sharing';

  static const knownSmsSenders = {
    'HNB',
    'NDB',
    'CDS',
    'BOC',
    'HSBC',
    'NTB',
    'COMBANK',
    'COMMERCIAL',
    'SEYLAN',
    'SAMPATH',
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
  static const familySyncEnabled = 'family_sync_enabled';
}
