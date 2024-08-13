// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/game.dart';
import 'package:regun/theme/palette.dart';
import 'package:regun/utils/app_extensions.dart';
import 'package:regun/utils/nav.dart';
import 'package:regun/widgets/click_button.dart';

class PowerUpDialog extends ConsumerStatefulWidget {
  final BuildContext cntxt;
  const PowerUpDialog({
    super.key,
    required this.cntxt,
  });

  @override
  ConsumerState<PowerUpDialog> createState() => _PowerUpDialogState();
}

class _PowerUpDialogState extends ConsumerState<PowerUpDialog> {
  late RegunGame _myGame;
  @override
  void initState() {
    super.initState();
    _myGame = RegunGame();
    Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
      _myGame.slow();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black26.withOpacity(0.3),
      body: Center(
        child: Container(
          height: 240.0,
          width: 327.0,
          decoration: BoxDecoration(
              color: const Color.fromRGBO(20, 19, 23, 1),
              borderRadius: BorderRadius.circular(8.0)),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClickButton(
                  onTap: () {
                    _myGame.normalizeGameSpeed();

                    goBack(widget.cntxt);
                  },
                  text: 'Select power-up 1',
                  width: 200,
                  height: 50,
                ).fadeInFromBottom(delay: 100.ms),
                const SizedBox(
                  height: 30,
                ),
                ClickButton(
                  onTap: () {
                    _myGame.normalizeGameSpeed();

                    goBack(widget.cntxt);
                  },
                  buttonColor: Palette.buttonBlueVariant,
                  buttonShadow: Palette.buttonShadowBlueVariant,
                  text: 'Select power-up 2',
                  width: 200,
                  height: 50,
                ).fadeInFromBottom(delay: 100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
