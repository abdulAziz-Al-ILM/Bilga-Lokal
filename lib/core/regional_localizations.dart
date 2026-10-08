import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'strings.dart';

// Flutter provides Kyrgyz. These delegates fill its Tajik/Turkmen gap.
bool _regional(Locale locale) =>
    const {'tg', 'tk'}.contains(locale.languageCode);
const _labels = <String, List<String>>{
  "copyButtonLabel": ["Нусха гирифтан", "Nusgala"],
  "cutButtonLabel": ["Буридан", "Kes"],
  "pasteButtonLabel": ["Гузоштан", "Goý"],
  "selectAllButtonLabel": ["Интихоби ҳама", "Hemmesini saýla"],
  "lookUpButtonLabel": ["Ҷустуҷӯ", "Gözle"],
  "searchWebButtonLabel": ["Ҷустуҷӯ дар интернет", "Internetde gözle"],
  "shareButtonLabel": ["Мубодила", "Paýlaş"],
  "backButtonTooltip": ["Бозгашт", "Yza"],
  "openAppDrawerTooltip": ["Кушодани меню", "Menýuny aç"],
  "closeButtonTooltip": ["Пӯшидан", "Ýap"],
  "deleteButtonTooltip": ["Нест кардан", "Poz"],
  "moreButtonTooltip": ["Бештар", "Has köp"],
  "nextMonthTooltip": ["Моҳи оянда", "Indiki aý"],
  "previousMonthTooltip": ["Моҳи гузашта", "Öňki aý"],
  "showMenuTooltip": ["Намоиши меню", "Menýuny görkez"],
  "drawerLabel": ["Менюи роҳнамо", "Geçiş menýusy"],
  "popupMenuLabel": ["Меню", "Menýu"],
  "dialogLabel": ["Муколама", "Gepleşik penjiresi"],
  "alertDialogLabel": ["Огоҳӣ", "Duýduryş"],
  "searchFieldLabel": ["Ҷустуҷӯ", "Gözle"],
  "currentDateLabel": ["Имрӯз", "Şu gün"],
  "selectedDateLabel": ["Интихоб шуд", "Saýlandy"],
  "selectYearSemanticsLabel": ["Солро интихоб кунед", "Ýyly saýlaň"],
  "unspecifiedDate": ["Сана", "Sene"],
  "unspecifiedDateRange": ["Фосилаи санаҳо", "Sene aralygy"],
  "dateInputLabel": ["Санаро ворид кунед", "Senäni giriziň"],
  "dateRangeStartLabel": ["Санаи оғоз", "Başlangyç sene"],
  "dateRangeEndLabel": ["Санаи анҷом", "Ahyrky sene"],
  "invalidDateFormatLabel": [
    "Шакли сана нодуруст аст.",
    "Senäniň görnüşi nädogry.",
  ],
  "invalidDateRangeLabel": [
    "Фосилаи санаҳо нодуруст аст.",
    "Sene aralygy nädogry.",
  ],
  "dateOutOfRangeLabel": [
    "Сана берун аз ҳудуд аст.",
    "Sene aralykdan daşarda.",
  ],
  "datePickerHelpText": ["Санаро интихоб кунед", "Senäni saýlaň"],
  "dateRangePickerHelpText": ["Фосиларо интихоб кунед", "Aralygy saýlaň"],
  "calendarModeButtonLabel": ["Гузаштан ба тақвим", "Senenama geç"],
  "inputDateModeButtonLabel": ["Ворид кардани сана", "Senäni giriz"],
  "timePickerDialHelpText": ["Вақтро интихоб кунед", "Wagty saýlaň"],
  "timePickerInputHelpText": ["Вақтро ворид кунед", "Wagty giriziň"],
  "timePickerHourLabel": ["Соат", "Sagat"],
  "timePickerMinuteLabel": ["Дақиқа", "Minut"],
  "invalidTimeLabel": ["Вақти дурустро ворид кунед", "Dogry wagt giriziň"],
  "dialModeButtonLabel": ["Интихоб бо соат", "Sagatdan saýla"],
  "inputTimeModeButtonLabel": ["Ворид кардани вақт", "Wagty ýazyp giriz"],
  "timePickerHourModeAnnouncement": ["Соатро интихоб кунед", "Sagady saýlaň"],
  "timePickerMinuteModeAnnouncement": [
    "Дақиқаро интихоб кунед",
    "Minudy saýlaň",
  ],
  "modalBarrierDismissLabel": ["Пӯшидан", "Ýap"],
  "menuDismissLabel": ["Пӯшидани меню", "Menýuny ýap"],
  "reorderItemUp": ["Ба боло кӯчонед", "Ýokary geçir"],
  "reorderItemDown": ["Ба поён кӯчонед", "Aşak geçir"],
  "reorderItemLeft": ["Ба чап кӯчонед", "Çepe geçir"],
  "reorderItemRight": ["Ба рост кӯчонед", "Saga geçir"],
  "reorderItemToStart": ["Ба аввал кӯчонед", "Başa geçir"],
  "reorderItemToEnd": ["Ба охир кӯчонед", "Soňuna geçir"],
  "searchResultsFound": [
    "Натиҷаҳои ҷустуҷӯ ёфт шуданд",
    "Gözleg netijeleri tapyldy",
  ],
  "noResultsFound": ["Натиҷа ёфт нашуд", "Netije tapylmady"],
  "radioButtonUnselectedLabel": ["Интихоб нашудааст", "Saýlanmadyk"],
};
String _label(String code, String key) => _labels[key]![code == 'tg' ? 0 : 1];

class RegionalMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const RegionalMaterialDelegate();
  @override
  bool isSupported(Locale locale) => _regional(locale);
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(RegionalMaterialLocalizations(locale.languageCode));
  @override
  bool shouldReload(RegionalMaterialDelegate old) => false;
}

class RegionalMaterialLocalizations extends DefaultMaterialLocalizations {
  final String code;
  const RegionalMaterialLocalizations(this.code);
  String text(String key) => Strings.get(code, key);
  @override
  String get alertDialogLabel => _label(code, 'alertDialogLabel');
  @override
  String get backButtonTooltip => _label(code, 'backButtonTooltip');
  @override
  String get calendarModeButtonLabel => _label(code, 'calendarModeButtonLabel');
  @override
  String get closeButtonTooltip => _label(code, 'closeButtonTooltip');
  @override
  String get copyButtonLabel => _label(code, 'copyButtonLabel');
  @override
  String get currentDateLabel => _label(code, 'currentDateLabel');
  @override
  String get cutButtonLabel => _label(code, 'cutButtonLabel');
  @override
  String get dateInputLabel => _label(code, 'dateInputLabel');
  @override
  String get dateOutOfRangeLabel => _label(code, 'dateOutOfRangeLabel');
  @override
  String get datePickerHelpText => _label(code, 'datePickerHelpText');
  @override
  String get dateRangeEndLabel => _label(code, 'dateRangeEndLabel');
  @override
  String get dateRangePickerHelpText => _label(code, 'dateRangePickerHelpText');
  @override
  String get dateRangeStartLabel => _label(code, 'dateRangeStartLabel');
  @override
  String get deleteButtonTooltip => _label(code, 'deleteButtonTooltip');
  @override
  String get dialModeButtonLabel => _label(code, 'dialModeButtonLabel');
  @override
  String get dialogLabel => _label(code, 'dialogLabel');
  @override
  String get drawerLabel => _label(code, 'drawerLabel');
  @override
  String get inputDateModeButtonLabel =>
      _label(code, 'inputDateModeButtonLabel');
  @override
  String get inputTimeModeButtonLabel =>
      _label(code, 'inputTimeModeButtonLabel');
  @override
  String get invalidDateFormatLabel => _label(code, 'invalidDateFormatLabel');
  @override
  String get invalidDateRangeLabel => _label(code, 'invalidDateRangeLabel');
  @override
  String get invalidTimeLabel => _label(code, 'invalidTimeLabel');
  @override
  String get lookUpButtonLabel => _label(code, 'lookUpButtonLabel');
  @override
  String get menuDismissLabel => _label(code, 'menuDismissLabel');
  @override
  String get modalBarrierDismissLabel =>
      _label(code, 'modalBarrierDismissLabel');
  @override
  String get moreButtonTooltip => _label(code, 'moreButtonTooltip');
  @override
  String get nextMonthTooltip => _label(code, 'nextMonthTooltip');
  @override
  String get openAppDrawerTooltip => _label(code, 'openAppDrawerTooltip');
  @override
  String get pasteButtonLabel => _label(code, 'pasteButtonLabel');
  @override
  String get popupMenuLabel => _label(code, 'popupMenuLabel');
  @override
  String get previousMonthTooltip => _label(code, 'previousMonthTooltip');
  @override
  String get reorderItemDown => _label(code, 'reorderItemDown');
  @override
  String get reorderItemLeft => _label(code, 'reorderItemLeft');
  @override
  String get reorderItemRight => _label(code, 'reorderItemRight');
  @override
  String get reorderItemToEnd => _label(code, 'reorderItemToEnd');
  @override
  String get reorderItemToStart => _label(code, 'reorderItemToStart');
  @override
  String get reorderItemUp => _label(code, 'reorderItemUp');
  @override
  String get searchFieldLabel => _label(code, 'searchFieldLabel');
  @override
  String get searchWebButtonLabel => _label(code, 'searchWebButtonLabel');
  @override
  String get selectAllButtonLabel => _label(code, 'selectAllButtonLabel');
  @override
  String get selectYearSemanticsLabel =>
      _label(code, 'selectYearSemanticsLabel');
  @override
  String get selectedDateLabel => _label(code, 'selectedDateLabel');
  @override
  String get shareButtonLabel => _label(code, 'shareButtonLabel');
  @override
  String get showMenuTooltip => _label(code, 'showMenuTooltip');
  @override
  String get timePickerDialHelpText => _label(code, 'timePickerDialHelpText');
  @override
  String get timePickerHourLabel => _label(code, 'timePickerHourLabel');
  @override
  String get timePickerHourModeAnnouncement =>
      _label(code, 'timePickerHourModeAnnouncement');
  @override
  String get timePickerInputHelpText => _label(code, 'timePickerInputHelpText');
  @override
  String get timePickerMinuteLabel => _label(code, 'timePickerMinuteLabel');
  @override
  String get timePickerMinuteModeAnnouncement =>
      _label(code, 'timePickerMinuteModeAnnouncement');
  @override
  String get unspecifiedDate => _label(code, 'unspecifiedDate');
  @override
  String get unspecifiedDateRange => _label(code, 'unspecifiedDateRange');
  @override
  String get cancelButtonLabel => text('cancel');
  @override
  String get closeButtonLabel => text('close');
  @override
  String get continueButtonLabel => text('continue');
  @override
  String get okButtonLabel => text('confirm');
  @override
  String get saveButtonLabel => text('save');
  List<String> get months =>
      (code == 'tg'
              ? 'январ|феврал|март|апрел|май|июн|июл|август|сентябр|октябр|ноябр|декабр'
              : 'ýanwar|fewral|mart|aprel|maý|iýun|iýul|awgust|sentýabr|oktýabr|noýabr|dekabr')
          .split('|');
  List<String> get weekdays =>
      (code == 'tg'
              ? 'душанбе|сешанбе|чоршанбе|панҷшанбе|ҷумъа|шанбе|якшанбе'
              : 'duşenbe|sişenbe|çarşenbe|penşenbe|anna|şenbe|ýekşenbe')
          .split('|');
  @override
  List<String> get narrowWeekdays => code == 'tg'
      ? const ['Я', 'Д', 'С', 'Ч', 'П', 'Ҷ', 'Ш']
      : const ['Ý', 'D', 'S', 'Ç', 'P', 'A', 'Ş'];
  @override
  int get firstDayOfWeekIndex => 1;
  @override
  String get dateSeparator => '.';
  @override
  String get dateHelpText => 'dd.mm.yyyy';
  @override
  String formatCompactDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year.toString().padLeft(4, '0')}';
  @override
  String formatShortDate(DateTime date) =>
      '${date.day} ${months[date.month - 1]} ${date.year}';
  @override
  String formatMediumDate(DateTime date) =>
      '${date.day} ${months[date.month - 1]}';
  @override
  String formatFullDate(DateTime date) =>
      '${weekdays[date.weekday - 1]}, ${formatShortDate(date)}';
  @override
  String formatMonthYear(DateTime date) =>
      '${months[date.month - 1]} ${date.year}';
  @override
  String formatShortMonthDay(DateTime date) => formatMediumDate(date);
  @override
  DateTime? parseCompactDate(String? inputString) {
    if (inputString == null) return null;
    final parts = inputString.trim().split('.');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]),
        m = int.tryParse(parts[1]),
        y = int.tryParse(parts[2]);
    if (d == null ||
        m == null ||
        y == null ||
        y < 1 ||
        y > 9999 ||
        m < 1 ||
        m > 12 ||
        d < 1 ||
        d > 31) {
      return null;
    }
    final date = DateTime(y, m, d);
    return date.year == y && date.month == m && date.day == d ? date : null;
  }

  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      TimeOfDayFormat.HH_colon_mm;
  @override
  String formatTimeOfDay(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) =>
      '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}';
}

class RegionalWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const RegionalWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => _regional(locale);
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(_RegionalWidgets(locale.languageCode));
  @override
  bool shouldReload(RegionalWidgetsDelegate old) => false;
}

class _RegionalWidgets extends DefaultWidgetsLocalizations {
  final String code;
  const _RegionalWidgets(this.code);
  @override
  String get copyButtonLabel => _label(code, 'copyButtonLabel');
  @override
  String get cutButtonLabel => _label(code, 'cutButtonLabel');
  @override
  String get lookUpButtonLabel => _label(code, 'lookUpButtonLabel');
  @override
  String get noResultsFound => _label(code, 'noResultsFound');
  @override
  String get pasteButtonLabel => _label(code, 'pasteButtonLabel');
  @override
  String get radioButtonUnselectedLabel =>
      _label(code, 'radioButtonUnselectedLabel');
  @override
  String get reorderItemDown => _label(code, 'reorderItemDown');
  @override
  String get reorderItemLeft => _label(code, 'reorderItemLeft');
  @override
  String get reorderItemRight => _label(code, 'reorderItemRight');
  @override
  String get reorderItemToEnd => _label(code, 'reorderItemToEnd');
  @override
  String get reorderItemToStart => _label(code, 'reorderItemToStart');
  @override
  String get reorderItemUp => _label(code, 'reorderItemUp');
  @override
  String get searchResultsFound => _label(code, 'searchResultsFound');
  @override
  String get searchWebButtonLabel => _label(code, 'searchWebButtonLabel');
  @override
  String get selectAllButtonLabel => _label(code, 'selectAllButtonLabel');
  @override
  String get shareButtonLabel => _label(code, 'shareButtonLabel');
}

// Bilga's Android screens use Material. Keep Cupertino's required delegate
// available; an iOS release needs dedicated Cupertino translations as well.
class RegionalCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const RegionalCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => _regional(locale);
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultCupertinoLocalizations());
  @override
  bool shouldReload(RegionalCupertinoDelegate old) => false;
}
