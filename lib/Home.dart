import 'dart:html';

import 'package:camera/camera.dart';
import 'package:face_recognition_assignment/Utils_Scanner.dart';
import 'package:firebase_ml_vision_raw_bytes/firebase_ml_vision_raw_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isWorking = false;
  CameraController? cameraController;
  FaceDetector? faceDetector;
  Size? size;
  List<Face>? facesList;
  CameraDescription? description;
  CameraLensDirection cameraDirection = CameraLensDirection.front;
  initCamera() async {
    description = await UtilsScanner.getCamera(cameraDirection);
    cameraController = CameraController(description!, ResolutionPreset.medium);
    faceDetector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(
        enableClassification: true,
        minFaceSize: 8.1,
        mode: FaceDetectorMode.fast));
    cameraController!.initialize().then(
      (value) {
        if (!mounted) {
          return;
        }
        cameraController!.startImageStream((imageFromStream) {
          if (isWorking) {
            isWorking = true;
            performDetectionOnStreamFrames(imageFromStream);
          }
        });
      },
    );
  }

  dynamic scanResults;
  performDetectionOnStreamFrames(CameraImage cameraImage) async {
    UtilsScanner.detect(
            image: cameraImage,
            detectInImage: faceDetector!.processImage,
            imageRotaion: description!.sensorOrientation)
        .then(
      (dynamic results) {
        setState(() {
          scanResults = results;
        });
      },
    ).whenComplete(() {
      isWorking = false;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initCamera();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    cameraController?.dispose();
    faceDetector!.close();
  }

  Widget buildResult() {
    if (scanResults == null ||
        cameraController == null ||
        cameraController!.value.isInitialized) {
      return Text("");
    }
    final Size imageSize = Size(cameraController!.value.previewSize!.height,
        cameraController!.value.previewSize!.width);
    CustomPainter customPainter =
        FaceDetectorPainter(imageSize, scanResults, cameraDirection);
    return CustomPaint(
      painter: customPainter,
    );
  }

  toggleCameraFrontOrBack() async {
    if (cameraDirection == CameraLensDirection.front) {
      cameraDirection = CameraLensDirection.back;
    } else {
      cameraDirection = CameraLensDirection.front;
    }
    await cameraController!.stopImageStream();
    await cameraController!.dispose();
    setState(() {
      cameraController = null;
    });
    initCamera();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackWidgetChildren = [];
    size = MediaQuery.of(context).size;
    if (cameraController != null) {
      stackWidgetChildren.add(Positioned(
          top: 0,
          left: 0,
          width: size!.width,
          height: size!.height,
          child: Container(
            child: (cameraController!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: cameraController!.value.aspectRatio,
                    child: CameraPreview(cameraController!),
                  )
                : Container(),
          )));
    }

    stackWidgetChildren.add(Positioned(
        top: 0,
        left: 0,
        width: size!.width,
        height: size!.height - 250,
        child: Container(
          child: buildResult(),
        )));
    stackWidgetChildren.add(Positioned(
        top: size!.height - 250,
        left: 0,
        width: size!.width,
        height: 250,
        child: Container(
          child: Column(
            children: [
              IconButton(
                  onPressed: () {
                    toggleCameraFrontOrBack();
                  },
                  icon: Icon(Icons.cached_rounded))
            ],
          ),
        )));
    return Scaffold(
      body: Container(
          child: Stack(
        children: stackWidgetChildren,
      )),
    );
  }
}

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(
      this.absoluteImageSize, this.faces, this.cameraLensDirection);
  final Size absoluteImageSize;
  final List<Face> faces;
  CameraLensDirection cameraLensDirection;
  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (Face face in faces) {
      canvas.drawRect(
          Rect.fromLTRB(
            cameraLensDirection == CameraLensDirection.front
                ? (absoluteImageSize.width - face.boundingBox.right) * scaleX
                : face.boundingBox.left * scaleX,
            face.boundingBox.top * scaleY,
            cameraLensDirection == CameraLensDirection.front
                ? (absoluteImageSize.width - face.boundingBox.left) * scaleX
                : face.boundingBox.right * scaleX,
            face.boundingBox.bottom * scaleY,
          ),
          paint);
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    // TODO: implement shouldRepaint
    throw oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
