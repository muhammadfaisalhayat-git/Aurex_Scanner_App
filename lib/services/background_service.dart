import 'package:workmanager/workmanager.dart';
import 'database_service.dart';
import 'notification_service.dart';
import '../utils/date_utils.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final db = DatabaseService();
    final products = await db.getProducts();
    final notificationService = NotificationService();
    
    int expiredCount = 0;
    int nearExpiryCount = 0;

    for (var product in products) {
      if (product.expDate != null) {
        final days = AppDateUtils.calculateRemainingDays(product.expDate);
        if (days < 0) {
          expiredCount++;
        } else if (days <= 30) {
          nearExpiryCount++;
        }
      }
    }

    if (expiredCount > 0) {
      await notificationService.showNotification(
        id: 100,
        title: "Expired Products Alert",
        body: "You have $expiredCount items that have already expired.",
      );
    }

    if (nearExpiryCount > 0) {
      await notificationService.showNotification(
        id: 101,
        title: "Near Expiry Alert",
        body: "$nearExpiryCount items are expiring within 30 days.",
      );
    }

    return Future.value(true);
  });
}

class BackgroundService {
  static void init() {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // Schedule periodic check every 24 hours
    Workmanager().registerPeriodicTask(
      "expiry_check_task",
      "expiryCheck",
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.notRequired, // Fixed: Corrected from not_required
        requiresBatteryNotLow: true,
      ),
    );
  }

  // Helper to trigger immediate check for testing
  static void triggerImmediateCheck() {
    Workmanager().registerOneOffTask(
      "immediate_expiry_check",
      "expiryCheck",
    );
  }
}
