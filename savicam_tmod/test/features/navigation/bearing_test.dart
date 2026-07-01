import 'package:flutter_test/flutter_test.dart';

// Copy logic của hàm _bearingToInstruction từ offline_graph_engine.dart để test unit
String _bearingToInstruction(double delta, String roadName) {
  final d = ((delta + 540) % 360) - 180;
  final rn = roadName.isNotEmpty ? ' vào $roadName' : '';
  
  if (d.abs() < 20)             return 'Đi thẳng$rn';
  if (d > 20 && d < 80)         return 'Rẽ nhẹ phải$rn';
  if (d >= 80 && d < 150)       return 'Rẽ phải$rn';
  if (d >= 150)                 return 'Quay đầu';
  if (d < -20 && d > -80)       return 'Rẽ nhẹ trái$rn';
  if (d <= -80 && d > -150)     return 'Rẽ trái$rn';
  return 'Quay đầu';
}

void main() {
  group('Bearing Instruction Tests', () {
    test('Đi thẳng (delta < 20)', () {
      expect(_bearingToInstruction(0, ''), 'Đi thẳng');
      expect(_bearingToInstruction(19, 'Đường A'), 'Đi thẳng vào Đường A');
      expect(_bearingToInstruction(-19, ''), 'Đi thẳng');
      expect(_bearingToInstruction(360, ''), 'Đi thẳng'); // 360 -> 0
    });

    test('Rẽ nhẹ phải (20 < delta < 80)', () {
      expect(_bearingToInstruction(21, 'A'), 'Rẽ nhẹ phải vào A');
      expect(_bearingToInstruction(45, ''), 'Rẽ nhẹ phải');
      expect(_bearingToInstruction(79, 'B'), 'Rẽ nhẹ phải vào B');
    });

    test('Rẽ phải (80 <= delta < 150)', () {
      expect(_bearingToInstruction(80, ''), 'Rẽ phải');
      expect(_bearingToInstruction(90, 'C'), 'Rẽ phải vào C');
      expect(_bearingToInstruction(149, ''), 'Rẽ phải');
    });

    test('Rẽ nhẹ trái (-20 > delta > -80)', () {
      expect(_bearingToInstruction(-21, 'A'), 'Rẽ nhẹ trái vào A');
      expect(_bearingToInstruction(-45, ''), 'Rẽ nhẹ trái');
      expect(_bearingToInstruction(-79, 'B'), 'Rẽ nhẹ trái vào B');
    });

    test('Rẽ trái (-80 >= delta > -150)', () {
      expect(_bearingToInstruction(-80, ''), 'Rẽ trái');
      expect(_bearingToInstruction(-90, 'C'), 'Rẽ trái vào C');
      expect(_bearingToInstruction(-149, ''), 'Rẽ trái');
    });

    test('Quay đầu (delta >= 150 hoặc <= -150)', () {
      expect(_bearingToInstruction(150, ''), 'Quay đầu');
      expect(_bearingToInstruction(180, 'D'), 'Quay đầu'); // Không kèm tên đường
      expect(_bearingToInstruction(-150, ''), 'Quay đầu');
      expect(_bearingToInstruction(-180, ''), 'Quay đầu');
    });
  });
}
