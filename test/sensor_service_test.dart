import 'dart:async';

import 'package:angle_craft/services/sensor_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  test('low-pass filters accelerometer movement', () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast(
      sync: true,
    );
    final gyroscope = StreamController<GyroscopeEvent>.broadcast(sync: true);
    final service = SensorService(
      accelerometerEvents: accelerometer.stream,
      gyroscopeEvents: gyroscope.stream,
    );
    final readings = <(double, double)>[];
    service.startListening((roll, pitch) => readings.add((roll, pitch)));

    final start = DateTime.utc(2026);
    accelerometer.add(AccelerometerEvent(0, 9.81, 0, start));
    for (var sample = 1; sample <= 20; sample++) {
      accelerometer.add(
        AccelerometerEvent(
          9.81,
          0,
          0,
          start.add(Duration(milliseconds: sample * 20)),
        ),
      );
    }

    expect(readings.first.$1, closeTo(0, 0.01));
    expect(readings.last.$1, greaterThan(40));
    expect(readings.last.$1, lessThan(90));

    service.stopListening();
    await accelerometer.close();
    await gyroscope.close();
  });

  test('holds level readings steady despite small sensor noise', () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast(
      sync: true,
    );
    final gyroscope = StreamController<GyroscopeEvent>.broadcast(sync: true);
    final service = SensorService(
      accelerometerEvents: accelerometer.stream,
      gyroscopeEvents: gyroscope.stream,
    );
    final readings = <(double, double)>[];
    final start = DateTime.utc(2026);
    service.startListening((roll, pitch) => readings.add((roll, pitch)));

    for (var sample = 0; sample < 50; sample++) {
      final timestamp = start.add(Duration(milliseconds: sample * 20));
      accelerometer.add(
        AccelerometerEvent(sample.isEven ? 0.05 : -0.05, 9.81, 0, timestamp),
      );
      gyroscope.add(
        GyroscopeEvent(0, 0, 0.01, timestamp),
      );
    }

    expect(readings.last.$1, 0);
    expect(readings.last.$2, 0);

    service.stopListening();
    await accelerometer.close();
    await gyroscope.close();
  });

  test('learns stationary gyroscope bias instead of drifting', () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast(
      sync: true,
    );
    final gyroscope = StreamController<GyroscopeEvent>.broadcast(sync: true);
    final service = SensorService(
      accelerometerEvents: accelerometer.stream,
      gyroscopeEvents: gyroscope.stream,
    );
    final readings = <(double, double)>[];
    final start = DateTime.utc(2026);
    service.startListening((roll, pitch) => readings.add((roll, pitch)));

    for (var sample = 0; sample < 100; sample++) {
      final timestamp = start.add(Duration(milliseconds: sample * 20));
      accelerometer.add(AccelerometerEvent(0, 9.81, 0, timestamp));
      gyroscope.add(GyroscopeEvent(0, 0, 0.05, timestamp));
    }

    expect(readings.last.$1, 0);

    service.stopListening();
    await accelerometer.close();
    await gyroscope.close();
  });

  test('uses gyroscope rotation between gravity corrections', () async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast(
      sync: true,
    );
    final gyroscope = StreamController<GyroscopeEvent>.broadcast(sync: true);
    final service = SensorService(
      accelerometerEvents: accelerometer.stream,
      gyroscopeEvents: gyroscope.stream,
    );
    final readings = <(double, double)>[];
    final start = DateTime.utc(2026);
    service.startListening((roll, pitch) => readings.add((roll, pitch)));

    accelerometer.add(AccelerometerEvent(0, 9.81, 0, start));
    gyroscope.add(GyroscopeEvent(0, 0, 0, start));
    gyroscope.add(
      GyroscopeEvent(0, 0, 1, start.add(const Duration(milliseconds: 20))),
    );

    expect(readings.last.$1, closeTo(1.1, 0.01));

    service.stopListening();
    await accelerometer.close();
    await gyroscope.close();
  });
}
