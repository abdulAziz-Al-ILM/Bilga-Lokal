import 'package:flutter/material.dart';

import '../../core/strings.dart';

import 'note_database.dart';
import 'folder_model.dart';
import 'folder_service.dart';
import 'note_model.dart';
import 'note_service.dart';

class TrashFolderPage extends StatefulWidget {
  final Folder folder;

  const TrashFolderPage({super.key, required this.folder});

  @override
  State<TrashFolderPage> createState() => _TrashFolderPageState();
}

class _TrashFolderPageState extends State<TrashFolderPage> {
  final FolderService folderService = FolderService();
  final NoteService noteService = NoteService();

  List<Folder> subFolders = [];
  List<Note> notes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final allFolders = await folderService.getAllFoldersIncludingDeleted();

    final loadedSubFolders = allFolders.where((folder) {
      return folder.parentId == widget.folder.id && folder.isDeleted;
    }).toList();

    final db = await NoteDatabase.database;

    final noteMaps = await db.query(
      'notes',
      where: 'folder_id = ? AND is_deleted = ?',
      whereArgs: [widget.folder.id, 1],
      orderBy: 'updated_at DESC',
    );

    final loadedNotes = noteMaps.map((map) => Note.fromMap(map)).toList();

    if (!mounted) return;

    setState(() {
      subFolders = loadedSubFolders;
      notes = loadedNotes;
      isLoading = false;
    });
  }

  Future<void> openSubFolder(Folder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashFolderPage(folder: folder)),
    );
  }

  Future<void> viewNote(Note note) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B22),
          title: Text(
            note.title.isEmpty ? context.tr('untitled') : note.title,
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                note.body.isEmpty ? context.tr('emptyNote') : note.body,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(context.tr('close')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = subFolders.isEmpty && notes.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF071C16),

      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: Text(widget.folder.name),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5A46)),
            )
          : isEmpty
          ? Center(
              child: Text(
                context.tr('empty'),
                style: const TextStyle(color: Colors.white54, fontSize: 18),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (subFolders.isNotEmpty) ...[
                  Text(
                    context.tr('folderView'),
                    style: const TextStyle(
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
                            openSubFolder(folder);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
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
                  Text(
                    context.tr('notes'),
                    style: const TextStyle(
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
                        color: const Color(0xFF0D2B22),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            viewNote(note);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF1E5A46),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title.isEmpty
                                      ? context.tr('untitled')
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
    );
  }
}
