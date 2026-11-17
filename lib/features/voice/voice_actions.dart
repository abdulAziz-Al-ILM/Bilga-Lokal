import 'voice_book_picker.dart';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/strings.dart';
import '../../core/dialogs.dart';
import '../../core/editor_form.dart';
import '../agent/agent_access.dart';
import '../private_space/record_store.dart';
import '../private_space/space_page.dart' show RecordPage;
import '../notes/note_model.dart';
import '../notes/note_service.dart';
import '../notes/note_editor_page.dart';
import '../todo/todo_editor_page.dart';
import '../search/library_page.dart';
import '../search/search_repository.dart';
import '../habits/habit_store.dart';
import '../habits/habit_statistics_page.dart';
import '../finance/finance_page.dart';
import '../finance/ledger.dart';
import '../finance/account_ledger.dart';
import '../experiences/experience_editor.dart';
import '../experiences/experience_model.dart';
import '../experiences/experience_store.dart';
import '../experiences/experience_page.dart';
import '../books/book_library_store.dart';
import '../books/reading/book_reading_page.dart';
import '../books/reading/reading_store.dart';
import '../books/reading/reading_hub.dart';
import 'voice_command.dart';

/// Uses existing validation, repositories and navigation. It never executes an
/// unreviewed transcript, guesses a matching personal record, or invents money.
class VoiceActions {
  final Database? notesDb, tasksDb;
  final AgentAccess access;
  VoiceActions({this.notesDb, this.tasksDb, AgentAccess? access})
    : access = access ?? AgentAccess.instance;
  RecordStore get records => RecordStore(database: notesDb);
  void require({bool finance = false}) {
    if (!access.has(finance ? AgentAccess.finance : AgentAccess.core)) {
      throw StateError('access_expired');
    }
  }

  Future<void> page(BuildContext c, Widget page) =>
      Navigator.push<void>(c, MaterialPageRoute(builder: (_) => page));
  Future<String?> choose(
    BuildContext c,
    String title,
    Map<String, String> options,
  ) => showDialog<String>(
    context: c,
    builder: (c) => SimpleDialog(
      title: Text(title),
      children: [
        for (final e in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, e.key),
            child: Text(e.value),
          ),
      ],
    ),
  );
  Future<void> execute(BuildContext c, VoiceCommand command) async {
    final argument = command.argument;
    switch (command.action) {
      case VoiceAction.findNotes:
      case VoiceAction.findFinance:
      case VoiceAction.search:
        await page(
          c,
          LibraryPage(
            repository: SearchRepository(notesDb: notesDb, todoDb: tasksDb),
            initialQuery: argument,
            initialKind: command.action == VoiceAction.findNotes
                ? 'note'
                : command.action == VoiceAction.findFinance
                ? 'finance'
                : null,
            assistant: true,
          ),
        );
      case VoiceAction.note:
        await note(c, argument);
      case VoiceAction.task:
      case VoiceAction.reminder:
        await task(c, argument, command.action == VoiceAction.reminder);
      case VoiceAction.completeHabit:
        await habit(c, argument);
      case VoiceAction.expense:
      case VoiceAction.income:
        await finance(
          c,
          argument,
          command.action == VoiceAction.expense ? 'expense' : 'income',
        );
      case VoiceAction.experience:
        await experience(c, argument);
      case VoiceAction.openBook:
      case VoiceAction.continueBook:
      case VoiceAction.card:
        await book(c, argument, command.action);
      case VoiceAction.unknown:
        throw StateError('voice_unknown');
    }
  }

  Future<void> note(BuildContext c, String text) async {
    require();
    final service = NoteService(database: notesDb);
    Note? saved;
    final id = localId();
    await editFields(
      c,
      c.tr('newNote'),
      {'title': c.tr('title'), 'body': c.tr('write')},
      initial: {'title': text.length <= 200 ? text : '', 'body': text},
      multiline: {'body'},
      requiredFields: {'title'},
      onSave: (v) async {
        require();
        final now = DateTime.now();
        final draft = Note(
          id: id,
          title: v['title']!.trim(),
          body: v['body']!,
          createdAt: now,
          updatedAt: now,
        );
        await service.addNote(draft);
        saved = draft;
      },
    );
    if (saved != null && c.mounted) {
      await page(c, NoteEditorPage(note: saved, service: service));
    }
  }

  Future<void> task(BuildContext c, String text, bool reminder) async {
    require();
    final parsed = VoiceWhen.parse(text, DateTime.now());
    DateTime? at = parsed.at;
    if (reminder && at == null) {
      final now = DateTime.now();
      final date =
          parsed.date ??
          await showDatePicker(
            context: c,
            initialDate: now,
            firstDate: DateUtils.dateOnly(now),
            lastDate: DateTime(2200),
          );
      if (date == null || !c.mounted) return;
      final time = parsed.minute == null
          ? await showTimePicker(context: c, initialTime: TimeOfDay.now())
          : TimeOfDay(hour: parsed.minute! ~/ 60, minute: parsed.minute! % 60);
      if (time == null || !c.mounted) return;
      at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }
    if (!c.mounted) return;
    final title = parsed.remainder;
    await page(
      c,
      TodoEditorPage(
        database: tasksDb,
        initialTitle: title.length <= 200 ? title : '',
        initialDescription: title.length > 200 ? title : '',
        initialDue: at,
        initialReminder: reminder ? at : null,
      ),
    );
  }

  Future<void> habit(BuildContext c, String query) async {
    require();
    final store = HabitStore(provided: notesDb),
        all = await HabitStore(provided: notesDb).all();
    if (!c.mounted) return;
    final needle = VoiceCommand.normalize(query).toLowerCase();
    final matches = all
        .where(
          (h) =>
              needle.isEmpty ||
              VoiceCommand.normalize(h.title).toLowerCase().contains(needle),
        )
        .toList();
    if (matches.isEmpty) {
      showError(c, 'voiceNoMatch');
      return;
    }
    final selected = await choose(c, c.tr('voiceChooseHabit'), {
      for (final h in matches) h.id: h.title,
    });
    if (selected == null || !c.mounted) return;
    final h = await store.get(selected);
    if (!c.mounted) return;
    final today = DateTime.now();
    if (h.plan.done(today, h.days)) {
      showError(c, 'voiceHabitAlreadyDone');
      return;
    }
    if (!await confirm(
          c,
          '${h.title}\n${dayKey(today)} · ${h.plan.targetAt(today)} ${h.plan.unit}',
          title: c.tr('voiceConfirmHabit'),
        ) ||
        !c.mounted) {
      return;
    }
    require();
    await store.mark(h.id, today, true);
    if (c.mounted) {
      await page(
        c,
        HabitStatisticsPage(store: store, habitId: h.id, access: access),
      );
    }
  }

  Future<void> finance(BuildContext c, String text, String type) async {
    require(finance: true);
    final when = VoiceWhen.parse(text, DateTime.now());
    final money = VoiceMoney.extract(when.remainder);
    final ledgers = (await records.all('finance'))
        .where(
          (r) => money.currency == null || r.data['currency'] == money.currency,
        )
        .toList();
    if (!c.mounted) return;
    if (ledgers.isEmpty) {
      showError(c, 'voiceNeedLedger');
      await page(c, FinancePage(store: records, access: access));
      return;
    }
    final ledgerId = await choose(c, c.tr('voiceChooseLedger'), {
      for (final r in ledgers)
        r.id: '${r.data['title']} · ${r.data['currency']}',
    });
    if (ledgerId == null || !c.mounted) return;
    final ledger = await records.get(ledgerId),
        currency = ledger.data['currency'] as String;
    final accounts = AccountLedger.accounts(ledger.data)
        .where((a) => a['archived'] != true)
        .toList();
    if (accounts.isEmpty) {
      if (c.mounted) showError(c, 'fAccountNeedActive');
      return;
    }
    if (!c.mounted) return;
    final accountId = await choose(c, c.tr('fAccounts'), {
      for (final a in accounts) a['id']: a['name'],
    });
    if (accountId == null || !c.mounted) return;
    final id = localId();
    String amount = '';
    if (money.number != null) {
      try {
        parseMoney(money.number!, currency);
        amount = money.number!;
      } catch (_) {
        /* Ambiguous/invalid amounts require correction. */
      }
    }
    await editFields(
      c,
      c.tr('x$type'),
      {
        'amount': '${c.tr('xAmount')} ($currency)',
        'date': c.tr('xDate'),
        'category': c.tr('xCategory'),
        'description': c.tr('description'),
      },
      initial: {
        'amount': amount,
        'date': ExperienceModel.day(when.date ?? DateTime.now()),
        'description': money.remainder,
      },
      requiredFields: {'amount', 'date'},
      numberFields: {'amount'},
      dateFields: {'date'},
      multiline: {'description'},
      onSave: (v) async {
        require(finance: true);
        final latest = await records.get(ledgerId);
        Ledger.validate(latest.data);
        if (latest.data['currency'] != currency) {
          throw StateError('currency_changed');
        }
        final account = AccountLedger.accounts(latest.data)
            .singleWhere((a) => a['id'] == accountId && a['archived'] != true);
        final n = parseMoney(v['amount']!, currency);
        if (!c.mounted) throw const EditorSaveCancelled();
        if (!await confirm(
          c,
          '${latest.data['title']} · ${account['name']}\n${c.tr('x$type')} · ${moneyText(n, currency)}\n${v['date']}\n${v['category']}\n${v['description']}',
          title: c.tr('voiceConfirmFinance'),
        )) {
          throw const EditorSaveCancelled();
        }
        require(finance: true);
        if ((latest.data['entries'] as List).any((e) => e['id'] == id)) {
          throw StateError('already_saved');
        }
        await records.save('finance', {
          ...latest.data,
          'entries': [
            ...latest.data['entries'],
            {
              'id': id,
              'type': type,
              'amount': n,
              'date': v['date']!,
              'category': v['category']!,
              'description': v['description']!,
              'account': accountId,
              'currency': currency,
              'void': false,
            },
          ],
        }, previous: latest);
      },
    );
  }

  Future<void> experience(BuildContext c, String text) async {
    require();
    final store = ExperienceStore(records: records),
        categories = await ExperienceStore(records: records).categories();
    if (!c.mounted) return;
    final result = await Navigator.push<PrivateRecord>(
      c,
      MaterialPageRoute(
        builder: (_) => ExperienceEditor(
          initial: {
            'title': text.length <= 200 ? text : '',
            'body': text,
            'category': 'life',
          },
          categories: categories,
          onSave: (data) {
            require();
            return records.save('experience', data);
          },
        ),
      ),
    );
    if (result != null && c.mounted) {
      await page(
        c,
        ExperiencePage(record: result, store: store, access: access),
      );
    }
  }

  Future<void> book(BuildContext c, String query, VoiceAction action) async {
    if (action == VoiceAction.card) require();
    final library = BookLibraryStore(records: records);
    final id = await Navigator.push<String>(
      c,
      MaterialPageRoute(
        builder: (_) => VoiceBookPicker(
          store: library,
          query: action == VoiceAction.card ? '' : query,
          sort: action == VoiceAction.continueBook ? 'opened' : 'title',
        ),
      ),
    );
    if (id == null || !c.mounted) return;
    final book = await records.get(id), store = ReadingStore(records: records);
    if (!c.mounted) return;
    if (action == VoiceAction.card) {
      await editReadingCard(
        c,
        store,
        id,
        () => access.has(AgentAccess.core),
        front: query,
      );
      return;
    }
    if (await store.one(id, 'source') != null) {
      if (!c.mounted) return;
      await page(c, BookReadingPage(book: book, store: store, access: access));
    } else {
      if (!c.mounted) return;
      await page(c, RecordPage(book, store: records, access: access));
    }
  }
}
