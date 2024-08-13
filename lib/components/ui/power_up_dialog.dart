// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:regun/theme/palette.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black26.withOpacity(0.3),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                height: 240.0,
                width: 327.0,
                decoration: BoxDecoration(
                    color: Palette.whiteColor,
                    borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(
                    vertical: 24.0, horizontal: 18.0),
                margin: const EdgeInsets.only(top: 250),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(widget.cntxt).pop();
                    },
                    child: const Text('Go back'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
