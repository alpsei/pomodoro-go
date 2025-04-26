import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isRunning = false;
  bool _isNotificationActive = false;
  String? _lastTitle;
  String? _lastTask;
  NotificationDetails? _lastNotificationDetails;
  static bool _isInitialized = false;
  String? _lastTab = 'pomodoro';
  BuildContext? _context;
  
  Function? onToggleTimer;
  Function? onUpdateRunningState;
  Function? onCloseApp;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  void setContext(BuildContext context) {
    _context = context;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    await _requestPostNotificationPermission();

    const AndroidInitializationSettings androidInitialization =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(android: androidInitialization);

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification response received: ${response.actionId}');
        _onNotificationResponse(response);
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'pomodoro_channel_id',
          'Pomodoro App Notifications',
          description: 'Persistent notification for pomodoro timer',
          importance: Importance.low,
          enableVibration: false,
          showBadge: false,
          playSound: false,
        ),
      );
    }

    _isInitialized = true;
    debugPrint('NotificationService initialized successfully');
  }

  Future<void> _requestPostNotificationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      debugPrint('Current notification permission status: $status');
      if (status.isDenied) {
        final result = await Permission.notification.request();
        debugPrint('Notification permission request result: $result');
      }
    }
  }

  void _onNotificationResponse(NotificationResponse response) async {
    if (_context == null) return;
    
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');

    if (response.actionId != null) {
      switch (response.actionId) {
        case 'toggle':
          debugPrint('Toggle action received');
          _isRunning = !_isRunning;

          if (onToggleTimer != null) {
            debugPrint('Calling toggle timer callback');
            onToggleTimer!();
          }

          if (onUpdateRunningState != null) {
            debugPrint('Updating running state to: $_isRunning');
            onUpdateRunningState!(_isRunning);
          }

          if (_isNotificationActive && _lastTitle != null && _lastNotificationDetails != null) {
            await Future.delayed(const Duration(milliseconds: 100));
            
            final androidDetails = AndroidNotificationDetails(
              'pomodoro_channel_id',
              'Pomodoro App Notifications',
              channelDescription: 'Persistent notification for pomodoro timer',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              playSound: false,
              enableVibration: false,
              showWhen: false,
              actions: [
                AndroidNotificationAction(
                  'toggle',
                  _context != null && AppLocalizations.of(_context!) != null 
                      ? (_isRunning 
                          ? AppLocalizations.of(_context!)!.stopTimer 
                          : AppLocalizations.of(_context!)!.startTimer)
                      : _isRunning ? 'Durdur' : 'Başlat',
                  showsUserInterface: true,
                  cancelNotification: false,
                ),
                AndroidNotificationAction(
                  'close',
                  _context != null && AppLocalizations.of(_context!) != null 
                      ? AppLocalizations.of(_context!)!.closeApp 
                      : 'Kapat',
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ],
            );

            final updatedDetails = NotificationDetails(android: androidDetails);
            
            await _flutterLocalNotificationsPlugin.show(
              0,
              _lastTitle!,
              _lastTask,
              updatedDetails,
            );
          }
          break;

        case 'close':
          debugPrint('Close action received');
          if (_isRunning && onToggleTimer != null) {
            onToggleTimer!();
          }
          await closeNotification();
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isIOS) {
            exit(0);
          }
          break;
      }
    }
  }

  void setCurrentTab(String tab) {
    _lastTab = tab;
  }

  Future<void> updateNotification({
    required BuildContext context,
    required String title,
    required String task,
  }) async {
    _lastTitle = title;
    _lastTask = task;
    _context = context;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_id',
      'Pomodoro Timer',
      channelDescription: 'Pomodoro timer notifications',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'toggle',
          _isRunning
              ? (AppLocalizations.of(_context!)?.stopTimer ?? 'Durdur')
              : (AppLocalizations.of(_context!)?.startTimer ?? 'Başlat'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'close',
          AppLocalizations.of(_context!)?.closeApp ?? 'Kapat',
          showsUserInterface: true,
        ),
      ],
      color: isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC),
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      task,
      platformChannelSpecifics,
      payload: 'Default_Sound',
    );
  }

  Future<void> showCompletionNotification(String type, BuildContext context) async {
    String title;
    String body;
    
    if (Localizations.localeOf(context).languageCode == 'en') {
      switch(type) {
        case 'pomodoro':
          title = 'Pomodoro Completed!';
          body = 'Time to take a break.';
          break;
        case 'shortBreak':
          title = 'Break Completed!';
          body = 'Ready to start working?';
          break;
        case 'longBreak':
          title = 'Long Break Completed!';
          body = 'Great job! Ready for a new session?';
          break;
        default:
          title = 'Timer Completed!';
          body = 'Check your timer.';
      }
    } else {
      switch(type) {
        case 'pomodoro':
          title = 'Pomodoro Tamamlandı!';
          body = 'Mola zamanı.';
          break;
        case 'shortBreak':
          title = 'Mola Tamamlandı!';
          body = 'Çalışmaya hazır mısın?';
          break;
        case 'longBreak':
          title = 'Uzun Mola Tamamlandı!';
          body = 'Harika iş! Yeni bir oturum için hazır mısın?';
          break;
        default:
          title = 'Zamanlayıcı Tamamlandı!';
          body = 'Zamanlayıcınızı kontrol edin.';
      }
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'completion_id',
      'Timer Completion',
      channelDescription: 'Notifications for timer completion',
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      1,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> closeNotification() async {
    debugPrint('Closing notification');
    await _flutterLocalNotificationsPlugin.cancel(0);
    _isNotificationActive = false;
  }

  String formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  String _getTabName() {
    switch (_lastTab) {
      case 'shortBreak':
        return 'Kısa Mola';
      case 'longBreak':
        return 'Uzun Mola';
      default:
        return 'Pomodoro';
    }
  }
}