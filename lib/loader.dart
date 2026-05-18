// ============================================================================
// Новый лоадер Lounge of Idleness
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoungeOfIdlenessWaveLoader extends StatefulWidget {
  const LoungeOfIdlenessWaveLoader({Key? key}) : super(key: key);

  @override
  State<LoungeOfIdlenessWaveLoader> createState() =>
      _LoungeOfIdlenessWaveLoaderState();
}

class _LoungeOfIdlenessWaveLoaderState
    extends State<LoungeOfIdlenessWaveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController loungeOfIdlenessWaveController;

  @override
  void initState() {
    super.initState();
    loungeOfIdlenessWaveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    loungeOfIdlenessWaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color loungeOfIdlenessBackground = Color(0xFF05071B);
    const Color loungeOfIdlenessPrimary = Color(0xFF49F2FF);
    const Color loungeOfIdlenessSecondary = Color(0xFFFFA54B);

    const String loungeOfIdlenessTitle = 'Lounge';
    const String loungeOfIdlenessSubtitle = 'of Idleness';

    return Container(
      color: loungeOfIdlenessBackground,
      child: Center(
        child: AnimatedBuilder(
          animation: loungeOfIdlenessWaveController,
          builder: (BuildContext context, Widget? child) {
            final double loungeOfIdlenessT =
                loungeOfIdlenessWaveController.value * 2 * math.pi;

            List<Widget> loungeOfIdlenessLetters = <Widget>[];
            for (int loungeOfIdlenessIndex = 0;
            loungeOfIdlenessIndex < loungeOfIdlenessTitle.length;
            loungeOfIdlenessIndex++) {
              final String loungeOfIdlenessChar =
              loungeOfIdlenessTitle[loungeOfIdlenessIndex];
              final double loungeOfIdlenessPhase =
                  loungeOfIdlenessT + loungeOfIdlenessIndex * 0.6;
              final double loungeOfIdlenessDy =
                  math.sin(loungeOfIdlenessPhase) * 6.0;
              final double loungeOfIdlenessOpacity =
                  0.7 + 0.3 * math.sin(loungeOfIdlenessPhase).abs();

              loungeOfIdlenessLetters.add(
                Transform.translate(
                  offset: Offset(0, loungeOfIdlenessDy),
                  child: Text(
                    loungeOfIdlenessChar,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: loungeOfIdlenessPrimary
                          .withOpacity(loungeOfIdlenessOpacity),
                      shadows: <Shadow>[
                        Shadow(
                          color: loungeOfIdlenessSecondary.withOpacity(
                              0.6 * loungeOfIdlenessOpacity),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.transparent,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: loungeOfIdlenessPrimary.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                    border: Border.all(
                      color: loungeOfIdlenessPrimary.withOpacity(0.9),
                      width: 3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: loungeOfIdlenessLetters,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  loungeOfIdlenessSubtitle,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3,
                    color: loungeOfIdlenessPrimary.withOpacity(0.9),
                    shadows: <Shadow>[
                      Shadow(
                        color: loungeOfIdlenessSecondary.withOpacity(0.7),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}