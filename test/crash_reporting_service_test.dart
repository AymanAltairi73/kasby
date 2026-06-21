import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/services/crash_reporting/crash_error_category.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';

void main() {
  group('CrashReportingService', () {
    test('isCollectionEnabled is false in debug/test mode', () {
      expect(CrashReportingService.isCollectionEnabled, isFalse);
    });

    test('balanceRange buckets values without exposing exact amounts', () {
      expect(CrashReportingService.balanceRange(null), 'unknown');
      expect(CrashReportingService.balanceRange(50), '0-100');
      expect(CrashReportingService.balanceRange(500), '100-1k');
      expect(CrashReportingService.balanceRange(5000), '1k-10k');
      expect(CrashReportingService.balanceRange(50000), '10k-100k');
      expect(CrashReportingService.balanceRange(500000), '100k+');
    });

    test('categoryFromFeature maps feature names to categories', () {
      expect(
        CrashReportingService.categoryFromFeature('Authentication'),
        CrashErrorCategory.authentication,
      );
      expect(
        CrashReportingService.categoryFromFeature('WalletController'),
        CrashErrorCategory.wallet,
      );
      expect(
        CrashReportingService.categoryFromFeature('Investment'),
        CrashErrorCategory.investments,
      );
    });

    test('recordError does not throw when Crashlytics is not initialized', () async {
      await expectLater(
        CrashReportingService.recordError(
          Exception('test'),
          StackTrace.current,
          reason: 'unit_test',
          category: CrashErrorCategory.unknown,
        ),
        completes,
      );
    });

    test('recordSupabaseError does not throw for PostgrestException shape', () async {
      await expectLater(
        CrashReportingService.recordSupabaseError(
          Exception('simulated postgrest failure'),
          rpcName: 'create_investment',
          tableName: 'investments',
        ),
        completes,
      );
    });

    test('log and setCustomKey complete safely in debug mode', () async {
      await expectLater(CrashReportingService.log('Test breadcrumb'), completes);
      await expectLater(
        CrashReportingService.setCustomKey('screen_name', 'TestScreen'),
        completes,
      );
    });
  });
}
