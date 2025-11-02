import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:photo_uploader/main.dart'; // Make sure this imports your main.dart file

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {

    const MockCameraDescription mockCamera = MockCameraDescription(
      name: 'mock_cam',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );


    await tester.pumpWidget(const MyApp(camera: mockCamera));


    expect(find.byType(FutureBuilder<void>), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Capture & Upload'), findsOneWidget);
  });
}


class MockCameraDescription extends CameraDescription {
  const MockCameraDescription({
    required super.name,
    required super.lensDirection,
    required super.sensorOrientation,
  });
}