import 'package:flutter/material.dart';
import 'package:regun/navigation/game_page_route.dart';

void goBack(BuildContext context) => Navigator.of(context).pop();

void goTo({required BuildContext context, required Widget view}) {
  Navigator.of(context).push(GamePageRoute<void>(builder: (_) => view));
}

void fadeTo({required BuildContext context, required Widget view}) =>
    goTo(context: context, view: view);
