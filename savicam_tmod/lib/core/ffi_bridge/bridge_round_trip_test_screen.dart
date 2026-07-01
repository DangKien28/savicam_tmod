import 'package:flutter/material.dart';
import 'method_channel_bridge.dart';

/// BridgeRoundTripTestScreen
///
/// Màn hình kiểm thử trực quan cho TASK-W1-01.
/// Thực hiện 3 lời gọi round-trip lên native layer và hiển thị kết quả:
///   1. ping  → kỳ vọng "pong"
///   2. getVersion → kỳ vọng version string
///   3. echo("Hello from Dart") → kỳ vọng "[native-echo] Hello from Dart"
///
/// Cách chạy: Mount widget này vào bất kỳ route nào trong khi debug.
class BridgeRoundTripTestScreen extends StatefulWidget {
  const BridgeRoundTripTestScreen({super.key});

  @override
  State<BridgeRoundTripTestScreen> createState() =>
      _BridgeRoundTripTestScreenState();
}

class _BridgeRoundTripTestScreenState
    extends State<BridgeRoundTripTestScreen> {
  final _bridge = MethodChannelBridge();

  final List<_TestResult> _results = [];
  bool _running = false;

  Future<void> _runAllTests() async {
    setState(() {
      _results.clear();
      _running = true;
    });

    await _runTest(
      name: 'ping',
      fn: () => _bridge.ping(),
      expected: 'pong',
    );

    await _runTest(
      name: 'getVersion',
      fn: () => _bridge.getNativeVersion(),
      expected: 'savicam-native/1.0.0 (W1-01)',
    );

    await _runTest(
      name: 'echo("Hello from Dart")',
      fn: () => _bridge.echo('Hello from Dart'),
      expected: '[native-echo] Hello from Dart',
    );

    setState(() => _running = false);
  }

  Future<void> _runTest({
    required String name,
    required Future<String> Function() fn,
    required String expected,
  }) async {
    try {
      final response = await fn();
      final passed = response == expected;
      setState(() {
        _results.add(_TestResult(
          name: name,
          response: response,
          passed: passed,
          error: passed ? null : 'Expected: "$expected"',
        ));
      });
    } on BridgeException catch (e) {
      setState(() {
        _results.add(_TestResult(
          name: name,
          response: null,
          passed: false,
          error: e.toString(),
        ));
      });
    } catch (e) {
      setState(() {
        _results.add(_TestResult(
          name: name,
          response: null,
          passed: false,
          error: 'Unexpected: $e',
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPassed =
        _results.isNotEmpty && _results.every((r) => r.passed);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D27),
        title: const Text(
          'TASK-W1-01 · MethodChannel Round-Trip Test',
          style: TextStyle(fontSize: 14, color: Color(0xFFB0B8D0)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header badge ─────────────────────────────────────────────
            _StatusBadge(
              running: _running,
              done: _results.isNotEmpty && !_running,
              allPassed: allPassed,
            ),
            const SizedBox(height: 20),

            // ── Results list ──────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ResultCard(result: _results[i]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Run button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _running ? null : _runAllTests,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_running ? 'Đang kiểm thử…' : 'Chạy Round-Trip Test'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F7FFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Internal widgets
// =============================================================================

class _StatusBadge extends StatelessWidget {
  final bool running;
  final bool done;
  final bool allPassed;

  const _StatusBadge(
      {required this.running, required this.done, required this.allPassed});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    IconData icon;

    if (running) {
      bg = const Color(0xFF2A2D3E);
      label = 'Đang chạy…';
      icon = Icons.sync_rounded;
    } else if (!done) {
      bg = const Color(0xFF2A2D3E);
      label = 'Chưa chạy';
      icon = Icons.radio_button_unchecked_rounded;
    } else if (allPassed) {
      bg = const Color(0xFF1A3A2A);
      label = '✓ Tất cả test PASSED — DoD đạt';
      icon = Icons.check_circle_rounded;
    } else {
      bg = const Color(0xFF3A1A1A);
      label = '✗ Có test FAILED';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: allPassed && done
              ? const Color(0xFF34D399)
              : !done || running
                  ? const Color(0xFF3A3E52)
                  : const Color(0xFFEF4444),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: allPassed && done
                  ? const Color(0xFF34D399)
                  : !done || running
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFB0B8D0),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _TestResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: result.passed
              ? const Color(0xFF34D399).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.passed
                    ? Icons.check_circle_outline_rounded
                    : Icons.highlight_off_rounded,
                size: 16,
                color: result.passed
                    ? const Color(0xFF34D399)
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.name,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: result.passed
                      ? const Color(0xFF34D399).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result.passed ? 'PASS' : 'FAIL',
                  style: TextStyle(
                    color: result.passed
                        ? const Color(0xFF34D399)
                        : const Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          if (result.response != null) ...[
            const SizedBox(height: 8),
            Text(
              'Response: "${result.response}"',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (result.error != null) ...[
            const SizedBox(height: 6),
            Text(
              result.error!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TestResult {
  final String name;
  final String? response;
  final bool passed;
  final String? error;

  const _TestResult({
    required this.name,
    required this.response,
    required this.passed,
    this.error,
  });
}
