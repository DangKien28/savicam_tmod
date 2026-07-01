import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Quản lý kết nối WebSocket cho real-time events (SOS tracking, live alerts)
class WebSocketManager {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final void Function(Map<String, dynamic>)? onMessage;
  final void Function()? onDisconnect;

  WebSocketManager({this.onMessage, this.onDisconnect});

  bool get isConnected => _channel != null;

  void connect(String url) {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final map = json.decode(data as String) as Map<String, dynamic>;
          onMessage?.call(map);
        } catch (_) {}
      },
      onDone: () {
        _channel = null;
        onDisconnect?.call();
      },
      onError: (_) {
        _channel = null;
        onDisconnect?.call();
      },
    );
  }

  void send(Map<String, dynamic> data) {
    _channel?.sink.add(json.encode(data));
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
