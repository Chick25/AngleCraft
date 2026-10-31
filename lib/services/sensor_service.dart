import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService{
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  void startListening(Function(double roll, double pitch) onSensorChanged) {
    _accelerometerSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      double roll = atan2(event.y, event.z) * (180/pi);
      double pitch = atan2(-event.x, sqrt(event.y * event.y + event.z * event.z)) * (180 /pi);

      onSensorChanged(roll, pitch);
    });
  }

  void stopListening(){
    _accelerometerSub?.cancel();
  }

}