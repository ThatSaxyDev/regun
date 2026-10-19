import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regun/models/control_layout.dart';
import 'package:regun/services/local_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('control layout and personal best survive service recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final first = LocalPreferences();
    await first.load();
    expect(
        await first
            .saveControls(const ControlLayout(inset: 120, leftHanded: true)),
        isTrue);
    await first.record(score: 123, seconds: 70);
    await first.record(score: 1, seconds: 5);
    final second = LocalPreferences();
    await second.load();
    expect(second.controls.inset, 120);
    expect(second.controls.leftHanded, isTrue);
    expect(second.bestScore, 123);
    expect(second.bestSeconds, 70);
  });

  test('corrupt control data keeps records and uses safe defaults', () async {
    SharedPreferences.setMockInitialValues(
        {'controls.v1': '{broken', 'record.score': 99});
    final preferences = LocalPreferences();
    await preferences.load();
    expect(preferences.controls.inset, 84);
    expect(preferences.bestScore, 99);
  });
  test('profile backup recovers corruption and reset clears both copies',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = LocalPreferences();
    await preferences.load();
    preferences.profile.scrap = 100;
    expect(await preferences.saveProfile(), isTrue);
    preferences.profile.scrap = 200;
    expect(await preferences.saveProfile(), isTrue);
    final storage = await SharedPreferences.getInstance();
    await storage.setString('profile.v1', '{broken');
    final recovered = LocalPreferences();
    await recovered.load();
    expect(recovered.profile.scrap, 100);
    await recovered.resetProgress();
    final fresh = LocalPreferences();
    await fresh.load();
    expect(fresh.profile.scrap, 0);
    expect(fresh.profile.challenges, isEmpty);
    expect(storage.getString('profile.backup.v1'), isNull);
  });
}
