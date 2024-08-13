import 'package:flutter/material.dart';

void goBack(BuildContext context) {
  // killKeyboard(context);
  Navigator.of(context).pop();
}

// void goBack(BuildContext context) {
//   killKeyboard(context);
//   Routemaster.of(context).pop();
// }

// void goTo({
//   required BuildContext context,
//   required String route,
// }) {
//   Routemaster.of(context).push(route);
// }

void goTo({
  required BuildContext context,
  required Widget view,
}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (context) => view,
  ));
}

//! fade page transition
fadeTo({
  required BuildContext context,
  required Widget view,
}) {
  Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, anotherAnimation) {
        return view;
      },
      transitionDuration: const Duration(milliseconds: 1000),
      transitionsBuilder: (context, animation, anotherAnimation, child) {
        animation = CurvedAnimation(
          curve: Curves.linearToEaseOut,
          parent: animation,
        );
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      }));
}
