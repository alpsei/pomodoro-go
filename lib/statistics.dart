// statistics.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Her gün için istatistik kaydını tutan model
class StatisticRecord {
  final String day;   // Örn: "Pazartesi"
  final String date;  // Örn: "2025-02-10"
  final double pomodoro;   // Saniye cinsinden toplam çalışma süresi
  final double shortBreak;
  final double longBreak;

  StatisticRecord({
    required this.day,
    required this.date,
    required this.pomodoro,
    required this.shortBreak,
    required this.longBreak,
  });

  factory StatisticRecord.fromMap(Map<String, dynamic> map) {
    return StatisticRecord(
      day: map['day'] ?? '',
      date: map['date'] ?? '',
      pomodoro: (map['pomodoro'] ?? 0).toDouble(),
      shortBreak: (map['shortBreak'] ?? 0).toDouble(),
      longBreak: (map['longBreak'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'date': date,
      'pomodoro': pomodoro,
      'shortBreak': shortBreak,
      'longBreak': longBreak,
    };
  }
}

/// Belirtilen tarihin Türkçe gün adını döndürür.
String getTurkishDayName(DateTime date, BuildContext context) {
  if (Localizations.localeOf(context).languageCode == 'en') {
    switch (date.weekday) {
      case DateTime.monday: return "Monday";
      case DateTime.tuesday: return "Tuesday";
      case DateTime.wednesday: return "Wednesday";
      case DateTime.thursday: return "Thursday";
      case DateTime.friday: return "Friday";
      case DateTime.saturday: return "Saturday";
      case DateTime.sunday: return "Sunday";
      default: return "";
    }
  } else {
    switch (date.weekday) {
      case DateTime.monday: return "Pazartesi";
      case DateTime.tuesday: return "Salı";
      case DateTime.wednesday: return "Çarşamba";
      case DateTime.thursday: return "Perşembe";
      case DateTime.friday: return "Cuma";
      case DateTime.saturday: return "Cumartesi";
      case DateTime.sunday: return "Pazar";
      default: return "";
    }
  }
}

/// İstatistik ekranı: Son 7 günlük veriyi grafik ve takvim şeklinde iki sekme ile gösterir.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Box statisticsBox;
  DateTime selectedDate = DateTime.now();
  String currentTab = 'graph';

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    if (!Hive.isBoxOpen('statisticsBox')) {
      statisticsBox = await Hive.openBox('statisticsBox');
    } else {
      statisticsBox = Hive.box('statisticsBox');
    }
    if (mounted) setState(() {});
  }

  /// Sadece son 7 günü (haftanın Pazartesi'den Pazar'a kadar) gösterir.
  List<StatisticRecord> getDisplayStatistics() {
    if (statisticsBox == null) return [];
    List stored = statisticsBox!.get('statisticsList', defaultValue: []) as List;
    DateTime now = DateTime.now();
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    List<StatisticRecord> weekRecords = [];
    for (int i = 0; i < 7; i++) {
      DateTime day = monday.add(Duration(days: i));
      String dateString =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      Map<String, dynamic>? recMap;
      for (var item in stored) {
        Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        if (itemMap['date'] == dateString) {
          recMap = itemMap;
          break;
        }
      }
      if (recMap != null) {
        weekRecords.add(StatisticRecord.fromMap(recMap));
      } else {
        weekRecords.add(StatisticRecord(
          day: getTurkishDayName(day, context),
          date: dateString,
          pomodoro: 0,
          shortBreak: 0,
          longBreak: 0,
        ));
      }
    }
    return weekRecords;
  }

  /// İstatistik listesini temizler.
  Future<void> _clearStatistics() async {
    await statisticsBox.clear();
    setState(() {});
  }

  /// Grafik sekmesi
  Widget _buildGraphTab() {
    if (statisticsBox == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    double totalMinutes =
        getDisplayStatistics().fold(0.0, (prev, rec) => prev + rec.pomodoro) / 60;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder(
        valueListenable: statisticsBox!.listenable(),
        builder: (context, Box box, _) {
          List<StatisticRecord> data = getDisplayStatistics();
          return Column(
            children: [
              Expanded(
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  primaryYAxis: NumericAxis(labelFormat: '{value} dk'),
                  legend: Legend(isVisible: true),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: <CartesianSeries>[
                    ColumnSeries<StatisticRecord, String>(
                      dataSource: data,
                      xValueMapper: (StatisticRecord rec, _) => rec.day,
                      yValueMapper: (StatisticRecord rec, _) => rec.pomodoro / 60,
                      name: 'Pomodoro',
                      color: Colors.blue,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    ),
                    ColumnSeries<StatisticRecord, String>(
                      dataSource: data,
                      xValueMapper: (StatisticRecord rec, _) => rec.day,
                      yValueMapper: (StatisticRecord rec, _) => rec.shortBreak / 60,
                      name: 'Kısa Mola',
                      color: Colors.green,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    ),
                    ColumnSeries<StatisticRecord, String>(
                      dataSource: data,
                      xValueMapper: (StatisticRecord rec, _) => rec.day,
                      yValueMapper: (StatisticRecord rec, _) => rec.longBreak / 60,
                      name: 'Uzun Mola',
                      color: Colors.red,
                      dataLabelSettings: const DataLabelSettings(isVisible: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Toplam: ${totalMinutes.toStringAsFixed(0)} dk",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Takvim sekmesi
  Widget _buildCalendarTab() {
    if (statisticsBox == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ValueListenableBuilder(
        valueListenable: statisticsBox!.listenable(),
        builder: (context, Box box, _) {
          List stored = box.get('statisticsList', defaultValue: []) as List;
          List<StatisticRecord> allRecords = stored
              .map((item) =>
              StatisticRecord.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          Map<DateTime, StatisticRecord> recordMap = {};
          for (var record in allRecords) {
            try {
              DateTime date = DateTime.parse(record.date);
              recordMap[date] = record;
            } catch (e) {
              // Hata varsa pas geç
            }
          }

          final Map<int, String> months = {
            1: Localizations.localeOf(context).languageCode == 'en' ? 'January' : 'Ocak',
            2: Localizations.localeOf(context).languageCode == 'en' ? 'February' : 'Şubat',
            3: Localizations.localeOf(context).languageCode == 'en' ? 'March' : 'Mart',
            4: Localizations.localeOf(context).languageCode == 'en' ? 'April' : 'Nisan',
            5: Localizations.localeOf(context).languageCode == 'en' ? 'May' : 'Mayıs',
            6: Localizations.localeOf(context).languageCode == 'en' ? 'June' : 'Haziran',
            7: Localizations.localeOf(context).languageCode == 'en' ? 'July' : 'Temmuz',
            8: Localizations.localeOf(context).languageCode == 'en' ? 'August' : 'Ağustos',
            9: Localizations.localeOf(context).languageCode == 'en' ? 'September' : 'Eylül',
            10: Localizations.localeOf(context).languageCode == 'en' ? 'October' : 'Ekim',
            11: Localizations.localeOf(context).languageCode == 'en' ? 'November' : 'Kasım',
            12: Localizations.localeOf(context).languageCode == 'en' ? 'December' : 'Aralık',
          };

          String formatMonthYear(DateTime date) {
            return '${months[date.month]} ${date.year}';
          }

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime(DateTime.now().year, 1, 1),
                lastDay: DateTime(DateTime.now().year, 12, 31),
                focusedDay: selectedDate,
                selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    selectedDate = selectedDay;
                  });
                  StatisticRecord? record = recordMap[selectedDay];
                  final Color dialogBg = isDark ? Colors.black : Colors.white;
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        backgroundColor: dialogBg,
                        title: Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? "Statistics: ${selectedDay.day} ${months[selectedDay.month]} ${selectedDay.year}"
                                : "İstatistikler: ${selectedDay.day} ${months[selectedDay.month]} ${selectedDay.year}",
                            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        content: record != null
                            ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? "Pomodoro: ${(record.pomodoro / 60).toStringAsFixed(0)} min"
                                    : "Pomodoro: ${(record.pomodoro / 60).toStringAsFixed(0)} dk",
                                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                            Text(
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? "Short Break: ${(record.shortBreak / 60).toStringAsFixed(0)} min"
                                    : "Kısa Mola: ${(record.shortBreak / 60).toStringAsFixed(0)} dk",
                                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                            Text(
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? "Long Break: ${(record.longBreak / 60).toStringAsFixed(0)} min"
                                    : "Uzun Mola: ${(record.longBreak / 60).toStringAsFixed(0)} dk",
                                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                          ],
                        )
                            : Text(
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? "No statistics found for this day."
                                    : "Bu gün için istatistik bulunamadı.",
                                style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                            ),
                            child: Text(
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? "Close"
                                    : "Kapat"),
                          ),
                        ],
                      );
                    },
                  );
                },
                calendarStyle: CalendarStyle(
                  todayDecoration:
                  const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7FB3D5) : const Color(0xFF5DADE2),
                    shape: BoxShape.circle,
                  ),
                  defaultTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                  weekendTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleTextFormatter: (date, locale) => formatMonthYear(date),
                  titleTextStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                  leftChevronIcon:
                  Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black),
                  rightChevronIcon:
                  Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    StatisticRecord? record = recordMap[date];
                    if (record != null && record.pomodoro > 0) {
                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green,
                        ),
                        width: 8,
                        height: 8,
                      );
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text("Bir tarihe tıklayarak o günün istatistiklerini görüntüleyin.",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.delete, color: isDark ? Colors.white : Colors.black),
              onPressed: _clearStatistics,
            ),
          ],
          title: Text(AppLocalizations.of(context)!.statistics,
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                currentTab = index == 0 ? 'graph' : 'calendar';
              });
            },
            tabs: [
              Tab(
                child: Text(AppLocalizations.of(context)!.graphTab,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              ),
              Tab(
                child: Text(AppLocalizations.of(context)!.calendarTab,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              ),
            ],
          ),
        ),
        body: FutureBuilder(
          future: _openBox(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return TabBarView(
              children: [
                _buildGraphTab(),
                _buildCalendarTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}
