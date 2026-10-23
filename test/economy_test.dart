import 'package:flutter_test/flutter_test.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/models/economy/career_progress.dart';
import 'package:regun/models/economy/shop_catalog.dart';
import 'package:regun/models/economy/scrap_reward.dart';
import 'package:regun/services/economy/shop_repository.dart';
import 'package:regun/services/account/account_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('earned Scrap is unchanged, explicit and absent in Training', () {
    final reward = ScrapReward.run(
      salvage: 7,
      kills: 309,
      bosses: 1,
      seconds: 659,
    );
    expect(
      [
        reward.salvage,
        reward.kills,
        reward.bosses,
        reward.survival,
        reward.total,
      ],
      [7, 30, 15, 10, 62],
    );
    expect(
      ScrapReward.run(
        salvage: 7,
        kills: 309,
        bosses: 1,
        seconds: 659,
        training: true,
      ).total,
      0,
    );
  });
  test('career pin survives save and completed goals give way without removing unlocks', () {
    final profile = PlayerProfile(totalKills: 490)..pinnedGoal = 'scrapper';
    expect(CareerProgress(profile).next?.id, 'scrapper');
    final restored = PlayerProfile.fromJson(profile.toJson());
    expect(CareerProgress(restored).next?.id, 'scrapper');
    restored.challenges.add('scrapper');
    expect(CareerProgress(restored).next?.id, isNot('scrapper'));
    expect(profile.scrap, 0);
  });
  test('catalogue accepts older server, ignores unsupported art and refuses malformed prices', () {
    final old = ShopCatalog.fromJson({
      'version': 'scrap-cosmetics-1',
      'prices': {'copper': 100, 'moss': 100, 'ivory': 150},
    });
    expect(old.prices.length, 3);
    for (final value in [24, 5001, 100.5, '100']) {
      expect(
        () => ShopCatalog.fromJson({
          'version': 'scrap-cosmetics-r2',
          'prices': {'copper': value},
        }),
        throwsFormatException,
      );
    }
    final next = ShopCatalog.fromJson({
      'version': 'scrap-cosmetics-r2',
      'prices': {'copper': 125, 'unknown': 10},
      'available': {'copper': false, 'unknown': true},
    });
    expect(next.prices, {'copper': 125});
    expect(next.available, isEmpty);
  });
  test('cached catalogue survives offline refresh; failures never fabricate a live quote', () async {
    var online = true;
    final api = AccountApi(
      endpoint: Uri.parse('https://shop.test'),
      client: () => MockClient((_) async {
        if (!online) throw Exception('offline');
        return http.Response(
          '{"version":"scrap-cosmetics-r2","prices":{"copper":125},"available":{"copper":true}}',
          200,
        );
      }),
    );
    final first = ShopRepository(api: api);
    await first.refresh();
    expect(first.live, isTrue);
    online = false;
    final restored = ShopRepository(api: api);
    await restored.refresh();
    expect(restored.catalog.prices['copper'], 125);
    expect(restored.live, isFalse);
    expect(restored.issue, isNotNull);
    first.dispose();
    restored.dispose();
  });
}
