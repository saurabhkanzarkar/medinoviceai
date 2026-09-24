import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:medinvoiceai/screens/auth_screen.dart';
import 'package:medinvoiceai/screens/main_screen.dart';
import 'package:medinvoiceai/services/background_task_service.dart';
import 'package:medinvoiceai/services/invoice_reminder_service.dart';
import 'package:medinvoiceai/services/hive_service.dart';
import 'package:medinvoiceai/services/local_notification_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();
  await Hive.initFlutter();

  await Hive.openBox('billsBox');
  await Hive.openBox('invoice_bills');
  await Hive.openBox('expiry_alert_state');
  await Hive.openBox('settings_box');
  await Hive.openBox('stock_box');
  await LocalNotificationService.initialize();
  await InvoiceReminderService.checkAndNotifyInvoiceReminder();
  await BackgroundTaskService.initializeAndScheduleDailyExpiryCheck();
  runApp(const PharmaBillApp());
}

class PharmaBillApp extends StatelessWidget {
  const PharmaBillApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaBill',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: HiveService.isLoggedIn
          ? const MainScreen()
          : (HiveService.hasRegisteredUser
                ? const LoginScreen()
                : const RegisterScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
