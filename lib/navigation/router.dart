import 'package:regun/navigation/game_page_route.dart';
import 'package:go_router/go_router.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/menu_view.dart';

enum Routes { menu, game }

GoRouter goRouter() {
  return GoRouter(
    initialLocation: '/game',
    routes: <RouteBase>[
      GoRoute(
        path: '/menu',
        name: Routes.menu.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const MenuView(),
            transitionDuration: GameScreenTransition.enter,
            reverseTransitionDuration: GameScreenTransition.leave,
            transitionsBuilder: GameScreenTransition.build,
          );
        },
        // builder: (context, state) {
        //   return const MenuView();
        // },
      ),
      GoRoute(
        path: '/game',
        name: Routes.game.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const BaseView(),
            transitionDuration: GameScreenTransition.enter,
            reverseTransitionDuration: GameScreenTransition.leave,
            transitionsBuilder: GameScreenTransition.build,
          );
        },
      ),
    ],
  );
}
