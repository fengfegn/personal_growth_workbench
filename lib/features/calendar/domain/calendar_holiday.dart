import '../../../core/time/local_date.dart';

enum CalendarHolidayType { publicHoliday, traditionalFestival, observance }

class CalendarHoliday {
  const CalendarHoliday({
    required this.localDate,
    required this.name,
    required this.type,
  });

  final String localDate;
  final String name;
  final CalendarHolidayType type;

  bool get isPublicHoliday => type == CalendarHolidayType.publicHoliday;

  String get typeLabel {
    return switch (type) {
      CalendarHolidayType.publicHoliday => '法定节日',
      CalendarHolidayType.traditionalFestival => '传统节日',
      CalendarHolidayType.observance => '纪念日',
    };
  }
}

class CalendarHolidayCatalog {
  CalendarHolidayCatalog._();

  static List<CalendarHoliday> forYear(int year) {
    final holidays = <CalendarHoliday>[
      CalendarHoliday(
        localDate: _date(year, 1, 1),
        name: '元旦',
        type: CalendarHolidayType.publicHoliday,
      ),
      CalendarHoliday(
        localDate: _date(year, 2, 14),
        name: '情人节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 3, 8),
        name: '妇女节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 3, 12),
        name: '植树节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 5, 1),
        name: '劳动节',
        type: CalendarHolidayType.publicHoliday,
      ),
      CalendarHoliday(
        localDate: _date(year, 6, 1),
        name: '儿童节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 7, 1),
        name: '建党节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 8, 1),
        name: '建军节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 9, 10),
        name: '教师节',
        type: CalendarHolidayType.observance,
      ),
      CalendarHoliday(
        localDate: _date(year, 10, 1),
        name: '国庆节',
        type: CalendarHolidayType.publicHoliday,
      ),
      CalendarHoliday(
        localDate: _date(year, 12, 25),
        name: '圣诞节',
        type: CalendarHolidayType.observance,
      ),
    ];

    for (final holiday in _yearSpecificDates[year] ?? const <_HolidayDate>[]) {
      holidays.add(
        CalendarHoliday(
          localDate: _date(year, holiday.month, holiday.day),
          name: holiday.name,
          type: holiday.type,
        ),
      );
    }

    holidays.sort(
      (first, second) => first.localDate.compareTo(second.localDate),
    );
    return holidays;
  }

  static CalendarHoliday? forDate(DateTime date) {
    final key = localDateKey(date);
    for (final holiday in forYear(date.year)) {
      if (holiday.localDate == key) {
        return holiday;
      }
    }
    return null;
  }
}

const _yearSpecificDates = <int, List<_HolidayDate>>{
  2026: [
    _HolidayDate(1, 26, '腊八节', CalendarHolidayType.traditionalFestival),
    _HolidayDate(2, 16, '除夕', CalendarHolidayType.traditionalFestival),
    _HolidayDate(2, 17, '春节', CalendarHolidayType.publicHoliday),
    _HolidayDate(3, 3, '元宵节', CalendarHolidayType.traditionalFestival),
    _HolidayDate(4, 5, '清明节', CalendarHolidayType.publicHoliday),
    _HolidayDate(6, 19, '端午节', CalendarHolidayType.publicHoliday),
    _HolidayDate(8, 19, '七夕', CalendarHolidayType.traditionalFestival),
    _HolidayDate(8, 27, '中元节', CalendarHolidayType.traditionalFestival),
    _HolidayDate(9, 25, '中秋节', CalendarHolidayType.publicHoliday),
    _HolidayDate(10, 18, '重阳节', CalendarHolidayType.traditionalFestival),
  ],
};

class _HolidayDate {
  const _HolidayDate(this.month, this.day, this.name, this.type);

  final int month;
  final int day;
  final String name;
  final CalendarHolidayType type;
}

String _date(int year, int month, int day) {
  return localDateKey(DateTime(year, month, day));
}
