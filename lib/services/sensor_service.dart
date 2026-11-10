import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

typedef SensorLevelCallback = void Function(double roll, double pitch);
typedef SensorErrorCallback = void Function(Object error);

class SensorService {
  SensorService({
    Stream<AccelerometerEvent>? accelerometerEvents,
    Stream<GyroscopeEvent>? gyroscopeEvents,
  }) : _accelerometerEvents =
           accelerometerEvents ??
           accelerometerEventStream(
             samplingPeriod: SensorInterval.gameInterval,
           ),
       _gyroscopeEvents =
           gyroscopeEvents ??
           gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval);

  static const double _gravityFilterFactor = 0.12;
  static const double _complementaryFilterFactor = 0.98;
  static const double _gyroRateDeadband = 0.025;
  static const double _stationaryGyroThreshold = 0.12;
  static const double _stationaryGravityTolerance = 0.35;
  static const double _gyroBiasFilterFactor = 0.02;
  static const double _angleDeadband = 0.75;
  static const double _radiansToDegrees = 180 / pi;

  final Stream<AccelerometerEvent> _accelerometerEvents;
  final Stream<GyroscopeEvent> _gyroscopeEvents;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;
  double _roll = 0;
  double _pitch = 0;
  double _gyroBiasX = 0;
  double _gyroBiasZ = 0;
  bool _hasGravityReading = false;
  DateTime? _lastGyroscopeTimestamp;

  void startListening(
    SensorLevelCallback onSensorChanged, {
    SensorErrorCallback? onError,
  }) {
    stopListening();
    _hasGravityReading = false;
    _lastGyroscopeTimestamp = null;
    _roll = 0;
    _pitch = 0;
    _gyroBiasX = 0;
    _gyroBiasZ = 0;

    _accelerometerSubscription = _accelerometerEvents
        .listen(
          (event) {
            if (!_hasGravityReading) {
              _gravityX = event.x;
              _gravityY = event.y;
              _gravityZ = event.z;
              _hasGravityReading = true;
            } else {
              _gravityX += _gravityFilterFactor * (event.x - _gravityX);
              _gravityY += _gravityFilterFactor * (event.y - _gravityY);
              _gravityZ += _gravityFilterFactor * (event.z - _gravityZ);
            }

            final accelerometerRoll = atan2(_gravityX, _gravityY) *
                _radiansToDegrees;
            final accelerometerPitch =
                atan2(_gravityZ, sqrt(_gravityX * _gravityX + _gravityY * _gravityY)) *
                _radiansToDegrees;

            if (_lastGyroscopeTimestamp == null) {
              _roll = accelerometerRoll;
              _pitch = accelerometerPitch;
            } else {
              _roll = _fuseAngle(_roll, accelerometerRoll);
              _pitch = _fuseAngle(_pitch, accelerometerPitch);
            }
            _emitStableReading(onSensorChanged);
          },
          onError: (Object error) => onError?.call(error),
        );

    _gyroscopeSubscription = _gyroscopeEvents.listen(
      (event) {
        _updateGyroscopeBias(event);
        final previousTimestamp = _lastGyroscopeTimestamp;
        _lastGyroscopeTimestamp = event.timestamp;
        if (!_hasGravityReading || previousTimestamp == null) return;

        final elapsedSeconds =
            event.timestamp.difference(previousTimestamp).inMicroseconds /
            Duration.microsecondsPerSecond;
        if (elapsedSeconds <= 0 || elapsedSeconds > 0.1) return;

        _roll += _removeGyroNoise(event.z - _gyroBiasZ) *
            elapsedSeconds *
            _radiansToDegrees;
        _pitch += _removeGyroNoise(event.x - _gyroBiasX) *
            elapsedSeconds *
            _radiansToDegrees;
        _emitStableReading(onSensorChanged);
      },
      onError: (Object error) => onError?.call(error),
    );
  }

  double _fuseAngle(double gyroAngle, double accelerometerAngle) {
    final delta =
        ((accelerometerAngle - gyroAngle + 180) % 360 + 360) % 360 - 180;
    return gyroAngle + (1 - _complementaryFilterFactor) * delta;
  }

  double _removeGyroNoise(double angularVelocity) =>
      angularVelocity.abs() < _gyroRateDeadband ? 0 : angularVelocity;

  void _updateGyroscopeBias(GyroscopeEvent event) {
    if (!_hasGravityReading) return;

    final gravityMagnitude = sqrt(
      _gravityX * _gravityX + _gravityY * _gravityY + _gravityZ * _gravityZ,
    );
    final gyroMagnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final isStationary =
        (gravityMagnitude - 9.81).abs() < _stationaryGravityTolerance &&
        gyroMagnitude < _stationaryGyroThreshold;
    if (!isStationary) return;

    _gyroBiasX += _gyroBiasFilterFactor * (event.x - _gyroBiasX);
    _gyroBiasZ += _gyroBiasFilterFactor * (event.z - _gyroBiasZ);
  }

  void _emitStableReading(SensorLevelCallback onSensorChanged) {
    onSensorChanged(_stabilizeAngle(_roll), _stabilizeAngle(_pitch));
  }

  double _stabilizeAngle(double angle) {
    if (angle.abs() < _angleDeadband) return 0;
    return double.parse(angle.toStringAsFixed(1));
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
  }
}
