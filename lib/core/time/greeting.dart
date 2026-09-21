enum GreetingPeriod {
  morning('早上好'),
  afternoon('下午好'),
  evening('晚上好');

  const GreetingPeriod(this.label);

  final String label;
}

GreetingPeriod greetingPeriodFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) {
    return GreetingPeriod.morning;
  }
  if (hour >= 12 && hour < 18) {
    return GreetingPeriod.afternoon;
  }
  return GreetingPeriod.evening;
}

String greetingFor(DateTime time, {String nickname = '你的昵称'}) {
  return '${greetingPeriodFor(time).label}，$nickname';
}
