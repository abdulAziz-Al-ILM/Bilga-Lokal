import 'package:flutter/material.dart';

import 'create_folder_page.dart';
import 'create_note_page.dart';
import 'edit_note_page.dart';
import 'folder_model.dart';
import 'folder_service.dart';
import 'move_folder_page.dart';
import 'note_model.dart';
import 'note_service.dart';

class FolderPage extends StatefulWidget {
  final Folder folder;

  const FolderPage({super.key, required this.folder});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final FolderService folderService = FolderService();
  final NoteService noteService = NoteService();

  late Folder currentFolder;

  List<Folder> subFolders = [];
  List<Note> notes = [];
  List<Folder> folderPath = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    currentFolder = widget.folder;

    loadData();
  }

  Future<void> loadData() async {
    final loadedFolders = await folderService.getSubFolders(currentFolder.id);

    final loadedNotes = await noteService.getNotesByFolder(currentFolder.id);

    final loadedPath = await folderService.getFolderPath(currentFolder.id);

    if (!mounted) return;

    setState(() {
      subFolders = loadedFolders;
      notes = loadedNotes;
      folderPath = loadedPath;
      isLoading = false;
    });
  }

  Future<void> createSubFolder() async {
    final Folder? newFolder = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateFolderPage(parentId: currentFolder.id),
      ),
    );

    if (newFolder == null) return;

    await folderService.addFolder(newFolder);
    await loadData();
  }

  Future<void> createNote() async {
    final Note? newNote = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateNotePage(folderId: currentFolder.id),
      ),
    );

    if (newNote == null) return;

    await loadData();
  }

  Future<void> openFolder(Folder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderPage(folder: folder)),
    );

    await loadData();
  }

  Future<void> editNote(Note note) async {
    final Note? updatedNote = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditNotePage(note: note)),
    );

    if (updatedNote == null) return;

    await loadData();
  }

  Future<void> renameFolder() async {
    final controller = TextEditingController(text: currentFolder.name);

    final String? newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B22),
          title: const Text(
            'Papka nomini o‘zgartirish',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'Papka nomi',
              hintStyle: TextStyle(color: Colors.white38),
            ),
            onSubmitted: (value) {
              final name = value.trim();

              if (name.isEmpty) return;

              Navigator.pop(dialogContext, name);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Bekor qilish'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();

                if (name.isEmpty) return;

                Navigator.pop(dialogContext, name);
              },
              child: const Text('Saqlash'),
            ),
          ],
        );
      },
    );

    if (newName == null) return;

    if (newName == currentFolder.name) return;

    final renamedFolder = currentFolder.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );

    await folderService.updateFolder(renamedFolder);

    if (!mounted) return;

    setState(() {
      currentFolder = renamedFolder;
    });

    await loadData();
  }

  Future<void> moveFolder() async {
    final MoveFolderResult? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MoveFolderPage(folder: currentFolder)),
    );

    if (result == null) {
      return;
    }

    if (result.parentId == currentFolder.parentId) {
      return;
    }

    final moved = await folderService.moveFolder(
      currentFolder,
      result.parentId,
    );

    if (!mounted) return;

    if (!moved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu folderni tanlangan joyga ko‘chirib bo‘lmaydi.'),
        ),
      );

      return;
    }

    Navigator.pop(context);
  }

  Future<void> moveFolderToTrash() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B22),
          title: const Text(
            'Savatga yuborish',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '"${currentFolder.name}" papkasi va uning ichidagi barcha yozuv va ichki papkalar savatga yuboriladi.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Bekor qilish'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Savatga yuborish',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await folderService.moveFolderTreeToTrash(currentFolder);

    if (!mounted) return;

    Navigator.pop(context);
  }

  void goToHome() {
    final navigator = Navigator.of(context);

    for (int i = 0; i < folderPath.length; i++) {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  void goToFolderInPath(int index) {
    final stepsBack = folderPath.length - 1 - index;

    if (stepsBack <= 0) {
      return;
    }

    final navigator = Navigator.of(context);

    for (int i = 0; i < stepsBack; i++) {
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  Widget buildBreadcrumb() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: goToHome,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.home_outlined, size: 16, color: Colors.white54),
                  SizedBox(width: 4),
                  Text(
                    'Bosh sahifa',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          for (int i = 0; i < folderPath.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 16, color: Colors.white30),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: i == folderPath.length - 1
                  ? null
                  : () {
                      goToFolderInPath(i);
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  folderPath[i].name,
                  style: TextStyle(
                    color: i == folderPath.length - 1
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 13,
                    fontWeight: i == folderPath.length - 1
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2B22),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.note_add_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Yangi yozuv',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    createNote();
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
                    Navigator.pop(context);
                    createSubFolder();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Folderni ko‘chirish',
            onPressed: moveFolder,
            icon: const Icon(Icons.drive_file_move_outline),
          ),
          IconButton(
            tooltip: 'Savatga yuborish',
            onPressed: moveFolderToTrash,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5A46)),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: buildBreadcrumb(),
                ),
                Expanded(
                  child: subFolders.isEmpty && notes.isEmpty
                      ? const Center(
                          child: Text(
                            'Bu folder hali bo‘sh',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (subFolders.isNotEmpty) ...[
                              const Text(
                                'Papkalar',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...subFolders.map(
                                (folder) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: const Color(0xFF0D2B22),
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        openFolder(folder);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF1E5A46),
                                          ),
                                        ),
                                        child: ListTile(
                                          leading: const Icon(
                                            Icons.folder_outlined,
                                            color: Colors.white70,
                                          ),
                                          title: Text(
                                            folder.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          trailing: const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],

                            if (notes.isNotEmpty) ...[
                              const Text(
                                'Notes',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...notes.map(
                                (note) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        editNote(note);
                                      },
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D2B22),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF1E5A46),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              note.title.isEmpty
                                                  ? 'Sarlavhasiz yozuv'
                                                  : note.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (note.body.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                note.body,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E5A46),
        foregroundColor: Colors.white,
        onPressed: showCreateMenu,
        child: const Icon(Icons.add),
      ),
    );
  }
}
