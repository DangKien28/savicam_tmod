import '../../core/network/websocket_manager.dart';
import '../../core/services/location_service.dart';
import '../vision_alerts/vision_alert_controller.dart';

/// Data Source / Repository cho việc đẩy telemetry lên Relap
class LocationTrackingRepository {
  final WebSocketManager _webSocketManager;
  final LocationService _locationService;
  final VisionAlertController _visionController;

  LocationTrackingRepository(
    this._webSocketManager,
    this._locationService,
    this._visionController,
  );

  /// Thu thập GPS và Risk Status hiện tại, gửi qua WebSocket
  Future<void> pushTelemetry() async {
    if (!_webSocketManager.isConnected) return;

    final pos = await _locationService.getCurrentPosition();
    if (pos == null) return;

    final riskLevel = _visionController.currentRiskLevel.value;
    final riskStatus = _visionController.currentStatus.value;
    final nearestDist = _visionController.lastDistance.value;

    final payload = {
      'type': 'device_telemetry',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'heading': pos.heading,
      'speed': pos.speed,
      'vision_status': {
        'risk_level': riskLevel,
        'description': riskStatus,
        'nearest_obstacle_m': nearestDist,
      },
    };

    _webSocketManager.send(payload);
  }
}
