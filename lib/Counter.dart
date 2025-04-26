import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'tasks.dart';
import 'alarm_player.dart';
import 'notification_service.dart';

String getTurkishDayName(DateTime date) {
  switch (date.weekday) {
    case DateTime.monday:
      return "Pazartesi";
    case DateTime.tuesday:
      return "Salı";
    case DateTime.wednesday:
      return "Çarşamba";
    case DateTime.thursday:
      return "Perşembe";
    case DateTime.friday:
      return "Cuma";
    case DateTime.saturday:
      return "Cumartesi";
    case DateTime.sunday:
      return "Pazar";
    default:
      return "";
  }
}

class CounterState {
  final int remainingTime;
  final bool isRunning;
  final String selectedTab;
  final bool isLoading;

  String get formattedTime {
    final minutes = (remainingTime ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingTime % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  int get totalTime {
    switch (selectedTab) {
      case 'shortBreak':
        return 5 * 60;
      case 'longBreak':
        return 15 * 60;
      default:
        return 25 * 60;
    }
  }

  const CounterState({
    required this.remainingTime,
    required this.isRunning,
    required this.selectedTab,
    this.isLoading = false,
  });

  CounterState copyWith({
    int? remainingTime,
    bool? isRunning,
    String? selectedTab,
    bool? isLoading,
  }) {
    return CounterState(
      remainingTime: remainingTime ?? this.remainingTime,
      isRunning: isRunning ?? this.isRunning,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class Counter extends StateNotifier<CounterState> {
  Box? _counterBox;
  Timer? _timer;
  Task? activeTask;
  int currentSubTaskIndex = 0;
  bool _isForceToggle = false;
  int _pomodoroCount = 0;
  BuildContext? _context;

  Counter()
      : super(const CounterState(
    remainingTime: 25 * 60,
    isRunning: false,
    selectedTab: 'pomodoro',
    isLoading: true,
  )) {
    _initializeBox();
  }

  void setContext(BuildContext context) {
    _context = context;
  }

  Future<void> _initializeBox() async {
    try {
      if (!Hive.isBoxOpen('counterBox')) {
        _counterBox = await Hive.openBox('counterBox');
      } else {
        _counterBox = Hive.box('counterBox');
      }
      final savedRemainingTime = _counterBox!.get('remainingTime');
      final savedIsRunning = _counterBox!.get('isRunning');
      final savedSelectedTab = _counterBox!.get('selectedTab');

      await Future.delayed(const Duration(milliseconds: 500)); // Loading göstergesi için kısa gecikme

      state = CounterState(
        remainingTime: savedRemainingTime is int
            ? savedRemainingTime
            : getCustomDuration('pomodoro'),
        isRunning: savedIsRunning is bool ? savedIsRunning : false,
        selectedTab:
        savedSelectedTab is String ? savedSelectedTab : 'pomodoro',
        isLoading: false,
      );
      debugPrint('Counter verileri yüklendi');

      // Eğer timer çalışıyorsa, yeniden başlat
      if (state.isRunning) {
        _startTimer();
      }
    } catch (e) {
      debugPrint("Counter kutusu yükleme hatası: $e");
      state = state.copyWith(
        remainingTime: getCustomDuration('pomodoro'),
        isRunning: false,
        selectedTab: 'pomodoro',
        isLoading: false,
      );
    }
  }

  Future<void> saveState() async {
    try {
      if (_counterBox != null && _counterBox!.isOpen) {
        await _counterBox!.putAll({
          'remainingTime': state.remainingTime,
          'isRunning': state.isRunning,
          'selectedTab': state.selectedTab,
        });
        debugPrint('Counter verileri kaydedildi');
      }
    } catch (e) {
      debugPrint("Counter kaydetme hatası: $e");
    }
  }

  void updateCustomDurations({
    required int pomodoro,
    required int shortBreak,
    required int longBreak,
  }) {
    if (_counterBox != null) {
      _counterBox!.put('pomodoroDuration', pomodoro);
      _counterBox!.put('shortBreakDuration', shortBreak);
      _counterBox!.put('longBreakDuration', longBreak);
    }
    state = state.copyWith(remainingTime: getCustomDuration(state.selectedTab));
    saveState();
  }

  int getCustomDuration(String tab) {
    if (_counterBox == null) return 25 * 60;
    switch (tab) {
      case 'shortBreak':
        return _counterBox!
            .get('shortBreakDuration', defaultValue: 5 * 60) as int;
      case 'longBreak':
        return _counterBox!
            .get('longBreakDuration', defaultValue: 15 * 60) as int;
      default:
        return _counterBox!
            .get('pomodoroDuration', defaultValue: 25 * 60) as int;
    }
  }

  void toggleTimer() {
    if (state.isRunning) {
      _timer?.cancel();
      state = state.copyWith(isRunning: false);
      saveState();
    } else {
      _startTimer();
      state = state.copyWith(isRunning: true);
      saveState();
    }
  }

  void _startTimer() {
    _timer?.cancel(); // Varolan timer'ı iptal et
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state.remainingTime > 0) {
        state = state.copyWith(remainingTime: state.remainingTime - 1);
        saveState();

        // Bildirim servisini güncelle
        try {
          if (_context != null) {
            final notificationService = NotificationService();
            await notificationService.updateNotification(
              context: _context!,
              title: activeTask?.title ?? '',
              task: state.formattedTime,
            );
          }
        } catch (e) {
          debugPrint('Bildirim güncelleme hatası: $e');
        }

        if (state.selectedTab == 'pomodoro') {
          await _updateStatisticsRecordProgressFor('pomodoro');
        } else if (state.selectedTab == 'shortBreak') {
          await _updateStatisticsRecordProgressFor('shortBreak');
        } else if (state.selectedTab == 'longBreak') {
          await _updateStatisticsRecordProgressFor('longBreak');
        }
      } else {
        await _handleTimerComplete();
      }
    });
  }

  // Bildirimden gelen toggle için yeni metot
  void toggleFromNotification() {
    _isForceToggle = true;
    if (!state.isRunning) {
      _startTimer();
      state = state.copyWith(isRunning: true);
    } else {
      _timer?.cancel();
      state = state.copyWith(isRunning: false);
    }
    saveState();
    _isForceToggle = false;
  }

  // Running state'i doğrudan güncellemek için yeni metot
  void setRunningState(bool isRunning) {
    if (!_isForceToggle) {
      if (isRunning && !state.isRunning) {
        _startTimer();
      } else if (!isRunning && state.isRunning) {
        _timer?.cancel();
      }
      state = state.copyWith(isRunning: isRunning);
      saveState();
    }
  }

  Future<void> _handleTimerComplete() async {
    _timer?.cancel();
    if (activeTask != null && activeTask!.subtasks.isNotEmpty) {
      if (state.selectedTab == 'pomodoro') {
        SubTask currentSub = activeTask!.subtasks[currentSubTaskIndex];
        if ((currentSubTaskIndex + 1) % activeTask!.longBreakFrequency == 0) {
          state = state.copyWith(
            selectedTab: 'longBreak',
            remainingTime: currentSub.longBreakDuration,
            isRunning: true,
          );
        } else {
          state = state.copyWith(
            selectedTab: 'shortBreak',
            remainingTime: currentSub.shortBreakDuration,
            isRunning: true,
          );
        }
      } else {
        int nextIndex = currentSubTaskIndex + 1;
        if (nextIndex >= activeTask!.subtasks.length) {
          nextIndex = 0;
        }
        SubTask nextSub = activeTask!.subtasks[nextIndex];
        state = state.copyWith(
          selectedTab: 'pomodoro',
          remainingTime: nextSub.pomodoroDuration,
          isRunning: true,
        );
        currentSubTaskIndex = nextIndex;
      }
    } else {
      // Görev seçili değilse
      if (state.selectedTab == 'pomodoro') {
        _pomodoroCount++;
        if (_pomodoroCount % 4 == 0) {
          state = state.copyWith(
            selectedTab: 'longBreak',
            remainingTime: getCustomDuration('longBreak'),
            isRunning: true,
          );
        } else {
          state = state.copyWith(
            selectedTab: 'shortBreak',
            remainingTime: getCustomDuration('shortBreak'),
            isRunning: true,
          );
        }
      } else {
        state = state.copyWith(
          selectedTab: 'pomodoro',
          remainingTime: getCustomDuration('pomodoro'),
          isRunning: true,
        );
      }
    }
    
    try {
      final notificationService = NotificationService();
      notificationService.setCurrentTab(state.selectedTab);
    } catch (e) {
      debugPrint('Tab güncelleme hatası: $e');
    }
    
    saveState();
    await _playAlarm();
  }

  Future<void> _playAlarm() async {
    try {
      Box settingsBox;
      if (!Hive.isBoxOpen('settingsBox')) {
        settingsBox = await Hive.openBox('settingsBox');
      } else {
        settingsBox = Hive.box('settingsBox');
      }
      String alarmName =
      settingsBox.get('selectedAlarm', defaultValue: "Alarm 1");
      await AlarmPlayer().playAlarm(alarmName);
    } catch (e) {
      debugPrint("Alarm çalma hatası: $e");
    }
  }

  Future<void> _updateStatisticsRecordProgressFor(String fieldName) async {
    try {
      Box statsBox;
      if (!Hive.isBoxOpen('statisticsBox')) {
        statsBox = await Hive.openBox('statisticsBox');
      } else {
        statsBox = Hive.box('statisticsBox');
      }
      
      List stored = statsBox.get('statisticsList', defaultValue: []) as List;
      DateTime now = DateTime.now();
      String todayDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      String dayName = getTurkishDayName(now);
      bool found = false;
      
      for (int i = 0; i < stored.length; i++) {
        Map<String, dynamic> recMap = Map<String, dynamic>.from(stored[i]);
        if (recMap['date'] == todayDate) {
          double currentVal = (recMap[fieldName] ?? 0).toDouble();
          double newVal = currentVal + 1;
          recMap[fieldName] = newVal;
          stored[i] = recMap;
          found = true;
          break;
        }
      }
      
      if (!found) {
        Map<String, dynamic> newRecord = {
          'day': dayName,
          'date': todayDate,
          'pomodoro': 0.0,
          'shortBreak': 0.0,
          'longBreak': 0.0,
        };
        newRecord[fieldName] = 1.0;
        stored.add(newRecord);
      }
      
      await statsBox.put('statisticsList', List.from(stored));
      debugPrint('İstatistik güncellendi: $fieldName');

      // Hive'ı yeniden yükle
      if (statsBox.isOpen) {
        await statsBox.close();
        await Hive.openBox('statisticsBox');
      }
    } catch (e) {
      debugPrint("Statistics progress update error: $e");
    }
  }

  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(
      remainingTime: getCustomDuration(state.selectedTab),
      isRunning: false,
    );
    saveState();
  }

  void setSelectedTab(String tab) {
    if (state.isRunning && tab != state.selectedTab) {
      return; // Sayaç çalışıyorken sekme değişimine izin verme
    }
    state = state.copyWith(
      selectedTab: tab,
      remainingTime: getCustomDuration(tab),
    );
    saveState();
    
    try {
      final notificationService = NotificationService();
      notificationService.setCurrentTab(tab);
    } catch (e) {
      debugPrint('Tab güncelleme hatası: $e');
    }
  }

  void setTimerDuration(int duration) {
    state = state.copyWith(remainingTime: duration);
    saveState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}