import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config.dart';
import 'l10n.dart';
import 'screens/delivery_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Am Geraet gespeicherte Einstellungen gehen vor; beim ersten Start gilt
  // das im Build hinterlegte Postfach.
  final settings = await TerminalSettings.load(
    defaultMailbox: AppConfig.mailFallback,
  );

  runApp(PostTerminalApp(
    settings: settings,
    locale: LocaleController(
      LocaleController.fromCode(AppConfig.defaultLanguage),
    ),
  ));
}

/// Farbwelt: kühles Schiefergrau als Grundton (Kühlhaus, Industrie),
/// ein einziger kräftiger Akzent für die Sendetaste, Orange nur für Kühlware.
class AppColors {
  static const ink = Color(0xFF16222E);
  static const inkSoft = Color(0xFF4A5A69);
  static const surface = Color(0xFFF2F5F6);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFD6DEE3);
  static const accent = Color(0xFF0E7C5A);
  static const accentDark = Color(0xFF0A5C43);
  static const alert = Color(0xFFC25E00);
  static const danger = Color(0xFFB3261E);
}

class PostTerminalApp extends StatelessWidget {
  final LocaleController locale;
  final TerminalSettings settings;

  const PostTerminalApp({
    super.key,
    required this.locale,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: locale,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'Frigemo Post',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.accent,
              primary: AppColors.accent,
              surface: AppColors.surface,
            ),
            scaffoldBackgroundColor: AppColors.surface,
            splashFactory: InkSparkle.splashFactory,
            textTheme: Typography.material2021().black.apply(
                  bodyColor: AppColors.ink,
                  displayColor: AppColors.ink,
                ),
          ),
          home: AppConfig.demoMode
              ? Banner(
                  message: 'DEMO',
                  location: BannerLocation.topStart,
                  color: AppColors.alert,
                  child: DeliveryScreen(locale: locale, settings: settings),
                )
              : DeliveryScreen(locale: locale, settings: settings),
        );
      },
    );
  }
}
