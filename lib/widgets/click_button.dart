// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/theme/palette.dart';
import 'package:regun/utils/soloud_play.dart';

class ClickButton extends ConsumerStatefulWidget {
  final void Function()? onTap;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? buttonColor;
  final Color? buttonShadow;
  final String text;
  final bool? isActive;
  const ClickButton({
    super.key,
    this.onTap,
    this.width,
    this.height,
    this.fontSize,
    this.buttonColor,
    this.buttonShadow,
    required this.text,
    this.isActive = true,
  });

  @override
  ConsumerState<ClickButton> createState() => _ClickButtonState();
}

class _ClickButtonState extends ConsumerState<ClickButton> {
  final ValueNotifier<bool> clicked = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: clicked,
      child: const SizedBox.shrink(),
      builder: (context, value, child) {
        return InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () {
            if (widget.isActive == true) {
              ref.read(soloudPlayProvider).play('click.mp3');
              clicked.value = true;
              Timer(const Duration(milliseconds: 100), () {
                clicked.value = false;
                widget.onTap?.call();
              });
            }
          },
          child: SizedBox(
            height: widget.height ?? 70,
            width: widget.width ?? double.infinity,
            child: Stack(
              children: [
                Align(
                  alignment: clicked.value == true
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  child: Container(
                    height: widget.height != null ? widget.height! - 2 : 68,
                    width: widget.width ?? double.infinity,
                    decoration: BoxDecoration(
                      color: widget.isActive == true
                          ? widget.buttonColor ?? Palette.buttonBlue
                          : Palette.inactiveButtonBlue,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isActive == true
                              ? widget.buttonShadow ?? Palette.buttonShadow
                              : Palette.inactiveButtonShadow,
                          offset: clicked.value == true
                              ? const Offset(0, 0)
                              : const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.text,
                        style: TextStyle(
                          fontFamily: FontFam.orbitron,
                          color: widget.isActive == true
                              ? Palette.textWhite
                              : Palette.textGrey,
                          fontSize: widget.fontSize ?? 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

//!

class ClickButtonM extends ConsumerStatefulWidget {
  final void Function()? onTap;
  final double? width;
  final double? height;
  final double? fontSize;
  final Color? buttonColor;
  final Color? buttonShadow;
  final String text;
  final bool? isActive;
  const ClickButtonM({
    super.key,
    this.onTap,
    this.width,
    this.height,
    this.fontSize,
    this.buttonColor,
    this.buttonShadow,
    required this.text,
    this.isActive = true,
  });

  @override
  ConsumerState<ClickButtonM> createState() => _ClickButtonMState();
}

class _ClickButtonMState extends ConsumerState<ClickButtonM> {
  final ValueNotifier<bool> clicked = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: clicked,
      child: const SizedBox.shrink(),
      builder: (context, value, child) {
        return InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () {
            if (widget.isActive == true) {
              ref.read(soloudPlayProvider).play('click.mp3');
              clicked.value = true;
              Timer(const Duration(milliseconds: 100), () {
                clicked.value = false;
                widget.onTap?.call();
              });
            }
          },
          child: SizedBox(
            height: widget.height ?? 70,
            width: widget.width ?? double.infinity,
            child: Stack(
              children: [
                Align(
                  alignment: clicked.value == true
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  child: Container(
                    height: widget.height != null ? widget.height! - 2 : 68,
                    width: widget.width ?? double.infinity,
                    decoration: BoxDecoration(
                      color: widget.isActive == true
                          ? widget.buttonColor ?? Palette.buttonBlue
                          : Palette.inactiveButtonBlue,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isActive == true
                              ? widget.buttonShadow ?? Palette.buttonShadow
                              : Palette.inactiveButtonShadow,
                          offset: clicked.value == true
                              ? const Offset(0, 0)
                              : const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            PhosphorIconsBold.list,
                            color: Palette.textWhite,
                            size: 25,
                          ),
                          const SizedBox(
                            width: 5,
                          ),
                          Text(
                            widget.text,
                            style: TextStyle(
                              fontFamily: FontFam.orbitron,
                              color: widget.isActive == true
                                  ? Palette.textWhite
                                  : Palette.textGrey,
                              fontSize: widget.fontSize ?? 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
