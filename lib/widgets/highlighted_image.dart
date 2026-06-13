import 'dart:io';
import 'package:flutter/material.dart';
import 'zoomable_image.dart';

class HighlightedImage extends StatelessWidget {
  final String imagePath;
  final String? mfgBox;
  final String? expBox;
  final double height;

  const HighlightedImage({
    super.key,
    required this.imagePath,
    this.mfgBox,
    this.expBox,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: InteractiveViewer(
                child: Center(
                  child: Stack(
                    children: [
                      Image.file(File(imagePath)),
                      _buildFullOverlay(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ZoomableImage(imagePath: imagePath, height: height),
          
          // Use FittedBox to scale the 1000x1000 coordinate system to match the image
          SizedBox(
            height: height,
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.contain, // MUST match ZoomableImage fit
              child: SizedBox(
                width: 1000,
                height: 1000,
                child: IgnorePointer(
                  child: _buildOverlay(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return CustomPaint(
      painter: BoxPainter(mfgBox: mfgBox, expBox: expBox),
    );
  }

  // Helper for the full-screen view where image is not restricted by 'height'
  Widget _buildFullOverlay(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 1000,
              height: 1000,
              child: _buildOverlay(context),
            ),
          );
        }
      ),
    );
  }
}

class BoxPainter extends CustomPainter {
  final String? mfgBox;
  final String? expBox;
  BoxPainter({this.mfgBox, this.expBox});

  @override
  void paint(Canvas canvas, Size size) {
    if (mfgBox != null) _drawBox(canvas, mfgBox!, Colors.green, "MFG");
    if (expBox != null) _drawBox(canvas, expBox!, Colors.red, "EXP");
  }

  void _drawBox(Canvas canvas, String coords, Color color, String label) {
    try {
      final p = coords.split(',').map((e) => double.parse(e)).toList();
      if (p.length < 4) return;

      // Coordinates are 0-1000, and canvas is 1000x1000 (set by parent SizedBox/FittedBox)
      final rect = Rect.fromLTRB(p[0], p[1], p[2], p[3]);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0; // Slightly thicker for visibility on 1000-unit scale
      
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), paint);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: label, 
          style: TextStyle(
            color: Colors.white, 
            fontSize: 24, // Larger font for 1000-unit scale
            fontWeight: FontWeight.bold,
          )
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRect = Rect.fromLTWH(
        rect.left, 
        rect.top - textPainter.height - 5, 
        textPainter.width + 10, 
        textPainter.height + 5
      );

      canvas.drawRect(labelRect, Paint()..color = color);
      textPainter.paint(canvas, Offset(rect.left + 5, rect.top - textPainter.height - 2));
      
    } catch (_) {}
  }

  @override
  bool shouldRepaint(BoxPainter old) => true;
}
