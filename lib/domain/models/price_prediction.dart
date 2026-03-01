import 'dart:math';

import 'package:sync_ledger/data/db/app_database.dart';
import 'package:sync_ledger/domain/services/cse_scraper_service.dart';

/// A single predicted price point.
class PricePrediction {
  final DateTime date;
  final double price;

  const PricePrediction({required this.date, required this.price});
}

/// Linear-regression extrapolation for CSE stock prices.
///
/// Fits y = a + bx on the most recent [lookbackDays] closing prices and
/// projects [forecastTradingDays] trading days (Mon–Fri) into the future.
/// Predictions are clamped to [0.5×min, 2×max] of the lookback window to
/// prevent runaway extrapolation.
class PricePredictor {
  static const int defaultLookbackDays = 60;
  static const int defaultForecastDays = 30;

  /// Returns an empty list when [history] has fewer than 5 data points.
  static List<PricePrediction> predict(
    List<StockPrice> history, {
    int forecastDays = defaultForecastDays,
    int lookbackDays = defaultLookbackDays,
  }) {
    if (history.length < 5) return [];

    // Use the most recent [lookbackDays] points.
    final recent = history.length > lookbackDays
        ? history.sublist(history.length - lookbackDays)
        : history;

    final prices = recent.map((p) => p.closePrice).toList();
    final n = prices.length;

    // Least-squares linear regression  y = a + b*x
    final xMean = (n - 1) / 2.0;
    final yMean = prices.fold(0.0, (s, v) => s + v) / n;

    double num = 0.0, den = 0.0;
    for (int i = 0; i < n; i++) {
      final dx = i - xMean;
      num += dx * (prices[i] - yMean);
      den += dx * dx;
    }

    final slope = den > 0 ? num / den : 0.0;
    final intercept = yMean - slope * xMean;

    // Clamp bounds: don't go below 50 % of min or above 200 % of max.
    final minPrice = prices.reduce(min) * 0.5;
    final maxPrice = prices.reduce(max) * 2.0;

    final lastDate =
        CseScraperService.yyyymmddToDate(recent.last.priceDate);

    final result = <PricePrediction>[];
    int dayOffset = 1;
    int count = 0;

    while (count < forecastDays) {
      final date = lastDate.add(Duration(days: dayOffset));
      dayOffset++;

      // CSE trades Mon–Fri only.
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        continue;
      }

      final x = n + count;
      final predicted =
          (intercept + slope * x).clamp(minPrice, maxPrice);

      result.add(PricePrediction(date: date, price: predicted));
      count++;
    }

    return result;
  }
}
