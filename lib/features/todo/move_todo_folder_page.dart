import 'package:flutter/material.dart';

import '../../core/strings.dart';

import 'todo_folder_model.dart';
import 'todo_folder_service.dart';

class MoveTodoFolderResult {
  final String? parentId;

  const MoveTodoFolderResult({required this.parentId});
}

class MoveTodoFolderPage extends StatefulWidget {
  final TodoFolder folder;

  const MoveTodoFolderPage({super.key, required this.folder});

  @override
  State<MoveTodoFolderPage> createState() => _MoveTodoFolderPageState();
}

class _MoveTodoFolderPageState extends State<MoveTodoFolderPage> {
  final TodoFolderService folderService = TodoFolderService();

  List<TodoFolder> folders = [];
  Set<String> blockedIds = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final allFolders = await folderService.getAllFolders();

    final descendants = getDescendantIds(widget.folder.id, allFolders);

    if (!mounted) return;

    setState(() {
      folders = allFolders;

      blockedIds = {widget.folder.id, ...descendants};

      isLoading = false;
    });
  }

  Set<String> getDescendantIds(String folderId, List<TodoFolder> allFolders) {
    final result = <String>{};

    void collect(String parentId) {
      final children = allFolders.where(
        (folder) => folder.parentId == parentId,
      );

      for (final child in children) {
        if (result.add(child.id)) {
          collect(child.id);
        }
      }
    }

    collect(folderId);

    return result;
  }

  void selectHome() {
    Navigator.pop(context, const MoveTodoFolderResult(parentId: null));
  }

  void selectFolder(TodoFolder folder) {
    if (blockedIds.contains(folder.id)) {
      return;
    }

    Navigator.pop(context, MoveTodoFolderResult(parentId: folder.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: Text(context.tr('move')),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: selectHome,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2B22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.folder.parentId == null
                              ? Colors.green
                              : const Color(0xFF1E5A46),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.tr('home'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.folder.parentId == null)
                            const Icon(Icons.check, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...folders.map((folder) {
                  final blocked = blockedIds.contains(folder.id);

                  final isCurrentParent = widget.folder.parentId == folder.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: blocked ? 0.35 : 1,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: blocked
                              ? null
                              : () {
                                  selectFolder(folder);
                                },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2B22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isCurrentParent
                                    ? Colors.green
                                    : const Color(0xFF1E5A46),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  blocked
                                      ? Icons.lock_outline
                                      : Icons.folder_outlined,
                                  color: blocked
                                      ? Colors.white38
                                      : Colors.amber,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    folder.name,
                                    style: TextStyle(
                                      color: blocked
                                          ? Colors.white38
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isCurrentParent)
                                  const Icon(Icons.check, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
