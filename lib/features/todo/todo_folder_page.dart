import 'dart:async';

import 'todo_status_indicator.dart';

import 'package:flutter/material.dart';

import 'create_todo_folder_page.dart';
import 'move_todo_folder_page.dart';
import 'todo_folder_model.dart';
import 'todo_folder_service.dart';
import 'todo_model.dart';
import 'todo_service.dart';

class TodoFolderPage extends StatefulWidget {
  final TodoFolder folder;

  const TodoFolderPage({super.key, required this.folder});

  @override
  State<TodoFolderPage> createState() => _TodoFolderPageState();
}

class _TodoFolderPageState extends State<TodoFolderPage> {
  final TodoService todoService = TodoService();
  final TodoFolderService folderService = TodoFolderService();

  late TodoFolder currentFolder;

  List<Todo> todos = [];
  List<TodoFolder> subFolders = [];

  bool isLoading = true;

  Timer? animationTimer;

  @override
  void initState() {
    super.initState();

    currentFolder = widget.folder;

    loadData();

    animationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    animationTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    final loadedTodos = await todoService.getTodosByFolder(currentFolder.id);

    final loadedFolders = await folderService.getSubFolders(currentFolder.id);

    if (!mounted) return;

    setState(() {
      todos = loadedTodos;
      subFolders = loadedFolders;
      isLoading = false;
    });
  }

  Future<void> renameFolder() async {
    final controller = TextEditingController(text: currentFolder.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Papka nomini o‘zgartirish'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Papka nomi'),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Saqlash'),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.isEmpty) return;
    if (newName == currentFolder.name) return;

    await folderService.renameFolder(currentFolder, newName);

    if (!mounted) return;

    setState(() {
      currentFolder = currentFolder.copyWith(
        name: newName,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<void> moveFolder() async {
    final result = await Navigator.push<MoveTodoFolderResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MoveTodoFolderPage(folder: currentFolder),
      ),
    );

    if (result == null) return;

    if (result.parentId == currentFolder.parentId) {
      return;
    }

    await folderService.moveFolder(currentFolder, result.parentId);

    if (!mounted) return;

    currentFolder = currentFolder.copyWith(
      parentId: result.parentId,
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context);
  }

  Future<void> openAddMenu() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0D2B22),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
                title: const Text(
                  'Yangi vazifa',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context, 'todo');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.create_new_folder_outlined,
                  color: Colors.white,
                ),
                title: const Text(
                  'Yangi papka',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context, 'folder');
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == 'todo') {
      await addTodo();
    }

    if (result == 'folder') {
      await createFolder();
    }
  }

  Future<void> createFolder() async {
    final folder = await Navigator.push<TodoFolder>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTodoFolderPage(parentId: currentFolder.id),
      ),
    );

    if (folder == null) return;

    await folderService.addFolder(folder);
    await loadData();
  }

  Future<DateTime?> chooseDueDateTime({DateTime? initialDateTime}) async {
    final now = DateTime.now();
    final initial = initialDateTime ?? now;

    final date = await showDatePicker(
      context: context,
      helpText: 'Sanani tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );

    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Vaqtni tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<TodoPriority?> choosePriority({TodoPriority? currentPriority}) async {
    return showDialog<TodoPriority>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Muhimlik darajasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              priorityOption(
                context,
                TodoPriority.normal,
                'Oddiy',
                const Color(0xFF4CAF50),
                currentPriority,
              ),
              priorityOption(
                context,
                TodoPriority.important,
                'Muhim',
                const Color(0xFFFFC107),
                currentPriority,
              ),
              priorityOption(
                context,
                TodoPriority.veryImportant,
                'Juda muhim',
                const Color(0xFFFF9800),
                currentPriority,
              ),
              priorityOption(
                context,
                TodoPriority.critical,
                'Kritik',
                const Color(0xFFF44336),
                currentPriority,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget priorityOption(
    BuildContext context,
    TodoPriority priority,
    String label,
    Color color,
    TodoPriority? currentPriority,
  ) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(label),
      trailing: currentPriority == priority ? const Icon(Icons.check) : null,
      onTap: () {
        Navigator.pop(context, priority);
      },
    );
  }

  Future<void> addTodo() async {
    final controller = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yangi vazifa'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Vazifa nomi'),
            onSubmitted: (value) {
              Navigator.pop(context, value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Keyingi'),
            ),
          ],
        );
      },
    );

    if (title == null || title.isEmpty) return;

    final priority = await choosePriority();

    if (priority == null || !mounted) return;

    final dueAt = await chooseDueDateTime();

    if (!mounted) return;

    final now = DateTime.now();

    final todo = Todo(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      isDone: false,
      priority: priority,
      dueAt: dueAt,
      folderId: currentFolder.id,
      createdAt: now,
      updatedAt: now,
    );

    await todoService.addTodo(todo);
    await loadData();
  }

  Future<void> editTodo(Todo todo) async {
    final controller = TextEditingController(text: todo.title);

    TodoPriority priority = todo.priority;
    DateTime? dueAt = todo.dueAt;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Vazifani tahrirlash'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Vazifa nomi',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Muhimlik',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final selected = await choosePriority(
                          currentPriority: priority,
                        );

                        if (selected == null) return;

                        setDialogState(() {
                          priority = selected;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: priorityColor(priority)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: priorityColor(priority),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(priorityText(priority)),
                            const Spacer(),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Muddat',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final selected = await chooseDueDateTime(
                          initialDateTime: dueAt,
                        );

                        if (selected == null) return;

                        setDialogState(() {
                          dueAt = selected;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dueAt == null
                                    ? 'Muddat yo‘q'
                                    : formatDateTime(dueAt!),
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Bekor qilish'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Text('Saqlash'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final title = controller.text.trim();

    if (title.isEmpty) return;

    final updatedTodo = todo.copyWith(
      title: title,
      priority: priority,
      dueAt: dueAt,
      updatedAt: DateTime.now(),
    );

    await todoService.updateTodo(updatedTodo);
    await loadData();
  }

  Future<void> toggleTodo(Todo todo) async {
    await todoService.toggleTodo(todo);
    await loadData();
  }

  Future<void> postponeTodo(Todo todo) async {
    final newDueAt = await chooseDueDateTime(initialDateTime: todo.dueAt);

    if (newDueAt == null) return;

    final updatedTodo = todo.copyWith(
      dueAt: newDueAt,
      updatedAt: DateTime.now(),
    );

    await todoService.updateTodo(updatedTodo);
    await loadData();
  }

  Future<void> confirmDeleteTodo(Todo todo) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vazifani o‘chirish'),
          content: Text('"${todo.title}" vazifasini o‘chirmoqchimisiz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('O‘chirish'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    await todoService.deleteTodo(todo.id);
    await loadData();
  }

  bool isOverdue(Todo todo) {
    if (todo.isDone) return false;
    if (todo.dueAt == null) return false;

    return todo.dueAt!.isBefore(DateTime.now());
  }

  Duration remaining(Todo todo) {
    if (todo.dueAt == null) {
      return Duration.zero;
    }

    return todo.dueAt!.difference(DateTime.now());
  }

  Color priorityColor(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.normal:
        return const Color(0xFF4CAF50);
      case TodoPriority.important:
        return const Color(0xFFFFC107);
      case TodoPriority.veryImportant:
        return const Color(0xFFFF9800);
      case TodoPriority.critical:
        return const Color(0xFFF44336);
    }
  }

  String priorityText(TodoPriority priority) {
    switch (priority) {
      case TodoPriority.normal:
        return 'Oddiy';
      case TodoPriority.important:
        return 'Muhim';
      case TodoPriority.veryImportant:
        return 'Juda muhim';
      case TodoPriority.critical:
        return 'Kritik';
    }
  }

  int blinkSpeed(Todo todo) {
    if (todo.dueAt == null) {
      return 0;
    }

    final diff = remaining(todo);

    if (diff.isNegative) {
      return 1000;
    }

    if (diff <= const Duration(seconds: 5)) {
      final ms = diff.inMilliseconds.clamp(0, 5000);
      final progress = 1 - (ms / 5000);

      return (500 - (380 * progress)).clamp(120, 500).round();
    }

    if (diff <= const Duration(minutes: 5)) {
      return 600;
    }

    if (diff <= const Duration(hours: 1)) {
      return 950;
    }

    if (diff <= const Duration(hours: 24)) {
      return 1500;
    }

    return 2200;
  }

  Widget buildStatus(Todo todo) {
    if (todo.isDone) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 22),
      );
    }

    if (todo.dueAt == null) {
      final color = priorityColor(todo.priority);

      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    final overdue = isOverdue(todo);
    final interval = blinkSpeed(todo);

    return TodoStatusIndicator(
      key: ValueKey('status-${todo.id}'),
      interval: interval,
      overdue: overdue,
      color: overdue ? const Color(0xFFB71C1C) : priorityColor(todo.priority),
    );
  }

  String formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final year = dateTime.year;

    final hour = dateTime.hour.toString().padLeft(2, '0');

    final minute = dateTime.minute.toString().padLeft(2, '0');

    final second = dateTime.second.toString().padLeft(2, '0');

    return '$day.$month.$year  $hour:$minute:$second';
  }

  String formatDuration(Duration duration) {
    final value = duration.abs();

    final days = value.inDays;
    final hours = value.inHours.remainder(24);
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);

    final parts = <String>[];

    if (days > 0) {
      parts.add('$days kun');
    }

    if (hours > 0 || days > 0) {
      parts.add('$hours soat');
    }

    if (minutes > 0 || hours > 0 || days > 0) {
      parts.add('$minutes daqiqa');
    }

    parts.add('$seconds soniya');

    return parts.join(' ');
  }

  Widget buildFolderCard(TodoFolder folder) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TodoFolderPage(folder: folder)),
          );

          await loadData();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E5A46)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, color: Colors.amber, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  folder.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTodoCard(Todo todo) {
    final overdue = isOverdue(todo);
    final timeLeft = remaining(todo);
    final color = priorityColor(todo.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          editTodo(todo);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2B22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: overdue
                  ? const Color(0xFFB71C1C)
                  : color.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: Center(child: buildStatus(todo)),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Checkbox(
                        value: todo.isDone,
                        onChanged: (_) {
                          toggleTodo(todo);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        color: todo.isDone ? Colors.white54 : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: todo.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      priorityText(todo.priority),
                      style: TextStyle(
                        color: todo.isDone ? Colors.white38 : color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Qo‘yildi: ${formatDateTime(todo.createdAt)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    if (todo.dueAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Bajarish: ${formatDateTime(todo.dueAt!)}',
                        style: TextStyle(
                          color: overdue ? Colors.redAccent : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      if (!todo.isDone) ...[
                        const SizedBox(height: 4),
                        Text(
                          overdue
                              ? 'Kechikdi: ${formatDuration(timeLeft)}'
                              : 'Qoldi: ${formatDuration(timeLeft)}',
                          style: TextStyle(
                            color: overdue ? Colors.redAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                    if (overdue) ...[
                      const SizedBox(height: 9),
                      OutlinedButton.icon(
                        onPressed: () {
                          postponeTodo(todo);
                        },
                        icon: const Icon(Icons.update, size: 18),
                        label: const Text('Kechiktirish'),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  confirmDeleteTodo(todo);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E5A46),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTodos = todos.where((todo) => !todo.isDone).toList();

    final completedTodos = todos.where((todo) => todo.isDone).toList();

    final hasContent =
        subFolders.isNotEmpty ||
        activeTodos.isNotEmpty ||
        completedTodos.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF071C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: Text(currentFolder.name),
        actions: [
          IconButton(
            tooltip: 'Nomini o‘zgartirish',
            onPressed: renameFolder,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Ko‘chirish',
            onPressed: moveFolder,
            icon: const Icon(Icons.drive_file_move_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E5A46),
        foregroundColor: Colors.white,
        onPressed: openAddMenu,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasContent
          ? const Center(
              child: Text(
                'Bu papka hozircha bo‘sh',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (subFolders.isNotEmpty) ...[
                  buildSectionTitle('Papkalar', subFolders.length),
                  ...subFolders.map(
                    (folder) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildFolderCard(folder),
                    ),
                  ),
                ],
                if (activeTodos.isNotEmpty) ...[
                  buildSectionTitle('Faol vazifalar', activeTodos.length),
                  ...activeTodos.map(
                    (todo) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildTodoCard(todo),
                    ),
                  ),
                ],
                if (completedTodos.isNotEmpty) ...[
                  buildSectionTitle('Bajarilganlar', completedTodos.length),
                  ...completedTodos.map(
                    (todo) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildTodoCard(todo),
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
