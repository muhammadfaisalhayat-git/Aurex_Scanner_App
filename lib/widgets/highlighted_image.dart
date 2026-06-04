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
    return LayoutBuilder(
      builder: (context, constraints) {
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
                          _buildOverlay(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: Stack(
            children: [
              ZoomableImage(imagePath: imagePath, height: height),
              SizedBox(
                height: height,
                width: double.infinity,
                child: _buildOverlay(context),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return CustomPaint(
      painter: BoxPainter(mfgBox: mfgBox, expBox: expBox),
    );
  }
}

class BoxPainter extends CustomPainter {
  final String? mfgBox;
  final String? expBox;
  BoxPainter({this.mfgBox, this.expBox});

  @override
  void paint(Canvas canvas, Size size) {
    // Note: To make boxes accurate, we would need the original image resolution.
    // Since we don't have it here, we use the coordinate data for symbolic highlighting.
    if (mfgBox != null) _drawBox(canvas, mfgBox!, Colors.green, "MFG");
    if (expBox != null) _drawBox(canvas, expBox!, Colors.red, "EXP");
  }

  void _drawBox(Canvas canvas, String coords, Color color, String label) {
    try {
      final p = coords.split(',').map((e) => double.parse(e)).toList();
      // Heuristic: Map 1000-unit coordinates to current canvas size
      double scaleX = canvas.getLocalClipBounds().width / 1000.0;
      double scaleY = canvas.getLocalClipBounds().height / 1000.0;
      
      final rect = Rect.fromLTRB(p[0] * scaleX, p[1] * scaleY, p[2] * scaleX, p[3] * scaleY);
      final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.0;
      canvas.drawRect(rect, paint);
      
      TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.black54)),
        textDirection: TextDirection.ltr,
      )..layout()..paint(canvas, Offset(rect.left, rect.top - 12));
    } catch (_) {}
  }
  @override
  bool shouldRepaint(BoxPainter old) => true;
}
