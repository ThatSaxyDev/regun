import 'package:flutter_test/flutter_test.dart';
import 'package:regun/utils/format_number.dart';

void main() {
  test('groups visible counts without losing signs or decimal precision', () {
    expect(formatNumber(999), '999');
    expect(formatNumber(1000), '1,000');
    expect(formatNumber(1234567), '1,234,567');
    expect(formatNumber(-1234567), '-1,234,567');
    expect(groupNumberText('+1234567.050'), '+1,234,567.050');
    expect(groupNumberText('12:30'), '12:30');
    expect(formatMetric('player-1234567'), 'player-1234567');
  });
}
