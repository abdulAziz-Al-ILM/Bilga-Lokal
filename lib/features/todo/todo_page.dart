import '../collections/collection_page.dart';
import '../collections/collection_repository.dart';

class TodoPage extends CollectionPage {
  const TodoPage({super.key, super.tutorial})
    : super(kind: CollectionKind.todos);
}
