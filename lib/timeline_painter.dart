import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'events.dart';

class TimeSelectionTimeline extends StatefulWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final List<Event> events;

  const TimeSelectionTimeline({
    Key? key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onDaySelected,
    required this.events,
  }) : super(key: key);

  @override
  _TimeSelectionTimelineState createState() => _TimeSelectionTimelineState();
}

class _TimeSelectionTimelineState extends State<TimeSelectionTimeline> {
  late PageController _pageController;
  late int currentPage;

  @override
  void initState() {
    super.initState();
    currentPage = DateTime.now().difference(widget.focusedMonth).inDays;
    _pageController = PageController(
      viewportFraction: 0.8, // Adjust based on your UI needs
      initialPage: currentPage,
    );
  }

  @override
  Widget build(BuildContext context) {
    double _cursorPositionX = 0.0; // Initialize cursor position

    return Container(
      height: 200, // Adjust based on your UI needs
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget
            .events.length, // Assuming one event per day for simplification
        onPageChanged: (index) {
          DateTime selectedDay = DateTime(
            widget.focusedMonth.year,
            widget.focusedMonth.month,
            index + 1,
          );
          widget.onDaySelected(selectedDay);
        },
        itemBuilder: (context, index) {
          // This is where you customize each "page" of the timeline
          bool isSelected = index == currentPage;
          return Transform(
            transform: Matrix4.identity()
              ..rotateY(
                  isSelected ? 0 : -0.4), // Slight rotation for side pages
            child: CustomPaint(
              painter: TimeLinePainter(
                events: widget.events,
                selectedDay: widget.selectedDay,
                cursorPositionX: _cursorPositionX,
                daysInMonth: DateTime(widget.focusedMonth.year,
                        widget.focusedMonth.month + 1, 0)
                    .day,
                focusedMonth: widget.focusedMonth,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class TimeLinePainter extends CustomPainter {
  final double cursorPositionX;
  final List<Event> events;
  final int daysInMonth;
  final DateTime selectedDay;
  final DateTime focusedMonth;
  final int cursorDayIndex; // New: Index of the day under the cursor
  final double expansionFactor = 20.0; // Controls how much days expand

  TimeLinePainter({
    required this.cursorPositionX,
    required this.events,
    required this.daysInMonth,
    required this.focusedMonth,
    required this.selectedDay,
    this.cursorDayIndex = 0, // Default or calculate based on cursorPositionX
  });

  // Added for page turn effect
  final double radius = 0.18; // Adjust as needed for effect strength

  void printEventDetails(Event event) {
    // Updated to reflect the new Event class structure
    print("Event: ${event.title}, "
        "Is Private: ${event.isPrivate}, "
        "Is All Day: ${event.isAllDay}, "
        "Date: ${event.date}, "
        "Start Time: ${event.startTime}, "
        "End Time: ${event.endTime}, "
        "Color: ${event.color}, "
        "Flag URL: ${event.flagUrl}, "
        "Username: ${event.username}");
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), linePaint);

    final double selectedDayWidth = size.width * 0.6;
    final double otherDaysWidth = size.width * 0.4 / (daysInMonth - 1);
    double xOffset = 0.0;

    for (int i = 0; i < daysInMonth; i++) {
      final bool isSelectedDay = i == (selectedDay.day - 1);
      final double dayWidth = isSelectedDay ? selectedDayWidth : otherDaysWidth;

      final Paint dayPaint = Paint()
        ..color = isSelectedDay ? Colors.blue : Colors.grey.withOpacity(0.3);
      canvas.drawRect(
          Rect.fromLTWH(xOffset, 0, dayWidth, size.height), dayPaint);

      if (isSelectedDay) {
        // Add a glowing effect for the selected day
        final Paint glowPaint = Paint()
          ..color = Colors.blue.withOpacity(0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawRect(
            Rect.fromLTWH(xOffset, 0, dayWidth, size.height), glowPaint);
      }

      // Position events for each day
      List<Event> dayEvents =
          events.where((event) => event.date?.day == i + 1).toList();
      for (Event event in dayEvents) {
        final double eventYStart = event.isAllDay || event.startTime == null
            ? 0
            : _calculateEventYPosition(event.startTime!, size.height);
        final double eventYEnd = event.isAllDay || event.endTime == null
            ? size.height
            : _calculateEventYPosition(event.endTime!, size.height);

        final Paint eventPaint = Paint()..color = event.color.withOpacity(0.7);
        canvas.drawRect(
            Rect.fromLTWH(
                xOffset, eventYStart, dayWidth, eventYEnd - eventYStart),
            eventPaint);
      }

      xOffset += dayWidth;
    }
  }

  double _calculateEventYPosition(String time, double canvasHeight) {
    final List<String> parts = time.split(':');
    final double hour = double.parse(parts[0]);
    final double minute = double.parse(parts[1]);
    final double position = ((hour + (minute / 60)) / 24) * canvasHeight;
    return position;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PageTurnWidget extends StatefulWidget {
  const PageTurnWidget({
    required Key key,
    required this.amount,
    this.backgroundColor = const Color(0xFFFFFFCC),
    required this.child,
  }) : super(key: key);

  final Animation<double> amount;
  final Color backgroundColor;
  final Widget child;

  @override
  _PageTurnWidgetState createState() => _PageTurnWidgetState();
}

class _PageTurnWidgetState extends State<PageTurnWidget> {
  final _boundaryKey = GlobalKey();
  late ui.Image _image;

  void _captureImage(Duration timeStamp) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final boundary = _boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PageTurnEffect(
        amount: widget.amount,
        image: _image,
        backgroundColor: widget.backgroundColor,
      ),
      size: Size.infinite,
    );
  }
}

class PageTurnImage extends StatefulWidget {
  const PageTurnImage({
    required Key key,
    required this.amount,
    required this.image,
    this.backgroundColor = const Color(0xFFFFFFCC),
  }) : super(key: key);

  final Animation<double> amount;
  final ImageProvider image;
  final Color backgroundColor;

  @override
  _PageTurnImageState createState() => _PageTurnImageState();
}

class _PageTurnImageState extends State<PageTurnImage> {
  late ImageStream _imageStream;
  late ImageInfo _imageInfo;
  bool _isListeningToStream = false;

  late ImageStreamListener _imageListener;

  @override
  void initState() {
    super.initState();
    _imageListener = ImageStreamListener(_handleImageFrame);
  }

  @override
  void dispose() {
    _stopListeningToStream();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _resolveImage();
    if (TickerMode.of(context)) {
      _listenToStream();
    } else {
      _stopListeningToStream();
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(PageTurnImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) {
      _resolveImage();
    }
  }

  @override
  void reassemble() {
    _resolveImage(); // in case the image cache was flushed
    super.reassemble();
  }

  void _resolveImage() {
    final ImageStream newStream =
        widget.image.resolve(createLocalImageConfiguration(context));
    _updateSourceStream(newStream);
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    setState(() => _imageInfo = imageInfo);
  }

  // Updates _imageStream to newStream, and moves the stream listener
  // registration from the old stream to the new stream (if a listener was
  // registered).
  void _updateSourceStream(ImageStream newStream) {
    if (_imageStream.key == newStream.key) return;

    if (_isListeningToStream) _imageStream.removeListener(_imageListener);

    _imageStream = newStream;
    if (_isListeningToStream) _imageStream.addListener(_imageListener);
  }

  void _listenToStream() {
    if (_isListeningToStream) return;
    _imageStream.addListener(_imageListener);
    _isListeningToStream = true;
  }

  void _stopListeningToStream() {
    if (!_isListeningToStream) return;
    _imageStream.removeListener(_imageListener);
    _isListeningToStream = false;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PageTurnEffect(
        amount: widget.amount,
        image: _imageInfo.image,
        backgroundColor: widget.backgroundColor,
      ),
      size: Size.infinite,
    );
  }
}

class _PageTurnEffect extends CustomPainter {
  _PageTurnEffect({
    required this.amount,
    required this.image,
    required this.backgroundColor,
    this.radius = 0.18,
  }) : super(repaint: amount);

  final Animation<double> amount;
  final ui.Image image;
  final Color backgroundColor;
  final double radius;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final pos = amount.value;
    final movX = (1.0 - pos) * 0.85;
    final calcR = (movX < 0.20) ? radius * movX * 5 : radius;
    final wHRatio = 1 - calcR;
    final hWRatio = image.height / image.width;
    final hWCorrection = (hWRatio - 1.0) / 2.0;

    final w = size.width.toDouble();
    final h = size.height.toDouble();
    final c = canvas;
    final shadowXf = (wHRatio - movX);
    final shadowSigma =
        Shadow.convertRadiusToSigma(8.0 + (32.0 * (1.0 - shadowXf)));
    final pageRect = Rect.fromLTRB(0.0, 0.0, w * shadowXf, h);
    c.drawRect(pageRect, Paint()..color = backgroundColor);
    c.drawRect(
      pageRect,
      Paint()
        ..color = Colors.black54
        ..maskFilter = MaskFilter.blur(BlurStyle.outer, shadowSigma),
    );

    final ip = Paint();
    for (double x = 0; x < size.width; x++) {
      final xf = (x / w);
      final v = (calcR * (math.sin(math.pi / 0.5 * (xf - (1.0 - pos)))) +
          (calcR * 1.1));
      final xv = (xf * wHRatio) - movX;
      final sx = (xf * image.width);
      final sr = Rect.fromLTRB(sx, 0.0, sx + 1.0, image.height.toDouble());
      final yv = ((h * calcR * movX) * hWRatio) - hWCorrection;
      final ds = (yv * v);
      final dr = Rect.fromLTRB(xv * w, 0.0 - ds, xv * w + 1.0, h + ds);
      c.drawImageRect(image, sr, dr, ip);
    }
  }

  @override
  bool shouldRepaint(_PageTurnEffect oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.amount.value != amount.value;
  }
}
