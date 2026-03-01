import 'package:workmanager/workmanager.dart';
import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/portfolio_calculator_service.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';
import 'package:sync_ledger/core/logger.dart';

/// Background task handler for daily portfolio updates
/// Runs at 4:30 PM (CSE market close time) each day
class BackgroundTaskHandler {
  static const String portfolioUpdateTaskName = 'portfolioUpdate';
  static const String portfolioUpdateTaskId = 'portfolio_update_daily';

  /// Initialize background task scheduling
  /// Call this once when the app starts
  static Future<void> initializeBackgroundTasks() async {
    try {
      AppLogger.d('BackgroundTaskHandler: Initializing background tasks');

      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for testing
      );

      // Schedule daily portfolio update at 4:30 PM (CSE close time)
      await Workmanager().registerPeriodicTask(
        portfolioUpdateTaskId,
        portfolioUpdateTaskName,
        frequency: const Duration(days: 1),
        initialDelay: _getInitialDelay(),
        constraints: Constraints(
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          networkType: NetworkType.connected,
        ),
        backoffPolicy: BackoffPolicy.exponential,
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );

      AppLogger.d('BackgroundTaskHandler: Portfolio update task scheduled');
    } catch (e) {
      AppLogger.e('BackgroundTaskHandler: Failed to initialize: $e');
    }
  }

  /// Cancel background tasks
  /// Call this if user disables stock analysis
  static Future<void> cancelBackgroundTasks() async {
    try {
      AppLogger.d('BackgroundTaskHandler: Cancelling background tasks');
      await Workmanager().cancelByUniqueName(portfolioUpdateTaskId);
      AppLogger.d('BackgroundTaskHandler: Background tasks cancelled');
    } catch (e) {
      AppLogger.e('BackgroundTaskHandler: Failed to cancel tasks: $e');
    }
  }

  /// Calculate initial delay to first run at 4:30 PM
  static Duration _getInitialDelay() {
    final now = DateTime.now();
    final targetTime = DateTime(now.year, now.month, now.day, 16, 30, 0); // 4:30 PM

    if (now.isBefore(targetTime)) {
      // Today hasn't hit 4:30 PM yet, run today
      return targetTime.difference(now);
    } else {
      // It's past 4:30 PM, run tomorrow
      final tomorrow = targetTime.add(const Duration(days: 1));
      return tomorrow.difference(now);
    }
  }
}

/// Main callback dispatcher for background tasks
/// This is called by the workmanager plugin
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      if (taskName == BackgroundTaskHandler.portfolioUpdateTaskName) {
        return await _executePortfolioUpdate();
      }
      return false;
    } catch (e) {
      AppLogger.e('callbackDispatcher: Task failed: $e');
      return false;
    }
  });
}

/// Execute the daily portfolio update task
/// This runs in an isolated context with fresh database connection
Future<bool> _executePortfolioUpdate() async {
  try {
    AppLogger.d('BackgroundTask: Starting portfolio update');

    // Initialize fresh database connection for this task
    final db = AppDatabase();

    try {
      // Get all profiles to update their portfolios
      final profiles = await db.select(db.profiles).get();

      if (profiles.isEmpty) {
        AppLogger.d('BackgroundTask: No profiles found to update');
        return true;
      }

      final cseService = CseScraperService();
      final calculatorService = PortfolioCalculatorService(
        db: db,
        cseService: cseService,
      );

      // Update portfolio for all profiles
      final profileIds = profiles.map((p) => p.id.toString()).toList();
      await calculatorService.updatePricesAndRecalculatePortfolio(profileIds);

      AppLogger.d('BackgroundTask: Updated portfolio for ${profileIds.length} profile(s)');

      AppLogger.d('BackgroundTask: Portfolio update completed successfully');
      return true;
    } finally {
      await db.close();
    }
  } catch (e) {
    AppLogger.e('BackgroundTask: Portfolio update failed: $e');
    return false;
  }
}
