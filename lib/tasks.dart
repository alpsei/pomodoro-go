// tasks.dart
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pomodoro/settings.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Üst görev modeli; alt görevlerin sürelerinin toplamı hesaplanır.
class Task {
  String title;
  String label;
  Color labelColor;
  List<SubTask> subtasks;
  int longBreakFrequency;

  Task({
    required this.title,
    required this.label,
    required this.labelColor,
    List<SubTask>? subtasks,
    this.longBreakFrequency = 4,
  }) : subtasks = subtasks ?? [];

  /// Alt görevlerin sürelerinin toplamı (saniye cinsinden)
  int get totalDuration {
    int total = 0;
    for (int i = 0; i < subtasks.length; i++) {
      SubTask sub = subtasks[i];
      if ((i + 1) % longBreakFrequency == 0) {
        total += sub.pomodoroDuration + sub.longBreakDuration;
      } else {
        total += sub.pomodoroDuration + sub.shortBreakDuration;
      }
    }
    return total;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'label': label,
      'labelColor': labelColor.value,
      'longBreakFrequency': longBreakFrequency,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    List<dynamic>? subtaskList = map['subtasks'];
    return Task(
      title: map['title'] ?? '',
      label: map['label'] ?? '',
      labelColor: Color(map['labelColor'] ?? Colors.grey.value),
      longBreakFrequency: map['longBreakFrequency'] ?? 4,
      subtasks: subtaskList != null
          ? subtaskList.map((s) {
        if (s is Map) {
          return SubTask.fromMap(Map<String, dynamic>.from(s));
        } else {
          return SubTask(
            title: '',
            label: '',
            labelColor: Colors.grey,
            pomodoroDuration: 25 * 60,
            shortBreakDuration: 5 * 60,
            longBreakDuration: 15 * 60,
          );
        }
      }).toList()
          : [],
    );
  }
}

/// Alt görev modeli; her alt görev için ayrı süreler ve etiket tanımlanır.
class SubTask {
  String title;
  String label;
  Color labelColor;
  int pomodoroDuration;    // saniye cinsinden
  int shortBreakDuration;  // saniye cinsinden
  int longBreakDuration;   // saniye cinsinden

  SubTask({
    required this.title,
    required this.label,
    required this.labelColor,
    required this.pomodoroDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'label': label,
      'labelColor': labelColor.value,
      'pomodoroDuration': pomodoroDuration,
      'shortBreakDuration': shortBreakDuration,
      'longBreakDuration': longBreakDuration,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      title: map['title'] ?? '',
      label: map['label'] ?? '',
      labelColor: Color(map['labelColor'] ?? Colors.grey.value),
      pomodoroDuration: map['pomodoroDuration'] ?? (25 * 60),
      shortBreakDuration: map['shortBreakDuration'] ?? (5 * 60),
      longBreakDuration: map['longBreakDuration'] ?? (15 * 60),
    );
  }
}

/// Görevler ekranı: Görevler eklenir, sıralanır, düzenlenir ve silinir.
class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Task> tasks = [];
  Box? tasksBox;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!Hive.isBoxOpen('tasksBox')) {
      tasksBox = await Hive.openBox('tasksBox');
    } else {
      tasksBox = Hive.box('tasksBox');
    }
    List<dynamic> stored = tasksBox!.get('tasksList', defaultValue: []);
    if (mounted) {
      setState(() {
        tasks = stored.map((e) {
          if (e is Map) {
            return Task.fromMap(Map<String, dynamic>.from(e));
          } else {
            return Task(title: '', label: '', labelColor: Colors.grey);
          }
        }).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    if (tasksBox != null && tasksBox!.isOpen) {
      await tasksBox!.put('tasksList', tasks.map((t) => t.toMap()).toList());
    }
  }

  void _addNewTask() {
    setState(() {
      tasks.add(Task(
        title: AppLocalizations.of(context)!.addTask,
        label: AppLocalizations.of(context)!.label,
        labelColor: Colors.grey,
      ));
    });
    _saveTasks();
  }

  void _deleteTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
    _saveTasks();
  }

  void _openTaskDetail(Task task, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TaskDetailSheet(
            task: task,
            onSave: (updatedTask) {
              setState(() {
                tasks[index] = updatedTask;
              });
              _saveTasks();
              Navigator.pop(context);
            },
          )),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = tasks.removeAt(oldIndex);
      tasks.insert(newIndex, task);
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color appBarColor = isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC);
    final Color fabColor = isDark ? appBarColor : const Color(0xFFE0E5ED);
    return WillPopScope(
      onWillPop: () async {
        await _saveTasks();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBarColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(AppLocalizations.of(context)!.tasks, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        ),
        body: tasks.isEmpty
            ? Center(
                child: Text(
                  AppLocalizations.of(context)!.noTasks,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black38,
                    fontSize: 18,
                  ),
                ),
              )
            : ReorderableListView(
                onReorder: _onReorder,
                children: [
                  for (int index = 0; index < tasks.length; index++)
                    Dismissible(
                      key: ValueKey('$index-${tasks[index].title.isEmpty ? UniqueKey() : tasks[index].title}'),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.startToEnd,
                      onDismissed: (direction) {
                        _deleteTask(index);
                      },
                      child: ListTile(
                        leading: Icon(Icons.drag_handle, 
                          color: isDark ? Colors.white70 : Colors.black54),
                        title: Text(tasks[index].title, 
                          style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        subtitle: Text(
                          "${tasks[index].subtasks.length} ${AppLocalizations.of(context)!.tasks}",
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, 
                                color: isDark ? Colors.white70 : Colors.black54),
                              onPressed: () => _openTaskDetail(tasks[index], index),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, 
                                color: isDark ? Colors.white70 : Colors.black54),
                              onPressed: () => _deleteTask(index),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewTask,
          backgroundColor: fabColor,
          child: Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

/// Görev detay düzenleme ekranı
class TaskDetailSheet extends StatefulWidget {
  final Task task;
  final Function(Task) onSave;

  const TaskDetailSheet({Key? key, required this.task, required this.onSave}) : super(key: key);

  @override
  _TaskDetailSheetState createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late TextEditingController titleController;
  late String label;
  late Color labelColor;
  late int longBreakFrequency;
  List<SubTask> subtasks = [];
  Color selectedColor = Colors.blue;
  
  final List<Color> palette = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.task.title);
    label = widget.task.label;
    labelColor = widget.task.labelColor;
    longBreakFrequency = widget.task.longBreakFrequency;
    subtasks = List.from(widget.task.subtasks);
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  // Tema bilgisi ile renkleri ayarlama
  Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color getSubtitleColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87;
  }

  Color getContainerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
  }

  Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  /// Etiket seçimi için modal bottom sheet (arka plan temaya göre)
  Future<Map<String, dynamic>?> _openLabelPicker() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color modalBg = isDark ? Colors.black : Colors.white;
    final Color accentColor = isDark ? const Color(0xFF7FB3D5) : const Color(0xFF5DADE2);
    
    List<Map<String, dynamic>> predefinedCategories = [
      {"name": AppLocalizations.of(context)!.study, "color": Colors.blue},
      {"name": AppLocalizations.of(context)!.work, "color": Colors.green},
      {"name": AppLocalizations.of(context)!.personal, "color": Colors.purple},
      {"name": AppLocalizations.of(context)!.reading, "color": Colors.orange},
      {"name": AppLocalizations.of(context)!.exercise, "color": Colors.red},
      {"name": AppLocalizations.of(context)!.project, "color": Colors.teal},
      {"name": AppLocalizations.of(context)!.writing, "color": Colors.indigo},
      {"name": AppLocalizations.of(context)!.meditation, "color": Colors.cyan},
    ];

    TextEditingController categoryController = TextEditingController();
    String selectedCategory = "";

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              color: modalBg,
              height: 500,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.selectCategory,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: getTextColor(context))),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.predefinedCategories,
                      style: TextStyle(fontSize: 16, color: getSubtitleColor(context))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: predefinedCategories.map((category) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(context, {
                            "label": category["name"],
                            "labelColor": category["color"],
                          });
                        },
                        child: Chip(
                          backgroundColor: category["color"],
                          label: Text(category["name"],
                              style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.customCategory,
                      style: TextStyle(fontSize: 16, color: getSubtitleColor(context))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: categoryController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.categoryName,
                      labelStyle: TextStyle(color: getSubtitleColor(context)),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: accentColor),
                      ),
                    ),
                    style: TextStyle(color: getTextColor(context)),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.categoryColor,
                      style: TextStyle(fontSize: 16, color: getSubtitleColor(context))),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: palette.length,
                      itemBuilder: (context, index) {
                        final color = palette[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color ? accentColor : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (categoryController.text.isNotEmpty) {
                        Navigator.pop(context, {
                          "label": categoryController.text,
                          "labelColor": selectedColor,
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(AppLocalizations.of(context)!.addCategory),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorPicker() {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: palette.length,
      itemBuilder: (context, index) {
        final color = palette[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              labelColor = color;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: labelColor == color
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<Color?> showColorPicker({
    required BuildContext context,
    required Color initialColor,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color modalBg = isDark ? Colors.black : Colors.white;
    Color selectedColor = initialColor;

    return showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: modalBg,
          title: Text('Özel Renk Seç',
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (Color color) {
                selectedColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              showLabel: true,
              paletteType: PaletteType.hsvWithHue,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('İptal',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Tamam'),
              onPressed: () {
                Navigator.of(context).pop(selectedColor);
              },
            ),
          ],
        );
      },
    );
  }

  /// Alt görev etiket seçimi
  Future<void> _selectSubTaskLabel(int index) async {
    var result = await _openLabelPicker();
    if (result != null) {
      setState(() {
        subtasks[index].label = result["label"];
        subtasks[index].labelColor = result["labelColor"];
      });
    }
  }

  Future<void> _editDuration(int index, String type) async {
    int currentDuration;
    switch (type) {
      case "pomodoro":
        currentDuration = subtasks[index].pomodoroDuration;
        break;
      case "shortBreak":
        currentDuration = subtasks[index].shortBreakDuration;
        break;
      case "longBreak":
        currentDuration = subtasks[index].longBreakDuration;
        break;
      default:
        return;
    }
    int? result = await showTimePickerDialog(context, currentDuration ~/ 60, currentDuration % 60);
    if (result != null) {
      setState(() {
        if (type == "pomodoro") {
          subtasks[index].pomodoroDuration = result;
        } else if (type == "shortBreak") {
          subtasks[index].shortBreakDuration = result;
        } else if (type == "longBreak") {
          subtasks[index].longBreakDuration = result;
        }
      });
    }
  }

  void _saveTask() {
    Task updatedTask = Task(
      title: titleController.text,
      label: label,
      labelColor: labelColor,
      longBreakFrequency: longBreakFrequency,
      subtasks: subtasks,
    );
    widget.onSave(updatedTask);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subtitleColor = isDark ? Colors.white70 : Colors.black87;
    final Color containerBg = isDark ? const Color(0xFF1C2A38) : Colors.white;
    final Color accentColor = isDark ? const Color(0xFF7FB3D5) : const Color(0xFF5DADE2);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC),
        title: Text(AppLocalizations.of(context)!.editTask, 
            style: TextStyle(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.taskTitle,
                          labelStyle: TextStyle(color: subtitleColor),
                        ),
                        style: TextStyle(color: textColor),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          var result = await _openLabelPicker();
                          if (result != null) {
                            setState(() {
                              label = result["label"];
                              labelColor = result["labelColor"];
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: containerBg,
                            border: Border.all(color: isDark ? Colors.white30 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(width: 16, height: 16, color: labelColor),
                              const SizedBox(width: 8),
                              Text(label.isEmpty ? AppLocalizations.of(context)!.selectLabel : label,
                                  style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(AppLocalizations.of(context)!.longBreak,
                              style: TextStyle(color: textColor)),
                          const SizedBox(width: 8),
                          Theme(
                            data: Theme.of(context).copyWith(
                              dropdownMenuTheme: DropdownMenuThemeData(
                                textStyle: TextStyle(color: textColor),
                              ),
                            ),
                            child: DropdownButton<int>(
                              value: longBreakFrequency,
                              dropdownColor: containerBg,
                              items: List.generate(10, (index) => index + 1)
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text("$e",
                                            style: TextStyle(color: textColor)),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  longBreakFrequency = value ?? 4;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.tasks, 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: subtasks.length,
                        itemBuilder: (context, index) {
                          SubTask sub = subtasks[index];
                          return Card(
                            color: containerBg,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: TextField(
                                controller: TextEditingController(text: sub.title),
                                decoration: _getInputDecoration(AppLocalizations.of(context)!.taskTitle, isDark),
                                onChanged: (val) {
                                  subtasks[index].title = val;
                                },
                                style: TextStyle(color: textColor),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text("${AppLocalizations.of(context)!.label}: ${sub.label}", 
                                          style: TextStyle(color: subtitleColor)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: getIconColor(context),
                                        onPressed: () => _selectSubTaskLabel(index),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${AppLocalizations.of(context)!.pomodoro}: ${sub.pomodoroDuration ~/ 60} ${AppLocalizations.of(context)!.minutes}", 
                                          style: TextStyle(color: subtitleColor)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: getIconColor(context),
                                        onPressed: () => _editDuration(index, "pomodoro"),
                                      ),
                                    ],
                                  ),
                                  (index + 1) % longBreakFrequency == 0
                                      ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${AppLocalizations.of(context)!.longBreak}: ${sub.longBreakDuration ~/ 60} ${AppLocalizations.of(context)!.minutes}", 
                                          style: TextStyle(color: subtitleColor)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: getIconColor(context),
                                        onPressed: () => _editDuration(index, "longBreak"),
                                      ),
                                    ],
                                  )
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("${AppLocalizations.of(context)!.shortBreak}: ${sub.shortBreakDuration ~/ 60} ${AppLocalizations.of(context)!.minutes}", 
                                          style: TextStyle(color: subtitleColor)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        color: getIconColor(context),
                                        onPressed: () => _editDuration(index, "shortBreak"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                color: getIconColor(context),
                                onPressed: () {
                                  setState(() {
                                    subtasks.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            subtasks.add(SubTask(
                              title: AppLocalizations.of(context)!.addTask,
                              label: AppLocalizations.of(context)!.label,
                              labelColor: Colors.grey,
                              pomodoroDuration: 25 * 60,
                              shortBreakDuration: 5 * 60,
                              longBreakDuration: 15 * 60,
                            ));
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: accentColor,
                        ),
                        child: Text(AppLocalizations.of(context)!.addTask),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _saveTask,
                  child: Text(AppLocalizations.of(context)!.save),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: isDark ? const Color(0xFF1C2A38) : const Color(0xFFF4F7FC),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Alt görev kartı içindeki TextField'lar için tema rengi
  InputDecoration _getInputDecoration(String label, bool isDark) {
    final Color accentColor = isDark ? const Color(0xFF7FB3D5) : const Color(0xFF5DADE2);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: accentColor),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
      ),
    );
  }
}

