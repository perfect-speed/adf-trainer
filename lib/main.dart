import 'dart:async';
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
      title: 'VOR Trainer',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFFEAF5FB),
        appBar: AppBar(
          title: const Text('VOR Trainer'),
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

  Offset aircraftPosition = const Offset(250, 250);

  double heading = 90;
  double selectedCourse = 0;
  bool isFlying = false;
  Timer? flightTimer;
  double aircraftSpeed = 20.0;
  double currentBoardSize = 0;

  static const double aircraftSize = 50;
  static const double pixelsPerNm = 30.0;

  double normalize360(double value) {
    value %= 360;

    if (value < 0) {
      value += 360;
    }

    return value;
  }

double calculateCdiDeviation({
  required double radial,
  required double selectedCourse,
}) {
  double difference =
      (radial - selectedCourse + 540) % 360 - 180;

  if (difference > 90) {
    difference -= 180;
  } else if (difference < -90) {
    difference += 180;
  }

  if (!difference.isFinite) {
    return 0.0;
  }

  return difference;
}

double calculateCdiDots({
  required double cdiDeviation,
  required String toFrom,
}) {
  if (toFrom == 'OFF') {
    return 0.0;
  }

  // Needle indication must reverse between TO and FROM
  // because the selected course direction is reversed.
  final sensedDeviation =
      toFrom == 'FROM'
          ? -cdiDeviation
          : cdiDeviation;

 if (!sensedDeviation.isFinite) {
    return 0.0;
  }



  // VOR: approximately 2 degrees per dot.
  final dots = sensedDeviation / 2.0;

  if (!dots.isFinite) {
    return 0.0;
  }

  // Limit the display to five dots either side.
  return dots.clamp(-5.0, 5.0).toDouble();
}

  double calculateRadial({
    required Offset aircraftCenter,
    required Offset vorCenter,
  }) {
    final dx = aircraftCenter.dx - vorCenter.dx;
    final dy = aircraftCenter.dy - vorCenter.dy;

    var angle =
        math.atan2(dx, -dy) * 180 / math.pi;

    if (angle < 0) {
      angle += 360;
    }

    return angle;
  }

double calculateDme({
  required Offset aircraftCenter,
  required Offset vorCenter,
}) {
  final dx = aircraftCenter.dx - vorCenter.dx;
  final dy = aircraftCenter.dy - vorCenter.dy;

  final distancePixels = math.sqrt(
    dx * dx + dy * dy,
  );

  return distancePixels / pixelsPerNm;
}



void startFlying() {
  if (isFlying) return;

  setState(() {
    isFlying = true;
  });

  const intervalMilliseconds = 50;

  flightTimer = Timer.periodic(
    const Duration(milliseconds: intervalMilliseconds),
    (timer) {
      setState(() {
        final headingRad = heading * math.pi / 180;

        final distance =
            aircraftSpeed * intervalMilliseconds / 1000;

        final dx = math.sin(headingRad) * distance;
        final dy = -math.cos(headingRad) * distance;

        final newX = aircraftPosition.dx + dx;
        final newY = aircraftPosition.dy + dy;

        final minX = aircraftSize / 2;
        final maxX = currentBoardSize - aircraftSize / 2;

        final minY = aircraftSize / 2;
        final maxY = currentBoardSize - aircraftSize / 2;

        final clampedX =
            newX.clamp(minX, maxX).toDouble();

        final clampedY =
            newY.clamp(minY, maxY).toDouble();

        aircraftPosition = Offset(
          clampedX,
          clampedY,
        );

        // Stoppa när flygplanet når kanten.
        if (clampedX != newX || clampedY != newY) {
          flightTimer?.cancel();
          flightTimer = null;
          isFlying = false;
        }
      });
    },
  );
}

void stopFlying() {
  flightTimer?.cancel();
  flightTimer = null;

  setState(() {
    isFlying = false;
  });
}

@override
void dispose() {
  flightTimer?.cancel();
  super.dispose();
}

String calculateToFrom({
  required double radial,
  required double selectedCourse,
  required double dme,
}) {
  // Osäker zon nära VOR-stationen.
  const double stationPassageZone = 0.5; // NM

  if (dme < stationPassageZone) {
    return 'OFF';
  }

  double difference =
      (selectedCourse - radial + 540) % 360 - 180;

  final absDifference = difference.abs();

  // Osäkerhet nära TO/FROM-gränsen.
  const double ambiguity = 1.0;

  if ((absDifference - 90).abs() <= ambiguity) {
    return 'OFF';
  }

  if (absDifference < 90) {
    return 'FROM';
  }

  return 'TO';
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

              currentBoardSize = boardSize;

              final beaconCenter = Offset(
                boardSize / 2,
                boardSize / 2,
              );

              // aircraftPosition ÄR flygplanets centrum.
              final aircraftCenter = aircraftPosition;


              final radial = calculateRadial(aircraftCenter: aircraftCenter, 
              vorCenter: beaconCenter,);


final dme = calculateDme(
  aircraftCenter: aircraftCenter,
  vorCenter: beaconCenter,
);

final toFrom = calculateToFrom(   radial: radial,   
selectedCourse: selectedCourse,
dme: dme,
);

final cdiDeviation = calculateCdiDeviation(
  radial: radial,
  selectedCourse: selectedCourse,
);

final cdiDots = calculateCdiDots(
  cdiDeviation: cdiDeviation,
  toFrom: toFrom,
);

              return Column(
                children: [
                  const SizedBox(height: 8),

                  // Informationspanelen ligger nu UTANFÖR
                  // själva kompassrosens Stack.
                  VorDataPanel(
                    heading: heading,
                    radial: radial,
                    selectedCourse: selectedCourse, 
                    toFrom: toFrom,
                    cdiDeviation: cdiDeviation,
                    cdiDots: cdiDots,
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

    // NYTT: OBS-kurslinjen
    Positioned.fill(
      child: CustomPaint(
        painter: ObsCoursePainter(
          vorCenter: beaconCenter,
          selectedCourse: selectedCourse,
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

                            // VOR-stationen
                            Positioned(
                              left: beaconCenter.dx - 45,
                              top: beaconCenter.dy - 45,
                              child: const VorStation(
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

const SizedBox(height: 12),

ElevatedButton.icon(
  onPressed: () {
    if (isFlying) {
      stopFlying();
    } else {
      startFlying();
    }
  },
  icon: Icon(
    isFlying
        ? Icons.pause
        : Icons.play_arrow,
  ),
  label: Text(
    isFlying ? 'Pause' : 'Play',
  ),
),

const SizedBox(height: 12),

const SizedBox(height: 16),

Text(
  'OBS Course: ${formatBearing(selectedCourse)}°',
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

Slider(
  value: selectedCourse,
  min: 0,
  max: 359,
  divisions: 359,
  label: '${formatBearing(selectedCourse)}°',
  onChanged: (value) {
    setState(() {
      selectedCourse = value;
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

class VorStation extends StatelessWidget {
  final double size;

  const VorStation({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: VorStationPainter(),
    );
  }
}

class ObsCoursePainter extends CustomPainter {
  final Offset vorCenter;
  final double selectedCourse;

  ObsCoursePainter({
    required this.vorCenter,
    required this.selectedCourse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final courseRad = selectedCourse * math.pi / 180;

    // I skärmkoordinater är +y nedåt.
    // 000° = upp
    // 090° = höger
    final dx = math.sin(courseRad);
    final dy = -math.cos(courseRad);

    // Samma ungefärliga radie som kompassrosen.
    final radius =
        math.min(size.width, size.height) / 2 * 0.76;

    // Vald kursriktning.
    final forward = Offset(
      vorCenter.dx + dx * radius,
      vorCenter.dy + dy * radius,
    );

    // Reciproka riktningen, 180° åt andra hållet.
    final backward = Offset(
      vorCenter.dx - dx * radius,
      vorCenter.dy - dy * radius,
    );

    // Rita OBS-kurslinjen.
    final linePaint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      backward,
      forward,
      linePaint,
    );

    // -------------------------------------------------
    // PIL PÅ DEN RECIPROKA SIDAN
    // -------------------------------------------------

    // Pilen ska peka från VOR ut mot reciprocal course.
    final arrowDx = dx;
    final arrowDy = dy;

    // Placera pilspetsen ganska nära kompassrosen.
    final arrowDistance = radius * 0.90;

    final arrowTip = Offset(
      vorCenter.dx + arrowDx * arrowDistance,
      vorCenter.dy + arrowDy * arrowDistance,
    );

    // Pilens storlek.
    const double arrowLength = 22.0;
    const double arrowWidth = 16.0;

    // Punkten där pilhuvudets bakre kant ligger.
    final arrowBaseCenter = Offset(
      arrowTip.dx - arrowDx * arrowLength,
      arrowTip.dy - arrowDy * arrowLength,
    );

    // Vinkelrät vektor för pilens bredd.
    final perpX = -arrowDy;
    final perpY = arrowDx;

    final arrowLeft = Offset(
      arrowBaseCenter.dx + perpX * arrowWidth / 2,
      arrowBaseCenter.dy + perpY * arrowWidth / 2,
    );

    final arrowRight = Offset(
      arrowBaseCenter.dx - perpX * arrowWidth / 2,
      arrowBaseCenter.dy - perpY * arrowWidth / 2,
    );

    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(arrowLeft.dx, arrowLeft.dy)
      ..lineTo(arrowRight.dx, arrowRight.dy)
      ..close();

    final arrowPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      arrowPath,
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ObsCoursePainter oldDelegate) {
    return oldDelegate.selectedCourse != selectedCourse ||
        oldDelegate.vorCenter != vorCenter;
  }
}
class VorStationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final r = size.width * 0.26;

    // Enkel sexhörning som VOR-symbol
    final path = Path();

    for (int i = 0; i < 6; i++) {
      final angle = (-90 + i * 60) * math.pi / 180;

      final p = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    path.close();
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      center,
      size.width * 0.04,
      dotPaint,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'VOR',
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

double calculateRadial({
  required Offset aircraftCenter,
  required Offset vorCenter,
}) {
  final dx = aircraftCenter.dx - vorCenter.dx;
  final dy = aircraftCenter.dy - vorCenter.dy;

  var angle =
      math.atan2(dx, -dy) * 180 / math.pi;

  if (angle < 0) {
    angle += 360;
  }

  return angle;
}

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
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

class VorDataPanel extends StatelessWidget {
  final double heading;
  final double radial;
  final double selectedCourse;
  final String toFrom;
  final double cdiDeviation;
  final double cdiDots;

  const VorDataPanel({
    super.key,
    required this.heading,
    required this.radial,
    required this.selectedCourse,
    required this.toFrom,
    required this.cdiDeviation,
    required this.cdiDots,
  });

  String f(double value) {
    return value.round().toString().padLeft(3, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HDG ${f(heading)}°',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 28),
              Text(
                'RADIAL ${f(radial)}°',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

Text(
  'CDI ${cdiDeviation.toStringAsFixed(1)}°',
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 8),

CdiIndicator(
  dots: cdiDots,
  off: toFrom == 'OFF',
),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OBS ${f(selectedCourse)}°',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 28),
              Text(
                toFrom,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CdiIndicator extends StatelessWidget {
  final double dots;
  final bool off;

  const CdiIndicator({
    super.key,
    required this.dots,
    required this.off,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 240;
    const double height = 42;

    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double margin = 10;

          final usableWidth =
              constraints.maxWidth - 2 * margin;

          // 11 punkter ger 10 intervall.
          final dotSpacing = usableWidth / 10;

          final centerX =
              margin + 5 * dotSpacing;

final safeDots = dots.isFinite ? dots : 0.0;
          final needleX =
              centerX + safeDots * dotSpacing;

          return Stack(
            children: [
              // De 11 CDI-punkterna
              for (int index = 0; index < 11; index++)
                Positioned(
                  left: margin +
                      index * dotSpacing -
                      (index == 5 ? 5 : 2.5),
                  top: height / 2 -
                      (index == 5 ? 5 : 2.5),
                  child: Container(
                    width: index == 5 ? 10 : 5,
                    height: index == 5 ? 10 : 5,
                    decoration: BoxDecoration(
                      color: index == 5
                          ? Colors.black
                          : Colors.black54,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

              // CDI-nålen
              if (!off)
                Positioned(
                  left: needleX - 1.5,
                  top: 4,
                  child: Container(
                    width: 3,
                    height: 34,
                    color: Colors.deepPurple,
                  ),
                ),

              // OFF-flagga
              if (off)
                const Positioned(
                  right: 0,
                  top: 0,
                  child: Text(
                    'OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}