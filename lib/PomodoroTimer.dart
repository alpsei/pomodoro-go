import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class PomodoroTimer extends ConsumerWidget {
  const PomodoroTimer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterState = ref.watch(counterProvider);
    final counterNotifier = ref.read(counterProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  counterState.formattedTime,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              child: IconButton(
                icon: Icon(
                  counterState.totalTime == 0
                      ? Icons.refresh
                      : counterState.isRunning
                      ? Icons.pause
                      : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (counterState.totalTime == 0) {
                    // Ek işlev ekleyebilirsiniz.
                  } else {
                    counterNotifier.toggleTimer();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
