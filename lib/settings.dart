import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'providers.dart';
import 'Counter.dart';
import 'alarm_player.dart'; // AlarmPlayer'ı ekliyoruz

/// Ayarlar ekranı: Kullanıcı, Pomodoro, Kısa Mola, Uzun Mola sürelerini ve alarm sesini ayarlar.
/// Alarm sesleri seçenekleri eklenmiştir.
class SettingsScreen extends ConsumerStatefulWidget {
  final bool isTaskMode;
  const SettingsScreen({Key? key, this.isTaskMode = false}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int pomodoroDuration;
  late int shortBreakDuration;
  late int longBreakDuration;

  // Alarm sesi seçimi için:
  String selectedAlarm = "Alarm 1"; // Varsayılan değer ekledik
  final List<String> availableAlarms = [
    "Alarm 1",
    "Alarm 2",
    "Alarm 3",
    "Alarm 4",
    "Alarm 5"
  ];

  Box? settingsBox;

  @override
  void initState() {
    super.initState();
    final counterBox = Hive.box('counterBox');
    pomodoroDuration =
    counterBox.get('pomodoroDuration', defaultValue: 25 * 60) as int;
    shortBreakDuration =
    counterBox.get('shortBreakDuration', defaultValue: 5 * 60) as int;
    longBreakDuration =
    counterBox.get('longBreakDuration', defaultValue: 15 * 60) as int;
    _loadAlarmSetting();
  }

  Future<void> _loadAlarmSetting() async {
    if (!Hive.isBoxOpen('settingsBox')) {
      settingsBox = await Hive.openBox('settingsBox');
    } else {
      settingsBox = Hive.box('settingsBox');
    }
    setState(() {
      selectedAlarm =
          settingsBox!.get('selectedAlarm', defaultValue: availableAlarms.first);
    });
  }

  Future<void> _saveAlarmSetting() async {
    if (settingsBox != null && settingsBox!.isOpen) {
      await settingsBox!.put('selectedAlarm', selectedAlarm);
    }
  }

  void updateDurations() {
    if (widget.isTaskMode) return;
    final counterNotifier = ref.read(counterProvider.notifier);
    counterNotifier.updateCustomDurations(
      pomodoro: pomodoroDuration,
      shortBreak: shortBreakDuration,
      longBreak: longBreakDuration,
    );
    _saveAlarmSetting();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2A38) : const Color(0xFFAEC6CF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.timeSettings,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                )),
            const SizedBox(height: 16),
            _buildDurationButton("Pomodoro", pomodoroDuration, (newValue) {
              pomodoroDuration = newValue;
            }, isDark),
            const SizedBox(height: 16),
            _buildDurationButton(l10n.shortBreak, shortBreakDuration, (newValue) {
              shortBreakDuration = newValue;
            }, isDark),
            const SizedBox(height: 16),
            _buildDurationButton(l10n.longBreak, longBreakDuration, (newValue) {
              longBreakDuration = newValue;
            }, isDark),
            const SizedBox(height: 24),
            // Alarm sesi seçimi ve kontrolü
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.play_arrow, 
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        AlarmPlayer().playAlarm(selectedAlarm);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.stop,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        AlarmPlayer().stopAlarm(selectedAlarm);
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.alarmSound,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black
                      ),
                    ),
                  ],
                ),
                DropdownButton<String>(
                  value: selectedAlarm,
                  dropdownColor: isDark ? Colors.black : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16
                  ),
                  icon: Icon(Icons.arrow_drop_down,
                      color: isDark ? Colors.white : Colors.black),
                  items: availableAlarms
                      .map((alarm) => DropdownMenuItem<String>(
                            value: alarm,
                            child: Text(alarm),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedAlarm = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Dil seçimi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.language,
                        color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      l10n.language,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black
                      ),
                    ),
                  ],
                ),
                DropdownButton<String>(
                  value: ref.watch(localeProvider).locale.languageCode,
                  dropdownColor: isDark ? Colors.black : Colors.white,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16
                  ),
                  icon: Icon(Icons.arrow_drop_down,
                      color: isDark ? Colors.white : Colors.black),
                  items: [
                    DropdownMenuItem(
                      value: 'tr',
                      child: Text('Türkçe',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black
                          )),
                    ),
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black
                          )),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(localeProvider.notifier).setLocale(value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.isTaskMode ? null : updateDurations,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isTaskMode
                    ? Colors.grey
                    : isDark
                    ? const Color(0xFF648FA8)
                    : const Color(0xFFB5E7FF),
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(l10n.apply,
                  style: TextStyle(
                      fontSize: 20, color: isDark ? Colors.white : Colors.black)),
            ),
            const SizedBox(height: 24),
            // Telif hakkı yazısı
            Text(
              "© 2025 Alper Serin",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Eski AlertDialog tabanlı süre seçici yerine,
  /// artık CupertinoPicker kullanılan modal bottom sheet'i çağırıyoruz.
  Future<int?> _showTimePickerDialog(
      BuildContext context, int currentDuration) {
    int initialMinute = currentDuration ~/ 60;
    int initialSecond = currentDuration % 60;
    return showTimePickerDialog(context, initialMinute, initialSecond);
  }

  Widget _buildDurationButton(String label, int duration, Function(int) onUpdate,
      bool isDark) {
    return OutlinedButton(
      onPressed: widget.isTaskMode
          ? null
          : () async {
        int? newDuration =
        await _showTimePickerDialog(context, duration);
        if (newDuration != null) {
          setState(() {
            onUpdate(newDuration);
          });
        }
      },
      style: OutlinedButton.styleFrom(
        backgroundColor:
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      child: Text(
        "$label: ${duration ~/ 60} ${AppLocalizations.of(context)!.minutes} ${duration % 60} ${AppLocalizations.of(context)!.seconds}",
        style: TextStyle(fontSize: 18, color: isDark ? Colors.white : Colors.black),
      ),
    );
  }
}

/// Aşağıdaki fonksiyon, tasks.dart içerisindeki showTimePickerDialog fonksiyonunun aynısıdır.
/// Tema bilgisine göre renkler ayarlanmakta ve dakika-saniye seçimi için iki adet CupertinoPicker kullanılmaktadır.
Future<int?> showTimePickerDialog(
    BuildContext context, int initialMinute, int initialSecond) {
  int selectedMinute = initialMinute;
  int selectedSecond = initialSecond;
  final theme = Theme.of(context);

  final backgroundColor = theme.brightness == Brightness.dark
      ? const Color(0xFF1C2A38)
      : const Color(0xFFAEC6CF);
  final pickerTextColor = theme.brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF2C3E50);
  final buttonTextColor = theme.brightness == Brightness.dark
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF2C3E50);
  final buttonBgColor = theme.brightness == Brightness.dark
      ? const Color(0xFF7FB3D5)
      : const Color(0xFFB5E7FF);

  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return RepaintBoundary(
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Süreyi Ayarla",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: pickerTextColor,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(
                      child: RepaintBoundary(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(initialItem: initialMinute),
                          onSelectedItemChanged: (int index) {
                            selectedMinute = index;
                          },
                          children: List.generate(60, (index) {
                            return Center(
                              child: Text(
                                "$index dk",
                                style: TextStyle(fontSize: 20, color: pickerTextColor),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(initialItem: initialSecond),
                          onSelectedItemChanged: (int index) {
                            selectedSecond = index;
                          },
                          children: List.generate(60, (index) {
                            return Center(
                              child: Text(
                                "$index sn",
                                style: TextStyle(fontSize: 20, color: pickerTextColor),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBgColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop(selectedMinute * 60 + selectedSecond);
                },
                child: Text(
                  "Uygula",
                  style: TextStyle(fontSize: 20, color: buttonTextColor),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
