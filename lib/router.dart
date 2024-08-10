import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:regun/views/base_view.dart';
import 'package:regun/views/menu_view.dart';

GoRouter goRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'menu',
        builder: (context, state) {
          return const MenuView();
        },
      ),
      GoRoute(
        path: '/game',
        name: 'game',
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
