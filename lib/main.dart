import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/startup/app_startup.dart';
import 'core/startup/startup_error_screen.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // التهيئة لا ترمي أبداً: تُعيد سبب الفشل ليُعرض للمستخدم بدل أن تمنع
  // `runApp` من التنفيذ فتظهر صفحة بيضاء صامتة. التفصيل في `AppStartup`.
  final startupError = await AppStartup.initializeFirebase();

  await EasyLocalization.ensureInitialized();
  try {
    await Hive.initFlutter();
  } catch (e) {
    Hive.init(
      '.',
    ); // Fallback for Windows if documents directory is unavailable
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
        child: StuStepApp(startupError: startupError),
      ),
    ),
  );
}

class StuStepApp extends StatelessWidget {
  /// سبب فشل التهيئة، أو `null` إن نجحت — وهو الحالة الطبيعية.
  final String? startupError;

  const StuStepApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    final error = startupError;

    return MaterialApp(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: context.watch<ThemeProvider>().themeMode,
      // عند الفشل لا نمضي إلى شاشة البداية: هي تستدعي `FirebaseAuth` بعد
      // ثلاث ثوانٍ ونصف، فيتحوّل العطل من بياض فوري إلى انهيار متأخر.
      home: error == null
          ? const SplashScreen()
          : StartupErrorScreen(
              details: error,
              onRetry: AppStartup.initializeFirebase,
              onReady: (_) => const SplashScreen(),
            ),
    );
  }
}
