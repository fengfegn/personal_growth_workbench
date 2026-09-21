import 'package:flutter_test/flutter_test.dart';
import 'package:personal_growth_workbench/core/time/greeting.dart';

void main() {
  test('returns the morning greeting from 05:00 through 11:59', () {
    expect(greetingPeriodFor(DateTime(2026, 8, 4, 5)), GreetingPeriod.morning);
    expect(
      greetingPeriodFor(DateTime(2026, 8, 4, 11, 59)),
      GreetingPeriod.morning,
    );
  });

  test('returns the afternoon greeting from 12:00 through 17:59', () {
    expect(
      greetingPeriodFor(DateTime(2026, 8, 4, 12)),
      GreetingPeriod.afternoon,
    );
    expect(
      greetingPeriodFor(DateTime(2026, 8, 4, 17, 59)),
      GreetingPeriod.afternoon,
    );
  });

  test('returns the evening greeting for the remaining hours', () {
    expect(
      greetingPeriodFor(DateTime(2026, 8, 4, 4, 59)),
      GreetingPeriod.evening,
    );
    expect(greetingPeriodFor(DateTime(2026, 8, 4, 18)), GreetingPeriod.evening);
    expect(greetingFor(DateTime(2026, 8, 4, 18), nickname: '小明'), '晚上好，小明');
  });
}
