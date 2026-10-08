import 'package:flutter/material.dart';

import 'todo_folder_model.dart';

class CreateTodoFolderPage extends StatefulWidget {
  final String? parentId;

  const CreateTodoFolderPage({super.key, this.parentId});

  @override
  State<CreateTodoFolderPage> createState() => _CreateTodoFolderPageState();
}

class _CreateTodoFolderPageState extends State<CreateTodoFolderPage> {
  final TextEditingController controller = TextEditingController();

  void createFolder() {
    final name = controller.text.trim();

    if (name.isEmpty) return;

    final now = DateTime.now();

    final folder = TodoFolder(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      parentId: widget.parentId,
      createdAt: now,
      updatedAt: now,
    );

    Navigator.pop(context, folder);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: const Text('Yangi papka'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Papka nomi',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E5A46)),
                ),
              ),
              onSubmitted: (_) {
                createFolder();
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: createFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Papka yaratish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
