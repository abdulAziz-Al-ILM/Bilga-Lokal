import 'package:flutter/material.dart';

import '../../core/strings.dart';

import 'folder_model.dart';
import 'folder_service.dart';

class MoveFolderResult {
  final String? parentId;

  const MoveFolderResult({required this.parentId});
}

class MoveFolderPage extends StatefulWidget {
  final Folder folder;

  const MoveFolderPage({super.key, required this.folder});

  @override
  State<MoveFolderPage> createState() => _MoveFolderPageState();
}

class _MoveFolderPageState extends State<MoveFolderPage> {
  final FolderService folderService = FolderService();

  List<Folder> folders = [];
  Set<String> blockedFolderIds = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final loadedFolders = await folderService.getAllFolders();

    final descendants = await folderService.getDescendantFolderIds(
      widget.folder.id,
    );

    if (!mounted) return;

    setState(() {
      folders = loadedFolders;

      blockedFolderIds = {widget.folder.id, ...descendants};

      isLoading = false;
    });
  }

  void selectHome() {
    Navigator.pop(context, const MoveFolderResult(parentId: null));
  }

  void selectFolder(Folder folder) {
    if (blockedFolderIds.contains(folder.id)) {
      return;
    }

    Navigator.pop(context, MoveFolderResult(parentId: folder.id));
  }

  @override
  Widget build(BuildContext context) {
    final currentParentId = widget.folder.parentId;

    return Scaffold(
      backgroundColor: const Color(0xFF071C16),

      appBar: AppBar(
        backgroundColor: const Color(0xFF071C16),
        foregroundColor: Colors.white,
        title: Text(context.tr('move')),
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
                        title: Text(
                          context.tr('home'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: currentParentId == null
                            ? const Icon(Icons.check, color: Colors.greenAccent)
                            : null,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      context.tr('folderView'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                ...folders.map((folder) {
                  final blocked = blockedFolderIds.contains(folder.id);

                  final isCurrentParent = currentParentId == folder.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Opacity(
                      opacity: blocked ? 0.35 : 1,
                      child: Material(
                        color: const Color(0xFF0D2B22),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: blocked
                              ? null
                              : () {
                                  selectFolder(folder);
                                },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF1E5A46),
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                blocked ? Icons.block : Icons.folder_outlined,
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
                              trailing: isCurrentParent
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.greenAccent,
                                    )
                                  : blocked
                                  ? const Icon(
                                      Icons.lock_outline,
                                      color: Colors.white38,
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
                  );
                }),
              ],
            ),
    );
  }
}
