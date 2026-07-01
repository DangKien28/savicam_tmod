/// Một bước chỉ dẫn trong lộ trình offline.
class NavigationStep {
  /// Câu chỉ dẫn tiếng Việt, VD: "Rẽ trái vào Lê Duẩn, đi 120 mét"
  final String instruction;

  /// Khoảng cách của bước này (mét)
  final double distanceM;

  /// Hướng di chuyển (độ, 0–360, 0=Bắc, 90=Đông)
  final double bearing;

  const NavigationStep({
    required this.instruction,
    required this.distanceM,
    required this.bearing,
  });
}
