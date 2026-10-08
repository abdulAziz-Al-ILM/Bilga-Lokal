import 'package:flutter_test/flutter_test.dart';
import 'package:bilga/features/agent/agent_command.dart';

void main() {
  test('Three languages, punctuation and Uzbek action suffix', () {
    expect(
      parseAgentCommand('create note: Shopping | Milk').argument,
      'Shopping | Milk',
    );
    expect(
      parseAgentCommand('создай задачу: Позвонить').action,
      AgentAction.task,
    );
    expect(
      parseAgentCommand('kitob o‘qish deb odat yarat').action,
      AgentAction.habit,
    );
    expect(
      parseAgentCommand('Qo‘ng‘iroq qil: +998901234567').action,
      AgentAction.call,
    );
    expect(parseAgentCommand('  READ TASKS  ').action, AgentAction.tasks);
  });
  test('Unknown commands never become mutations', () {
    expect(parseAgentCommand('delete all notes').action, AgentAction.unknown);
    expect(parseAgentCommand('noteworthy').action, AgentAction.unknown);
    expect(
      parseAgentCommand('create note: delete all tasks').action,
      AgentAction.note,
    );
    expect(
      parseAgentCommand('create note: delete all tasks').argument,
      'delete all tasks',
    );
  });
  test('SMS, USSD and URI injection boundaries', () {
    expect(safePhone('+998 (90) 123-45-67'), '+998901234567');
    expect(safePhone('*123#'), isNull);
    expect(safePhone('123?body=secret'), isNull);
    expect(safePhone('Mom'), isNull);
    expect(
      parseAgentCommand('sms: +998901234567 | Hello').action,
      AgentAction.sms,
    );
  });
}
