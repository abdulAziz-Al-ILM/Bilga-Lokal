import '../search/library_page.dart';

/// Source-linked local lookup; never generates personal facts or changes data.
class AgentPage extends LibraryPage {
  const AgentPage({super.key}) : super(assistant: true);
}
