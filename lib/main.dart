import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const AdfTrainerApp());
}

class AdfTrainerApp extends StatelessWidget {
  const AdfTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ADF Trainer',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFEAF5FB),
        appBar: AppBar(
          title: const Text('ADF Trainer'),
        ),
        body: const NavigationBoard(),
      ),
    );
  }
}

class NavigationBoard extends StatefulWidget {
  const NavigationBoard({super.key});

  @override
  State<NavigationBoard> createState() => _NavigationBoardState();
}

class _NavigationBoardState extends State<NavigationBoard> {
  // aircraftPosition anger nu flygplanets CENTRUM.
  Offset aircraftPosition = const Offset(250, 250);

  double heading = 90;

  static const double aircraftSize = 50;

  double normalize360(double value) {
    value %= 360;

    if (value < 0) {
      value += 360;
    }

    return value;
  }

  double calculateQdm({
    required Offset aircraftCenter,
    required Offset beaconCenter,
  }) {
    final dx = beaconCenter.dx - aircraftCenter.dx;
    final dy = beaconCenter.dy - aircraftCenter.dy;

    final angle = math.atan2(dx, -dy) * 180 / math.pi;

    return normalize360(angle);
  }

  double calculateQdr(double qdm) {
    return normalize360(qdm + 180);
  }

  double calculateRelativeBearing({
    required double qdm,
    required double heading,
  }) {
    return normalize360(qdm - heading);
  }

  String formatBearing(double value) {
    return value.round().toString().padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;

              // Vi reserverar lite höjd för informationspanelen
              // ovanför kompassrosen.
              final boardSize = math.min(
                availableWidth * 0.95,
                (availableHeight - 85) * 0.95,
              );

              final beaconCenter = Offset(
                boardSize / 2,
                boardSize / 2,
              );

              // aircraftPosition ÄR flygplanets centrum.
              final aircraftCenter = aircraftPosition;

              final qdm = calculateQdm(
                aircraftCenter: aircraftCenter,
                beaconCenter: beaconCenter,
              );

              final qdr = calculateQdr(qdm);

              final relativeBearing = calculateRelativeBearing(
                qdm: qdm,
                heading: heading,
              );

              return Column(
                children: [
                  const SizedBox(height: 8),

                  // Informationspanelen ligger nu UTANFÖR
                  // själva kompassrosens Stack.
                  NavigationDataPanel(
                    heading: heading,
                    relativeBearing: relativeBearing,
                    qdm: qdm,
                    qdr: qdr,
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Kompassros + linje mellan flygplan och NDB
                            Positioned.fill(
                              child: CustomPaint(
                                painter: NavigationPainter(
                                  beaconCenter: beaconCenter,
                                  aircraftCenter: aircraftCenter,
                                ),
                              ),
                            ),

                            // Flygplanet
                            Positioned(
                              left:
                                  aircraftPosition.dx - aircraftSize / 2,
                              top:
                                  aircraftPosition.dy - aircraftSize / 2,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  setState(() {
                                    final newPosition =
                                        aircraftPosition + details.delta;

                                    aircraftPosition = Offset(
                                      newPosition.dx.clamp(
                                        aircraftSize / 2,
                                        boardSize - aircraftSize / 2,
                                      ),
                                      newPosition.dy.clamp(
                                        aircraftSize / 2,
                                        boardSize - aircraftSize / 2,
                                      ),
                                    );
                                  });
                                },
                                child: Aircraft(
                                  heading: heading,
                                  size: aircraftSize,
                                ),
                              ),
                            ),

                            // Heading-text separat från flygplanssymbolen.
                            Positioned(
                              left: aircraftPosition.dx - 38,
                              top: aircraftPosition.dy -
                                  aircraftSize / 2 -
                                  22,
                              child: IgnorePointer(
                                child: Text(
                                  'HDG ${formatBearing(heading)}°',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // NDB-fyren
                            Positioned(
                              left: beaconCenter.dx - 45,
                              top: beaconCenter.dy - 45,
                              child: const NdbBeacon(
                                size: 90,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Kontrollpanelen hålls vit.
        Container(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            18,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Colors.grey.shade300,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Heading: ${formatBearing(heading)}°',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Slider(
                value: heading,
                min: 0,
                max: 359,
                divisions: 359,
                label: '${formatBearing(heading)}°',
                onChanged: (value) {
                  setState(() {
                    heading = value;
                  });
                },
              ),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('000°'),
                  Text('090°'),
                  Text('180°'),
                  Text('270°'),
                  Text('359°'),
                ],
              ),

              const SizedBox(height: 10),

              const Text(
                'Drag the aircraft to change its position.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NavigationDataPanel extends StatelessWidget {
  final double heading;
  final double relativeBearing;
  final double qdm;
  final double qdr;

  const NavigationDataPanel({
    super.key,
    required this.heading,
    required this.relativeBearing,
    required this.qdm,
    required this.qdr,
  });

  String f(double value) {
    return value.round().toString().padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item('HDG', f(heading)),
              const SizedBox(width: 24),
              _item('RB', f(relativeBearing)),
            ],
          ),

          const SizedBox(height: 5),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _item('QDM', f(qdm)),
              const SizedBox(width: 24),
              _item('QDR', f(qdr)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(String label, String value) {
    return SizedBox(
      width: 115,
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '$value°',
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class Aircraft extends StatelessWidget {
  final double heading;
  final double size;

  const Aircraft({
    super.key,
    required this.heading,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: CustomPaint(
        size: Size.square(size),
        painter: AircraftPainter(),
      ),
    );
  }
}

class NdbBeacon extends StatelessWidget {
  final double size;

  const NdbBeacon({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: NdbBeaconPainter(),
    );
  }
}

class NdbBeaconPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black;

    final innerRadius = size.width * 0.22;

    canvas.drawCircle(
      center,
      innerRadius,
      linePaint,
    );

    canvas.drawCircle(
      center,
      size.width * 0.045,
      dotPaint,
    );

    final ringRadius = size.width * 0.34;

    const dotCount = 24;

    for (int i = 0; i < dotCount; i++) {
      final angle = 2 * math.pi * i / dotCount;

      final dotCenter = Offset(
        center.dx + ringRadius * math.cos(angle),
        center.dy + ringRadius * math.sin(angle),
      );

      canvas.drawCircle(
        dotCenter,
        size.width * 0.028,
        dotPaint,
      );
    }

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'NDB',
        style: TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        size.height - 14,
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

class NavigationPainter extends CustomPainter {
  final Offset beaconCenter;
  final Offset aircraftCenter;

  NavigationPainter({
    required this.beaconCenter,
    required this.aircraftCenter,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        math.min(
          size.width,
          size.height,
        ) /
        2 *
        0.76;

    _drawCompassRose(
      canvas,
      center,
      radius,
    );

    _drawBearingLine(
      canvas,
      aircraftCenter,
      beaconCenter,
    );
  }

  void _drawBearingLine(
    Canvas canvas,
    Offset aircraft,
    Offset beacon,
  ) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      aircraft,
      beacon,
      paint,
    );
  }

  void _drawCompassRose(
    Canvas canvas,
    Offset center,
    double radius,
  ) {
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black;

    canvas.drawCircle(
      center,
      radius,
      circlePaint,
    );

    for (int degrees = 0;
        degrees < 360;
        degrees += 10) {
      final angle =
          (degrees - 90) *
          math.pi /
          180;

      final isMajor =
          degrees % 30 == 0;

      final tickLength =
          isMajor ? 22.0 : 10.0;

      final tickPaint = Paint()
        ..strokeWidth =
            isMajor ? 3 : 1
        ..color = Colors.black;

      final outer = Offset(
        center.dx +
            radius * math.cos(angle),
        center.dy +
            radius * math.sin(angle),
      );

      final inner = Offset(
        center.dx +
            (radius - tickLength) *
                math.cos(angle),
        center.dy +
            (radius - tickLength) *
                math.sin(angle),
      );

      canvas.drawLine(
        inner,
        outer,
        tickPaint,
      );

      if (isMajor) {
        _drawDegreeLabel(
          canvas,
          center,
          radius,
          degrees,
        );

        _drawRadialGuide(
          canvas,
          center,
          radius,
          degrees,
        );
      }
    }

    _drawCardinal(
      canvas,
      center,
      radius,
      0,
      'N',
    );

    _drawCardinal(
      canvas,
      center,
      radius,
      90,
      'E',
    );

    _drawCardinal(
      canvas,
      center,
      radius,
      180,
      'S',
    );

    _drawCardinal(
      canvas,
      center,
      radius,
      270,
      'W',
    );
  }

  void _drawDegreeLabel(
    Canvas canvas,
    Offset center,
    double radius,
    int degrees,
  ) {
    final text =
        degrees.toString().padLeft(3, '0');

    final painter = TextPainter(
      text: TextSpan(
        text: '$text°',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final angle =
        (degrees - 90) *
        math.pi /
        180;

    final labelRadius =
        radius + 28;

    final position = Offset(
      center.dx +
          labelRadius *
              math.cos(angle) -
          painter.width / 2,
      center.dy +
          labelRadius *
              math.sin(angle) -
          painter.height / 2,
    );

    painter.paint(
      canvas,
      position,
    );
  }

  void _drawCardinal(
    Canvas canvas,
    Offset center,
    double radius,
    int degrees,
    String text,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();

    final angle =
        (degrees - 90) *
        math.pi /
        180;

    final labelRadius =
        radius - 50;

    final position = Offset(
      center.dx +
          labelRadius *
              math.cos(angle) -
          painter.width / 2,
      center.dy +
          labelRadius *
              math.sin(angle) -
          painter.height / 2,
    );

    painter.paint(
      canvas,
      position,
    );
  }

  void _drawRadialGuide(
    Canvas canvas,
    Offset center,
    double radius,
    int degrees,
  ) {
    final angle =
        (degrees - 90) *
        math.pi /
        180;

    final startRadius = 60.0;
    final endRadius =
        radius - 25;

    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    const dashLength = 7.0;
    const gapLength = 7.0;

    double current = startRadius;

    while (current < endRadius) {
      final start = Offset(
        center.dx +
            current *
                math.cos(angle),
        center.dy +
            current *
                math.sin(angle),
      );

      final dashEnd = math.min(
        current + dashLength,
        endRadius,
      );

      final end = Offset(
        center.dx +
            dashEnd *
                math.cos(angle),
        center.dy +
            dashEnd *
                math.sin(angle),
      );

      canvas.drawLine(
        start,
        end,
        paint,
      );

      current +=
          dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(
    covariant NavigationPainter oldDelegate,
  ) {
    return oldDelegate.aircraftCenter !=
            aircraftCenter ||
        oldDelegate.beaconCenter !=
            beaconCenter;
  }
}

class AircraftPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    final path = Path();

    // Grundriktning: nosen pekar mot 000°.
    path.moveTo(w * 0.50, h * 0.02);

    // Höger sida av flygkroppen
    path.lineTo(w * 0.58, h * 0.35);

    // Höger vinge
    path.lineTo(w * 0.95, h * 0.55);
    path.lineTo(w * 0.95, h * 0.65);
    path.lineTo(w * 0.58, h * 0.55);

    // Höger stjärtplan
    path.lineTo(w * 0.58, h * 0.82);
    path.lineTo(w * 0.75, h * 0.92);
    path.lineTo(w * 0.75, h * 0.98);

    // Bakre flygkropp
    path.lineTo(w * 0.50, h * 0.92);

    // Vänster stjärtplan
    path.lineTo(w * 0.25, h * 0.98);
    path.lineTo(w * 0.25, h * 0.92);
    path.lineTo(w * 0.42, h * 0.82);

    // Vänster vinge
    path.lineTo(w * 0.42, h * 0.55);
    path.lineTo(w * 0.05, h * 0.65);
    path.lineTo(w * 0.05, h * 0.55);
    path.lineTo(w * 0.42, h * 0.35);

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}