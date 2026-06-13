import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class ZoomableImage extends StatelessWidget {
  final String imagePath;
  final double height;

  const ZoomableImage({
    super.key,
    required this.imagePath,
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
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: PhotoView(
                imageProvider: FileImage(File(imagePath)),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
        );
      },
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
        ),
        child: Hero(
          tag: imagePath,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }
}
