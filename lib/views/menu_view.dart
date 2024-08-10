import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:regun/router.dart';
import 'package:regun/utils/app_extensions.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';
import 'package:regun/widgets/home_animation.dart';

class MenuView extends ConsumerWidget {
  const MenuView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(20, 19, 23, 1),
      body: SizedBox(
        height: height(context),
        width: width(context),
        child: Row(
          children: [
            const SizedBox(
              width: 100,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Re-Gun',
                  style: TextStyle(
                    fontFamily: FontFam.pressStart,
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                  ),
                ).fadeInFromTop(delay: 0.ms),
                const SizedBox(
                  height: 30,
                ),
                ClickButton(
                  onTap: () {
                    context.goNamed('game');
                  },
                  text: 'Start',
                  fontSize: 20,
                  width: 120,
                  height: 60,
                ).fadeInFromBottom(delay: 100.ms),
              ],
            ),
            const Spacer(),
            const SizedBox(
              height: 200,
              width: 200,
              // color: Colors.red,
              child: MenuAnimation(),
            ),
            const SizedBox(
              width: 100,
            ),
          ],
        ),
      ),
    );
  }
}
