import 'package:flutter/material.dart';

import 'folder_model.dart';

class CreateFolderPage extends StatefulWidget {
  final String? parentId;

  const CreateFolderPage({super.key, this.parentId});

  @override
  State<CreateFolderPage> createState() => _CreateFolderPageState();
}

class _CreateFolderPageState extends State<CreateFolderPage> {
  final TextEditingController nameController = TextEditingController();

  void saveFolder() {
    final name = nameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    final now = DateTime.now();

    final folder = Folder(
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
    nameController.dispose();
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
        actions: [
          IconButton(
            tooltip: 'Saqlash',
            onPressed: saveFolder,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            hintText: 'Papka nomi',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onSubmitted: (_) {
            saveFolder();
          },
        ),
      ),
    );
  }
}
