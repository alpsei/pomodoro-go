import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'notification_service.dart';
import 'providers.dart';
import 'HomeScreen.dart';

void main() async {
  // Hive'ı başlat
  await Hive.initFlutter();
  // Hive kutularını aç
  await Hive.openBox('themeBox');
  await Hive.openBox('counterBox');
  await Hive.openBox('homeScreenBox');
  await Hive.openBox('settingsBox');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tema durumunu izliyoruz
    final themeState = ref.watch(themeProvider);
    final themeData = themeState.isDarkMode
        ? ref.read(themeProvider.notifier).darkTheme
        : ref.read(themeProvider.notifier).lightTheme;

    // HomeScreenBox verisini okuyalım (ilk açılış kontrolü vs.)
    final homeScreenBox = Hive.box('homeScreenBox');
    final isHomeScreenFirstTime = homeScreenBox.get('isFirstTime', defaultValue: true);

    // Dil durumunu izliyoruz
    final localeState = ref.watch(localeProvider);

    debugPrint('Theme isDarkMode: ${themeState.isDarkMode}');
    debugPrint('HomeScreen isFirstTime: $isHomeScreenFirstTime');

    return AnimatedTheme(
      data: themeData.copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlaywriteGBS'),
      ),
      duration: const Duration(milliseconds: 300),
      child: MaterialApp(
        title: 'Pomodoro Go',
        theme: themeData.copyWith(
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'PlaywriteGBS'),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        locale: localeState.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr'),
          Locale('en'),
        ],
      ),
    );
  }
}
