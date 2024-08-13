import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/menu_view.dart';

enum Routes {
  menu,
  game,
}

GoRouter goRouter() {
  return GoRouter(
    initialLocation: '/menu',
    routes: <RouteBase>[
      GoRoute(
        path: '/menu',
        name: Routes.menu.name,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const MenuView(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity:
                    CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                child: child,
              );
            },
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
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity:
                    CurveTween(curve: Curves.easeInOutCirc).animate(animation),
                child: child,
              );
            },
          );
        },
      ),
    ],
  );
}
