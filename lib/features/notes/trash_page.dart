import 'package:flutter/material.dart';

import '../../core/strings.dart';

import 'folder_model.dart';
import 'folder_service.dart';
import 'note_model.dart';
import 'note_service.dart';
import 'trash_folder_page.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final NoteService noteService = NoteService();
  final FolderService folderService = FolderService();

  List<Note> deletedNotes = [];
  List<Folder> deletedFolders = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTrash();
  }

  Future<void> loadTrash() async {
    final loadedNotes = await noteService.getDeletedNotes();

    final loadedFolders = await folderService.getDeletedRootFolders();

    if (!mounted) return;

    setState(() {
      deletedNotes = loadedNotes;
      deletedFolders = loadedFolders;
      isLoading = false;
    });
  }

  Future<void> openDeletedFolder(Folder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TrashFolderPage(folder: folder)),
    );

    await loadTrash();
  }

  Future<void> restoreNote(Note note) async {
    await noteService.restoreNote(note);
    await loadTrash();
  }

  Future<void> deleteNoteForever(Note note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B22),
          title: Text(
            context.tr('deleteForever'),
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${note.title.isEmpty ? context.tr('untitled') : note.title}\n\n${context.tr('permanentConfirm')}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                context.tr('deleteForever'),
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await noteService.deleteForever(note.id);
    await loadTrash();
  }

  Future<void> restoreFolder(Folder folder) async {
    await folderService.restoreFolderTree(folder);
    await loadTrash();
  }

  Future<void> deleteFolderForever(Folder folder) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D2B22),
          title: Text(
            context.tr('deleteForever'),
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            '${folder.name}\n\n${context.tr('permanentConfirm')}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                context.tr('deleteForever'),
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await folderService.deleteFolderTreeForever(folder);
    await loadTrash();
  }

  @override
  Widget build(BuildContext context) {
    final trashIsEmpty = deletedFolders.isEmpty && deletedNotes.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF071C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: Text(context.tr('trash')),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5A46)),
            )
          : trashIsEmpty
          ? Center(
              child: Text(
                context.tr('empty'),
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (deletedFolders.isNotEmpty) ...[
                  Text(
                    context.tr('folderView'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ...deletedFolders.map(
                    (folder) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: const Color(0xFF0D2B22),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            openDeletedFolder(folder);
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
                                Icons.folder_delete_outlined,
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
                              subtitle: Text(
                                context.tr('openFolderHint'),
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: context.tr('restore'),
                                    onPressed: () {
                                      restoreFolder(folder);
                                    },
                                    icon: const Icon(
                                      Icons.restore,
                                      color: Colors.greenAccent,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.tr('deleteForever'),
                                    onPressed: () {
                                      deleteFolderForever(folder);
                                    },
                                    icon: const Icon(
                                      Icons.delete_forever_outlined,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (deletedNotes.isNotEmpty) const SizedBox(height: 14),
                ],

                if (deletedNotes.isNotEmpty) ...[
                  Text(
                    context.tr('notes'),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ...deletedNotes.map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: const Color(0xFF0D2B22),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E5A46)),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.note_outlined,
                              color: Colors.white70,
                            ),
                            title: Text(
                              note.title.isEmpty
                                  ? context.tr('untitled')
                                  : note.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: note.body.isEmpty
                                ? null
                                : Text(
                                    note.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: context.tr('restore'),
                                  onPressed: () {
                                    restoreNote(note);
                                  },
                                  icon: const Icon(
                                    Icons.restore,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.tr('deleteForever'),
                                  onPressed: () {
                                    deleteNoteForever(note);
                                  },
                                  icon: const Icon(
                                    Icons.delete_forever_outlined,
                                    color: Colors.redAccent,
                                  ),
                                ),
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
