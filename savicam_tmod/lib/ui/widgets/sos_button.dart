import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../features/sos_module/sos_controller.dart';

/// Nút SOS tràn viền với anti-accidental touch (nhấn giữ 2 giây)
class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late final AnimationController _holdCtrl;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _holdCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_triggered) _fire();
      });
  }

  @override
  void dispose() {
    _holdCtrl.dispose();
    super.dispose();
  }

  void _fire() {
    setState(() => _triggered = true);
    GetIt.instance<SosController>().triggerSos(reason: 'Nút SOS được nhấn bởi người dùng');
  }

  void _reset() {
    _holdCtrl.reset();
    setState(() => _triggered = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) { if (!_triggered) _holdCtrl.forward(); },
      onLongPressEnd: (_) { if (!_triggered) _holdCtrl.reverse(); },
      onDoubleTap: _triggered ? _reset : null,
      child: AnimatedBuilder(
        animation: _holdCtrl,
        builder: (_, __) {
          return Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: _triggered ? const Color(0xFFFF3333) : const Color(0xFFCC0000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFFF00), width: 4),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_triggered && _holdCtrl.value > 0)
                  LinearProgressIndicator(
                    value: _holdCtrl.value,
                    color: const Color(0xFFFFFF00),
                    backgroundColor: Colors.transparent,
                    minHeight: 6,
                  ),
                const SizedBox(height: 8),
                Text(
                  _triggered ? 'ĐANG GỬI SOS...' : 'SOS KHẨN CẤP\n(NHẤN GIỮ 2 GIÂY)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
