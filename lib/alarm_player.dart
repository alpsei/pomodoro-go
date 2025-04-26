import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// AlarmPlayer, alarm seslerini çalmak için optimize edilmiş bir singleton sınıftır.
class AlarmPlayer {
  // Singleton instance
  static final AlarmPlayer _instance = AlarmPlayer._internal();
  factory AlarmPlayer() => _instance;
  AlarmPlayer._internal();

  /// Aktif olarak çalan alarmın `AudioPlayer` nesnesi.
  AudioPlayer? _currentPlayer;

  /// Çalan alarmın dosya adı.
  String? _currentAlarm;

  /// Desteklenen alarm ses dosyaları.
  final List<String> availableAlarms = [
    "alarm1.mp3",
    "alarm2.mp3",
    "alarm3.mp3",
    "alarm4.mp3",
    "alarm5.mp3",
  ];

  /// Alarm çalma fonksiyonu
  Future<void> playAlarm(String alarmName) async {
    final String fileName = _mapAlarmNameToFile(alarmName);

    if (_currentPlayer != null) {
      await _currentPlayer!.stop();
      _currentPlayer = null;
    }

    try {
      _currentPlayer = AudioPlayer();
      _currentAlarm = fileName;

      // Eğer platform Android veya iOS ise, alarmı loop modunda çal.
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _currentPlayer!.setReleaseMode(ReleaseMode.loop);
      }

      await _currentPlayer!.play(AssetSource("sounds/$fileName"));

      // Örneğin, alarmın 10 saniye sonra otomatik durması için:
      Future.delayed(const Duration(seconds: 10), () {
        stopAlarm(alarmName);
      });
    } catch (e) {
      debugPrint("Alarm play error: $e");
    }
  }

  /// Çalan alarmı durdur
  Future<void> stopAlarm(String selectedAlarm) async {
    if (_currentPlayer != null) {
      try {
        await _currentPlayer!.stop();
        _currentPlayer = null;
        _currentAlarm = null;
      } catch (e) {
        debugPrint("Alarm stop error: $e");
      }
    }
  }

  /// Alarm adını dosya adına eşler.
  String _mapAlarmNameToFile(String alarmName) {
    final regex = RegExp(r'Alarm\s*(\d+)', caseSensitive: false);
    final match = regex.firstMatch(alarmName);
    if (match != null) {
      int index = int.parse(match.group(1)!);
      if (index >= 1 && index <= availableAlarms.length) {
        return availableAlarms[index - 1];
      }
    }
    return availableAlarms.first;
  }
}
