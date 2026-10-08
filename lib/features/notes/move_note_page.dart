import 'package:flutter/material.dart';

import 'folder_model.dart';
import 'folder_service.dart';

class MoveNoteResult {
  final String? folderId;

  const MoveNoteResult({required this.folderId});
}

class MoveNotePage extends StatefulWidget {
  final String? currentFolderId;

  const MoveNotePage({super.key, this.currentFolderId});

  @override
  State<MoveNotePage> createState() => _MoveNotePageState();
}

class _MoveNotePageState extends State<MoveNotePage> {
  final FolderService folderService = FolderService();

  List<Folder> folders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFolders();
  }

  Future<void> loadFolders() async {
    final loadedFolders = await folderService.getAllFolders();

    if (!mounted) return;

    setState(() {
      folders = loadedFolders;
      isLoading = false;
    });
  }

  void selectHome() {
    Navigator.pop(context, const MoveNoteResult(folderId: null));
  }

  void selectFolder(Folder folder) {
    Navigator.pop(context, MoveNoteResult(folderId: folder.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: const Text('Note ko‘chirish'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5A46)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Material(
                  color: const Color(0xFF0D2B22),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: selectHome,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E5A46)),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.home_outlined,
                          color: Colors.white70,
                        ),
                        title: const Text(
                          'Bosh sahifa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: widget.currentFolderId == null
                            ? const Icon(Icons.check, color: Colors.greenAccent)
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (folders.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Papkalar',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ...folders.map(
                  (folder) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: const Color(0xFF0D2B22),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          selectFolder(folder);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E5A46)),
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
                            trailing: widget.currentFolderId == folder.id
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.greenAccent,
                                  )
                                : const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
