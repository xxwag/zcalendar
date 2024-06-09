import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math';
import 'dart:async';

class FunctionalButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double? maxWidth; // Optional maxWidth parameter
  final Color baseColor; // Base color for text and border

  const FunctionalButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.baseColor,
    this.maxWidth,
  });

  @override
  _FunctionalButtonState createState() => _FunctionalButtonState();
}

class _FunctionalButtonState extends State<FunctionalButton>
    with SingleTickerProviderStateMixin {
  late Color highlightColor;
  late int randomPeriod;
  bool showShimmer = false;
  Timer? _timer;
  late AnimationController _animationController;

  final List<Color> _highlightColors = [
    Colors.grey[100]!,
    Colors.green[100]!,
    Colors.blue[100]!,
    Colors.red[100]!,
  ];

  Color get _randomHighlightColor {
    final random = Random();
    return _highlightColors[random.nextInt(_highlightColors.length)];
  }

  void _setRandomPeriod() {
    final random = Random();
    randomPeriod = random.nextInt(30);
  }

  void _startTimer() {
    _timer?.cancel();
    _setRandomPeriod();
    _timer = Timer(Duration(seconds: randomPeriod), () {
      setState(() {
        _animationController.forward(from: 0.0);
      });
      Future.delayed(Duration(seconds: 3), () {
        setState(() {
          _animationController.reverse();
        });
        _startTimer();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    highlightColor = _randomHighlightColor;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double buttonWidth = constraints.maxWidth;
        if (widget.maxWidth != null && buttonWidth > widget.maxWidth!) {
          buttonWidth = widget.maxWidth!;
        }

        return GestureDetector(
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: buttonWidth,
              minHeight: 40.0,
              maxHeight: 40.0,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Static Text and Border
                Container(
                  width: double.infinity,
                  height: 40.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border:
                        Border.all(color: widget.baseColor), // Visible border
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Center(
                      child: AutoSizeText(
                        widget.label,
                        style: TextStyle(
                          color: widget.baseColor,
                          fontWeight: FontWeight.bold,
                        ),
                        minFontSize: 12,
                        maxFontSize: 15,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Shimmer Effect
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _animationController.value,
                      child: Shimmer.fromColors(
                        baseColor: widget.baseColor,
                        highlightColor: highlightColor,
                        period: Duration(seconds: 3), // Fixed shimmer duration
                        child: Container(
                          width: double.infinity,
                          height: 40.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: Colors.transparent),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Center(
                              child: AutoSizeText(
                                widget.label,
                                style: TextStyle(
                                  color: widget.baseColor,
                                  fontWeight: FontWeight.bold,
                                ),
                                minFontSize: 12,
                                maxFontSize: 15,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Tap detector
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(),
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
