import 'package:flutter/material.dart';
import 'package:slide_digital_clock/slide_digital_clock.dart';

class StaticDigitalClock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: DigitalClock(
        hourMinuteDigitTextStyle: const TextStyle(fontSize: 100),
        colon: const Icon(Icons.ac_unit_sharp, size: 35),
        colonDecoration: BoxDecoration(
          border: Border.all(),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
