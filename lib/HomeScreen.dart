// homescreen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'notification_service.dart'; // Bildirim servisi
import 'providers.dart';
import './Counter.dart';
import 'tasks.dart';          // Görevler ekranı
import 'statistics.dart';    // İstatistikler ekranı
import 'settings.dart';      // Ayarlar ekranı

/// Dalgalı (wavy) kenarı çizen custom painter (değişmedi)
class WavyCirclePainter extends CustomPainter {
  final double animationValue;
  final Color borderColor;
  final double strokeWidth;
  final bool isRunning;

  WavyCirclePainter({
    required this.animationValue,
    required this.borderColor,
    this.strokeWidth = 8.0,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final path = Path();
    const int waveCount = 12;
    final double baseAmplitude = 1.0;
    // Timer çalışıyorsa dalgalanma; değilse normal çember.
    final double amplitude =
    isRunning ? baseAmplitude * (0.5 + 0.5 * sin(animationValue * 2 * pi)) : 0.0;
    final double phase = animationValue * 2 * pi;
    const int segments = 180;
    for (int i = 0; i <= segments; i++) {
      final double theta = (i / segments) * 2 * pi;
      final double wave = sin(waveCount * theta + phase) * amplitude;
      final double rValue = radius + wave;
      final double x = center.dx + rValue * cos(theta);
      final double y = center.dy + rValue * sin(theta);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavyCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.isRunning != isRunning;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isUpdating = false;
  late Box homeScreenBox;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Görev yönetimi: Görev listesi ve seçili görev index'i
  List<Task> _tasks = [];
  int? _activeTaskIndex; // Seçili görev varsa index burada tutulur; yoksa null.
  Box? tasksBox;

  // Tek seferlik kullanmak üzere NotificationService örneği
  late final NotificationService _notificationService;

  @override
  void initState() {
    super.initState();
    _initializeHomeScreenBox();
    _loadTasks();

    _notificationService = NotificationService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _notificationService.init();
      _notificationService.setContext(context);

      // Counter'a context'i ekle
      ref.read(counterProvider.notifier).setContext(context);

      // Bildirimden gelen toggle işlemi için callback
      _notificationService.onToggleTimer = () {
        debugPrint("Bildirimden toggle tetiklendi");
        if (!mounted) return;

        final counterNotifier = ref.read(counterProvider.notifier);
        counterNotifier.toggleFromNotification();

        // Bildirimi hemen güncelle
        final counterState = ref.read(counterProvider);
        _notificationService.updateNotification(
          context: context,
          title: counterNotifier.activeTask?.title ?? '',
          task: counterState.formattedTime,
        );
      };

      // Bildirimden gelen running state değişiklikleri için callback
      _notificationService.onUpdateRunningState = (bool isRunning) {
        debugPrint("Bildirimden running state güncellendi: $isRunning");
        if (!mounted) return;

        final counterNotifier = ref.read(counterProvider.notifier);
        counterNotifier.setRunningState(isRunning);

        // Bildirimi hemen güncelle
        final counterState = ref.read(counterProvider);
        _notificationService.updateNotification(
          context: context,
          title: counterNotifier.activeTask?.title ?? '',
          task: counterState.formattedTime,
        );
      };

      // İlk bildirimi başlat
      final counterState = ref.read(counterProvider);

      // İlk bildirimi force update ile oluştur
      await _notificationService.updateNotification(
        context: context,
        title: ref.read(counterProvider.notifier).activeTask?.title ?? '',
        task: counterState.formattedTime,
      );

      // Sayaç değişikliklerini dinle
      ref.listen<CounterState>(
        counterProvider,
        (previous, next) {
          if (!mounted) return;

          // Her değişiklikte bildirimi güncelle
          _notificationService.updateNotification(
            context: context,
            title: ref.read(counterProvider.notifier).activeTask?.title ?? '',
            task: next.formattedTime,
          );
        },
      );

      _updateData();
    });

    // Animasyon controller'ı başlat
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }


  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeHomeScreenBox() async {
    try {
      if (!Hive.isBoxOpen('homeScreenBox')) {
        homeScreenBox = await Hive.openBox('homeScreenBox');
      } else {
        homeScreenBox = Hive.box('homeScreenBox');
      }
      final bool isFirstTime =
      homeScreenBox.get('isFirstTime', defaultValue: true);
      if (isFirstTime) {
        debugPrint("HomeScreen ilk kez açılıyor.");
        homeScreenBox.put('isFirstTime', false);
      } else {
        debugPrint("HomeScreen daha önce açılmış.");
      }
    } catch (e) {
      debugPrint("HomeScreen kutusu yükleme hatası: $e");
    }
  }

  Future<void> _loadTasks() async {
    if (!Hive.isBoxOpen('tasksBox')) {
      tasksBox = await Hive.openBox('tasksBox');
    } else {
      tasksBox = Hive.box('tasksBox');
    }
    List stored = tasksBox!.get('tasksList', defaultValue: []);
    if (mounted) {
      setState(() {
        _tasks = stored
            .map((e) => Task.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      });
    }
  }

  Future<void> _updateData() async {
    setState(() {
      _isUpdating = true;
    });
    try {
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      debugPrint("Güncelleme sırasında hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  /// Görev seçimi dropdown'u
  Widget _buildTaskDropdown() {
    if (_tasks.isEmpty) return Container();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButton<int>(
        isDense: true,
        underline: Container(),
        hint: Text(AppLocalizations.of(context)!.addTask, 
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87
            )),
        value: _activeTaskIndex,
        items: _tasks.asMap().entries.map((entry) {
          int index = entry.key;
          Task task = entry.value;
          return DropdownMenuItem<int>(
            value: index,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(task.title, 
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
                    )),
                const SizedBox(width: 8),
                Text("${(task.totalDuration / 60).toStringAsFixed(0)} ${AppLocalizations.of(context)!.minutes}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87
                    )),
              ],
            ),
          );
        }).toList(),
        onChanged: (int? newIndex) {
          setState(() {
            _activeTaskIndex = newIndex;
          });
          if (newIndex != null) {
            Task selected = _tasks[newIndex];
            if (selected.subtasks.isNotEmpty) {
              final first = selected.subtasks.first;
              final counterNotifier = ref.read(counterProvider.notifier);
              counterNotifier.activeTask = selected;
              counterNotifier.currentSubTaskIndex = 0;
              counterNotifier.updateCustomDurations(
                pomodoro: first.pomodoroDuration,
                shortBreak: first.shortBreakDuration,
                longBreak: first.longBreakDuration,
              );
              counterNotifier.setTimerDuration(first.pomodoroDuration);
              counterNotifier.setSelectedTab('pomodoro');
            }
          }
        },
      ),
    );
  }

  // Sekme butonları; eğer görev seçiliyse dokunulamaz.
  Widget _buildTabButton(
      String text,
      String tabName,
      CounterState counterState,
      Counter counterNotifier,
      Color accentColor,
      Color primaryColor,
      ) {
    final isSelected = counterState.selectedTab == tabName;
    final bool isTaskMode = _activeTaskIndex != null;
    return GestureDetector(
      onTap: () {
        if (!isTaskMode) {
          counterNotifier.setTimerDuration(_getDurationByTab(tabName));
          counterNotifier.setSelectedTab(tabName);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  int _getDurationByTab(String tab) {
    switch (tab) {
      case 'shortBreak':
        return 5 * 60;
      case 'longBreak':
        return 15 * 60;
      default:
        return 25 * 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final counterState = ref.watch(counterProvider);
    final counterNotifier = ref.read(counterProvider.notifier);
    final themeState = ref.watch(themeProvider);
    final isDark = themeState.isDarkMode;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final accentColor =
    isDark ? const Color(0xFF7FB3D5) : const Color(0xFF5DADE2);
    final circleColor =
    isDark ? const Color(0xFFB0C4DE) : const Color(0xFFAEC6CF);
    final tabBackgroundColor =
    isDark ? const Color(0xFF273C51) : const Color(0xFFAEC6CF);
    final iconColor = isDark ? const Color(0xFFB0C4DE) : const Color(0xFF2C3E50);

    if (counterState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC),
      body: Stack(
        children: [
          // Sol üstte tema değiştirme butonu
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                  color: iconColor,
                  size: 35,
                ),
                onPressed: () {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              ),
            ),
          ),
          // Sağ üstte istatistik butonu
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.bar_chart, size: 35, color: iconColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StatisticsScreen()),
                  );
                },
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Görev seçimi dropdown'u
                      _buildTaskDropdown(),
                      // Sekme Barı
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 300,
                        height: 50,
                        decoration: BoxDecoration(
                          color: tabBackgroundColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildTabButton(
                              AppLocalizations.of(context)!.pomodoro,
                              'pomodoro',
                              counterState,
                              counterNotifier,
                              accentColor,
                              primaryColor,
                            ),
                            _buildTabButton(
                              AppLocalizations.of(context)!.shortBreak,
                              'shortBreak',
                              counterState,
                              counterNotifier,
                              accentColor,
                              primaryColor,
                            ),
                            _buildTabButton(
                              AppLocalizations.of(context)!.longBreak,
                              'longBreak',
                              counterState,
                              counterNotifier,
                              accentColor,
                              primaryColor,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Timer Container
                      GestureDetector(
                        onTap: () => counterNotifier.toggleTimer(),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ScaleTransition(
                              scale: counterState.isRunning
                                  ? _pulseAnimation
                                  : AlwaysStoppedAnimation(1.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration:
                                    const Duration(milliseconds: 300),
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: counterState.isRunning
                                          ? circleColor.withOpacity(0.1)
                                          : circleColor.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(200, 200),
                                        painter: WavyCirclePainter(
                                          animationValue:
                                          _pulseController.value,
                                          borderColor: circleColor,
                                          strokeWidth: 8.0,
                                          isRunning: counterState.isRunning,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                      opacity: animation, child: child),
                              child: Column(
                                key: ValueKey(counterState.formattedTime),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    counterState.formattedTime,
                                    style: TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    counterState.isRunning 
                                      ? AppLocalizations.of(context)!.pause
                                      : AppLocalizations.of(context)!.start,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Reset Butonu
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: primaryColor,
                          size: 40,
                        ),
                        onPressed: () => counterNotifier.resetTimer(),
                      ),
                      // Eğer görev seçiliyse "Görevi İptal Et" butonu
                      if (_activeTaskIndex != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              _activeTaskIndex = null;
                            });
                            final counterNotifier =
                            ref.read(counterProvider.notifier);
                            counterNotifier.activeTask = null;
                            counterNotifier.updateCustomDurations(
                              pomodoro: 25 * 60,
                              shortBreak: 5 * 60,
                              longBreak: 15 * 60,
                            );
                            counterNotifier.setTimerDuration(25 * 60);
                            counterNotifier.setSelectedTab('pomodoro');
                          },
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Alt Butonlar: Görevler ve Ayarlar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: primaryColor,
                              size: 40,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const TasksScreen()),
                              ).then((_) {
                                if (mounted) _loadTasks();
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.settings,
                              color: primaryColor,
                              size: 40,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (context) {
                                  return SettingsScreen(
                                    isTaskMode: _activeTaskIndex != null,
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isUpdating)
            AnimatedOpacity(
              opacity: _isUpdating ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
