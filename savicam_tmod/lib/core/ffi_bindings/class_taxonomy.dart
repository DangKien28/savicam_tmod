// class_taxonomy.dart
// Bảng tra cứu 300 nhãn phát hiện của YOLOv8n SaViCam.
// class_id khớp 1:1 với dataset (1–300). ID = 0 là sentinel "không xác định".
//
// Cấu trúc tối ưu: const Map → O(1) lookup, compile-time constant,
// không phát sinh object allocation trong hot path của frame loop.
//
// Sử dụng:
//   final label = ClassTaxonomy.of(result.nearestClassId);
//   print(label.viName);  // "xe máy"

/// Module phân loại vật thể (khớp với cột "module" trong dataset)
enum ObjectModule {
  traffic,      // Phương tiện & Giao thông
  groundHazard, // Chướng ngại vật nền đường
  tallHazard,   // Chướng ngại vật tầm cao
  urban,        // Chỉ dẫn & Kiến trúc đô thị
  indoor,       // Môi trường trong nhà
  personal,     // Vật dụng cá nhân
  food,         // Thực phẩm & Đồ uống
  nature,       // Môi trường & Tự nhiên
  medical,      // Y tế & An toàn
  other,        // Khác & Đặc biệt
}

/// Metadata của 1 nhãn phát hiện
final class ClassLabel {
  final int id;
  final String enName;
  final String viName;
  final ObjectModule module;

  const ClassLabel({
    required this.id,
    required this.enName,
    required this.viName,
    required this.module,
  });

  /// Tên tiếng Việt viết hoa đầu câu, dùng cho TTS.
  String get ttsName => viName[0].toUpperCase() + viName.substring(1);

  @override
  String toString() => 'ClassLabel($id: $viName)';
}

/// Sentinel dùng khi class_id = 0 hoặc không tìm thấy trong taxonomy.
const ClassLabel kUnknownLabel = ClassLabel(
  id: 0,
  enName: 'unknown',
  viName: 'vật thể không xác định',
  module: ObjectModule.other,
);

/// Singleton bảng tra cứu toàn bộ 300 nhãn.
abstract final class ClassTaxonomy {
  /// Tra cứu nhãn theo [classId] (1–300).
  /// Trả về [kUnknownLabel] nếu id = 0 hoặc không có trong bảng.
  static ClassLabel of(int classId) =>
      _table[classId] ?? kUnknownLabel;

  /// Toàn bộ bảng taxonomy dưới dạng read-only list (dùng cho UI/debug).
  static List<ClassLabel> get allLabels => List.unmodifiable(_table.values);

  // ── Lookup table: compile-time const ────────────────────────────────────
  static const Map<int, ClassLabel> _table = {
    // ── Phương tiện & Giao thông (1–25) ─────────────────────────────────
    1:  ClassLabel(id: 1,  enName: 'car',                viName: 'ô tô',              module: ObjectModule.traffic),
    2:  ClassLabel(id: 2,  enName: 'motorbike',          viName: 'xe máy',            module: ObjectModule.traffic),
    3:  ClassLabel(id: 3,  enName: 'bus',                viName: 'xe buýt',           module: ObjectModule.traffic),
    4:  ClassLabel(id: 4,  enName: 'truck',              viName: 'xe tải',            module: ObjectModule.traffic),
    5:  ClassLabel(id: 5,  enName: 'bicycle',            viName: 'xe đạp',            module: ObjectModule.traffic),
    6:  ClassLabel(id: 6,  enName: 'tricycle',           viName: 'xe ba gác',         module: ObjectModule.traffic),
    7:  ClassLabel(id: 7,  enName: 'ambulance',          viName: 'xe cứu thương',     module: ObjectModule.traffic),
    8:  ClassLabel(id: 8,  enName: 'fire_truck',         viName: 'xe cứu hỏa',        module: ObjectModule.traffic),
    9:  ClassLabel(id: 9,  enName: 'police_car',         viName: 'xe cảnh sát',       module: ObjectModule.traffic),
    10: ClassLabel(id: 10, enName: 'shopping_cart',      viName: 'xe đẩy hàng',       module: ObjectModule.traffic),
    11: ClassLabel(id: 11, enName: 'wheelchair',         viName: 'xe lăn',            module: ObjectModule.traffic),
    12: ClassLabel(id: 12, enName: 'stroller',           viName: 'xe nôi',            module: ObjectModule.traffic),
    13: ClassLabel(id: 13, enName: 'pedestrian',         viName: 'người đi bộ',       module: ObjectModule.traffic),
    14: ClassLabel(id: 14, enName: 'dog',                viName: 'chó',               module: ObjectModule.traffic),
    15: ClassLabel(id: 15, enName: 'cat',                viName: 'mèo',               module: ObjectModule.traffic),
    16: ClassLabel(id: 16, enName: 'cyclo',              viName: 'xe xích lô',        module: ObjectModule.traffic),
    17: ClassLabel(id: 17, enName: 'garbage_truck',      viName: 'xe rác',            module: ObjectModule.traffic),
    18: ClassLabel(id: 18, enName: 'tanker_truck',       viName: 'xe bồn',            module: ObjectModule.traffic),
    19: ClassLabel(id: 19, enName: 'dump_truck',         viName: 'xe ben',            module: ObjectModule.traffic),
    20: ClassLabel(id: 20, enName: 'trailer',            viName: 'xe kéo',            module: ObjectModule.traffic),
    21: ClassLabel(id: 21, enName: 'forklift',           viName: 'xe nâng',           module: ObjectModule.traffic),
    22: ClassLabel(id: 22, enName: 'electric_car',       viName: 'xe điện',           module: ObjectModule.traffic),
    23: ClassLabel(id: 23, enName: 'train',              viName: 'tàu hỏa',           module: ObjectModule.traffic),
    24: ClassLabel(id: 24, enName: 'rickshaw',           viName: 'xích lô',           module: ObjectModule.traffic),
    25: ClassLabel(id: 25, enName: 'motorized_tricycle', viName: 'xe lôi',            module: ObjectModule.traffic),

    // ── Chướng ngại vật nền đường (26–55) ───────────────────────────────
    26: ClassLabel(id: 26, enName: 'pothole',            viName: 'hố',                module: ObjectModule.groundHazard),
    27: ClassLabel(id: 27, enName: 'puddle',             viName: 'vũng nước',         module: ObjectModule.groundHazard),
    28: ClassLabel(id: 28, enName: 'stairs',             viName: 'bậc thang',         module: ObjectModule.groundHazard),
    29: ClassLabel(id: 29, enName: 'road_pit',           viName: 'ổ gà',              module: ObjectModule.groundHazard),
    30: ClassLabel(id: 30, enName: 'manhole_cover',      viName: 'nắp cống',          module: ObjectModule.groundHazard),
    31: ClassLabel(id: 31, enName: 'speed_bump',         viName: 'gờ giảm tốc',       module: ObjectModule.groundHazard),
    32: ClassLabel(id: 32, enName: 'divider',            viName: 'con lươn',          module: ObjectModule.groundHazard),
    33: ClassLabel(id: 33, enName: 'flower_bed',         viName: 'bồn hoa',           module: ObjectModule.groundHazard),
    34: ClassLabel(id: 34, enName: 'tree_root',          viName: 'rễ cây',            module: ObjectModule.groundHazard),
    35: ClassLabel(id: 35, enName: 'sand_pile',          viName: 'đống cát',          module: ObjectModule.groundHazard),
    36: ClassLabel(id: 36, enName: 'brick_pile',         viName: 'đống gạch',         module: ObjectModule.groundHazard),
    37: ClassLabel(id: 37, enName: 'trash_pile',         viName: 'đống rác',          module: ObjectModule.groundHazard),
    38: ClassLabel(id: 38, enName: 'wooden_plank',       viName: 'ván gỗ',            module: ObjectModule.groundHazard),
    39: ClassLabel(id: 39, enName: 'glass_shard',        viName: 'miểng chai',        module: ObjectModule.groundHazard),
    40: ClassLabel(id: 40, enName: 'gutter',             viName: 'rãnh nước',         module: ObjectModule.groundHazard),
    41: ClassLabel(id: 41, enName: 'mud',                viName: 'bùn',               module: ObjectModule.groundHazard),
    42: ClassLabel(id: 42, enName: 'curb_ramp',          viName: 'bục rẽ',            module: ObjectModule.groundHazard),
    43: ClassLabel(id: 43, enName: 'sidewalk',           viName: 'vỉa hè',            module: ObjectModule.groundHazard),
    44: ClassLabel(id: 44, enName: 'ditch',              viName: 'mương nước',        module: ObjectModule.groundHazard),
    45: ClassLabel(id: 45, enName: 'catch_basin',        viName: 'hố ga',             module: ObjectModule.groundHazard),
    46: ClassLabel(id: 46, enName: 'construction_barrier', viName: 'rào chắn công trình', module: ObjectModule.groundHazard),
    47: ClassLabel(id: 47, enName: 'loose_brick',        viName: 'gạch lát bong tróc', module: ObjectModule.groundHazard),
    48: ClassLabel(id: 48, enName: 'lawn',               viName: 'bãi cỏ',            module: ObjectModule.groundHazard),
    49: ClassLabel(id: 49, enName: 'debris_pile',        viName: 'đống xà bần',       module: ObjectModule.groundHazard),
    50: ClassLabel(id: 50, enName: 'dry_leaf_pile',      viName: 'đống lá khô',       module: ObjectModule.groundHazard),
    51: ClassLabel(id: 51, enName: 'oil_puddle',         viName: 'vũng dầu',          module: ObjectModule.groundHazard),
    52: ClassLabel(id: 52, enName: 'broken_wire',        viName: 'dây điện đứt',      module: ObjectModule.groundHazard),
    53: ClassLabel(id: 53, enName: 'fallen_helmet',      viName: 'nón bảo hiểm rơi', module: ObjectModule.groundHazard),
    54: ClassLabel(id: 54, enName: 'boulder',            viName: 'đá tảng',           module: ObjectModule.groundHazard),
    55: ClassLabel(id: 55, enName: 'swampy_mud',         viName: 'bùn lầy',           module: ObjectModule.groundHazard),

    // ── Chướng ngại vật tầm cao (56–85) ─────────────────────────────────
    56: ClassLabel(id: 56, enName: 'tree',               viName: 'cây',               module: ObjectModule.tallHazard),
    57: ClassLabel(id: 57, enName: 'branch',             viName: 'cành cây',          module: ObjectModule.tallHazard),
    58: ClassLabel(id: 58, enName: 'trash_can',          viName: 'thùng rác',         module: ObjectModule.tallHazard),
    59: ClassLabel(id: 59, enName: 'stone_bench',        viName: 'ghế đá',            module: ObjectModule.tallHazard),
    60: ClassLabel(id: 60, enName: 'barrier',            viName: 'rào chắn',          module: ObjectModule.tallHazard),
    61: ClassLabel(id: 61, enName: 'barbed_wire',        viName: 'rào thép gai',      module: ObjectModule.tallHazard),
    62: ClassLabel(id: 62, enName: 'fire',               viName: 'lửa',               module: ObjectModule.tallHazard),
    63: ClassLabel(id: 63, enName: 'electric_pole',      viName: 'cột điện',          module: ObjectModule.tallHazard),
    64: ClassLabel(id: 64, enName: 'street_light',       viName: 'cột đèn',           module: ObjectModule.tallHazard),
    65: ClassLabel(id: 65, enName: 'electric_wire',      viName: 'dây điện',          module: ObjectModule.tallHazard),
    66: ClassLabel(id: 66, enName: 'cable',              viName: 'dây cáp',           module: ObjectModule.tallHazard),
    67: ClassLabel(id: 67, enName: 'railing',            viName: 'lan can',           module: ObjectModule.tallHazard),
    68: ClassLabel(id: 68, enName: 'awning',             viName: 'mái hiên',          module: ObjectModule.tallHazard),
    69: ClassLabel(id: 69, enName: 'tarpaulin',          viName: 'bạt che',           module: ObjectModule.tallHazard),
    70: ClassLabel(id: 70, enName: 'table',              viName: 'bàn',               module: ObjectModule.tallHazard),
    71: ClassLabel(id: 71, enName: 'chair',              viName: 'ghế',               module: ObjectModule.tallHazard),
    72: ClassLabel(id: 72, enName: 'cardboard_box',      viName: 'thùng carton',      module: ObjectModule.tallHazard),
    73: ClassLabel(id: 73, enName: 'sack',               viName: 'bao tải',           module: ObjectModule.tallHazard),
    74: ClassLabel(id: 74, enName: 'umbrella',           viName: 'ô dù',              module: ObjectModule.tallHazard),
    75: ClassLabel(id: 75, enName: 'conical_hat',        viName: 'nón lá',            module: ObjectModule.tallHazard),
    76: ClassLabel(id: 76, enName: 'sidewalk_sign',      viName: 'bảng hiệu vỉa hè', module: ObjectModule.tallHazard),
    77: ClassLabel(id: 77, enName: 'clothesline',        viName: 'dây phơi đồ',      module: ObjectModule.tallHazard),
    78: ClassLabel(id: 78, enName: 'tent',               viName: 'lều',               module: ObjectModule.tallHazard),
    79: ClassLabel(id: 79, enName: 'sunshade',           viName: 'dù che nắng',       module: ObjectModule.tallHazard),
    80: ClassLabel(id: 80, enName: 'technical_box',      viName: 'hộp kỹ thuật',      module: ObjectModule.tallHazard),
    81: ClassLabel(id: 81, enName: 'water_meter',        viName: 'đồng hồ nước',      module: ObjectModule.tallHazard),
    82: ClassLabel(id: 82, enName: 'outdoor_ac_unit',    viName: 'cục nóng máy lạnh', module: ObjectModule.tallHazard),
    83: ClassLabel(id: 83, enName: 'tin_roof',           viName: 'mái tôn',           module: ObjectModule.tallHazard),
    84: ClassLabel(id: 84, enName: 'water_pipe',         viName: 'ống nước',          module: ObjectModule.tallHazard),
    85: ClassLabel(id: 85, enName: 'hedge',              viName: 'hàng rào cây',      module: ObjectModule.tallHazard),

    // ── Chỉ dẫn & Kiến trúc đô thị (86–115) ────────────────────────────
    86:  ClassLabel(id: 86,  enName: 'traffic_light',    viName: 'đèn giao thông',    module: ObjectModule.urban),
    87:  ClassLabel(id: 87,  enName: 'traffic_sign',     viName: 'biển báo',          module: ObjectModule.urban),
    88:  ClassLabel(id: 88,  enName: 'road_marking',     viName: 'vạch kẻ đường',     module: ObjectModule.urban),
    89:  ClassLabel(id: 89,  enName: 'traffic_cone',     viName: 'cọc tiêu',          module: ObjectModule.urban),
    90:  ClassLabel(id: 90,  enName: 'bus_stop',         viName: 'trạm xe buýt',      module: ObjectModule.urban),
    91:  ClassLabel(id: 91,  enName: 'billboard',        viName: 'biển quảng cáo',    module: ObjectModule.urban),
    92:  ClassLabel(id: 92,  enName: 'mailbox',          viName: 'hòm thư',           module: ObjectModule.urban),
    93:  ClassLabel(id: 93,  enName: 'scaffolding',      viName: 'giàn giáo',         module: ObjectModule.urban),
    94:  ClassLabel(id: 94,  enName: 'safety_net',       viName: 'lưới an toàn',      module: ObjectModule.urban),
    95:  ClassLabel(id: 95,  enName: 'steam_roller',     viName: 'xe lu',             module: ObjectModule.urban),
    96:  ClassLabel(id: 96,  enName: 'excavator',        viName: 'máy xúc',           module: ObjectModule.urban),
    97:  ClassLabel(id: 97,  enName: 'crane',            viName: 'cần cẩu',           module: ObjectModule.urban),
    98:  ClassLabel(id: 98,  enName: 'kiosk',            viName: 'ki-ốt',             module: ObjectModule.urban),
    99:  ClassLabel(id: 99,  enName: 'wall',             viName: 'tường',             module: ObjectModule.urban),
    100: ClassLabel(id: 100, enName: 'pillar',           viName: 'cột trụ',           module: ObjectModule.urban),
    101: ClassLabel(id: 101, enName: 'gas_station',      viName: 'trạm xăng',         module: ObjectModule.urban),
    102: ClassLabel(id: 102, enName: 'milestone',        viName: 'cột mốc',           module: ObjectModule.urban),
    103: ClassLabel(id: 103, enName: 'barrier_gate',     viName: 'rào chắn barie',    module: ObjectModule.urban),
    104: ClassLabel(id: 104, enName: 'convex_mirror',    viName: 'gương cầu lồi',     module: ObjectModule.urban),
    105: ClassLabel(id: 105, enName: 'overpass',         viName: 'cầu vượt',          module: ObjectModule.urban),
    106: ClassLabel(id: 106, enName: 'underpass',        viName: 'hầm chui',          module: ObjectModule.urban),
    107: ClassLabel(id: 107, enName: 'toll_booth',       viName: 'trạm thu phí',      module: ObjectModule.urban),
    108: ClassLabel(id: 108, enName: 'guard_booth',      viName: 'bốt gác',           module: ObjectModule.urban),
    109: ClassLabel(id: 109, enName: 'fountain',         viName: 'đài phun nước',     module: ObjectModule.urban),
    110: ClassLabel(id: 110, enName: 'monument',         viName: 'tượng đài',         module: ObjectModule.urban),
    111: ClassLabel(id: 111, enName: 'planter',          viName: 'bồn cây',           module: ObjectModule.urban),
    112: ClassLabel(id: 112, enName: 'bus_waiting_bench', viName: 'ghế đợi xe buýt',  module: ObjectModule.urban),
    113: ClassLabel(id: 113, enName: 'public_trash_can', viName: 'thùng rác công cộng', module: ObjectModule.urban),
    114: ClassLabel(id: 114, enName: 'telephone_booth',  viName: 'bốt điện thoại',   module: ObjectModule.urban),
    115: ClassLabel(id: 115, enName: 'electric_cabinet', viName: 'tủ điện',           module: ObjectModule.urban),

    // ── Môi trường trong nhà (116–155) ──────────────────────────────────
    116: ClassLabel(id: 116, enName: 'elevator',         viName: 'thang máy',         module: ObjectModule.indoor),
    117: ClassLabel(id: 117, enName: 'escalator',        viName: 'thang cuốn',        module: ObjectModule.indoor),
    118: ClassLabel(id: 118, enName: 'rolling_door',     viName: 'cửa cuốn',          module: ObjectModule.indoor),
    119: ClassLabel(id: 119, enName: 'glass_door',       viName: 'cửa kính',          module: ObjectModule.indoor),
    120: ClassLabel(id: 120, enName: 'revolving_door',   viName: 'cửa xoay',          module: ObjectModule.indoor),
    121: ClassLabel(id: 121, enName: 'doorstep',         viName: 'bậc thềm',          module: ObjectModule.indoor),
    122: ClassLabel(id: 122, enName: 'atm_machine',      viName: 'máy ATM',           module: ObjectModule.indoor),
    123: ClassLabel(id: 123, enName: 'stall',            viName: 'quầy hàng',         module: ObjectModule.indoor),
    124: ClassLabel(id: 124, enName: 'cabinet',          viName: 'tủ',                module: ObjectModule.indoor),
    125: ClassLabel(id: 125, enName: 'bed',              viName: 'giường',            module: ObjectModule.indoor),
    126: ClassLabel(id: 126, enName: 'television',       viName: 'tivi',              module: ObjectModule.indoor),
    127: ClassLabel(id: 127, enName: 'potted_plant',     viName: 'chậu cây',          module: ObjectModule.indoor),
    128: ClassLabel(id: 128, enName: 'carpet',           viName: 'thảm',              module: ObjectModule.indoor),
    129: ClassLabel(id: 129, enName: 'curtain',          viName: 'rèm cửa',           module: ObjectModule.indoor),
    130: ClassLabel(id: 130, enName: 'electric_box',     viName: 'hộp điện',          module: ObjectModule.indoor),
    131: ClassLabel(id: 131, enName: 'switch',           viName: 'công tắc',          module: ObjectModule.indoor),
    132: ClassLabel(id: 132, enName: 'power_outlet',     viName: 'ổ điện',            module: ObjectModule.indoor),
    133: ClassLabel(id: 133, enName: 'faucet',           viName: 'vòi nước',          module: ObjectModule.indoor),
    134: ClassLabel(id: 134, enName: 'door_handle',      viName: 'tay nắm cửa',      module: ObjectModule.indoor),
    135: ClassLabel(id: 135, enName: 'wooden_door',      viName: 'cửa gỗ',            module: ObjectModule.indoor),
    136: ClassLabel(id: 136, enName: 'iron_door',        viName: 'cửa sắt',           module: ObjectModule.indoor),
    137: ClassLabel(id: 137, enName: 'screen_door',      viName: 'cửa lưới',          module: ObjectModule.indoor),
    138: ClassLabel(id: 138, enName: 'desk',             viName: 'bàn làm việc',      module: ObjectModule.indoor),
    139: ClassLabel(id: 139, enName: 'sofa',             viName: 'ghế sofa',          module: ObjectModule.indoor),
    140: ClassLabel(id: 140, enName: 'stool',            viName: 'ghế đẩu',           module: ObjectModule.indoor),
    141: ClassLabel(id: 141, enName: 'ceiling_fan',      viName: 'quạt trần',         module: ObjectModule.indoor),
    142: ClassLabel(id: 142, enName: 'floor_fan',        viName: 'quạt cây',          module: ObjectModule.indoor),
    143: ClassLabel(id: 143, enName: 'light_bulb',       viName: 'bóng đèn',          module: ObjectModule.indoor),
    144: ClassLabel(id: 144, enName: 'chandelier',       viName: 'đèn chùm',          module: ObjectModule.indoor),
    145: ClassLabel(id: 145, enName: 'wall_clock',       viName: 'đồng hồ treo tường', module: ObjectModule.indoor),
    146: ClassLabel(id: 146, enName: 'picture',          viName: 'tranh ảnh',         module: ObjectModule.indoor),
    147: ClassLabel(id: 147, enName: 'mirror',           viName: 'gương',             module: ObjectModule.indoor),
    148: ClassLabel(id: 148, enName: 'toilet',           viName: 'bồn cầu',           module: ObjectModule.indoor),
    149: ClassLabel(id: 149, enName: 'washbasin',        viName: 'bồn rửa mặt',      module: ObjectModule.indoor),
    150: ClassLabel(id: 150, enName: 'shower',           viName: 'vòi hoa sen',       module: ObjectModule.indoor),
    151: ClassLabel(id: 151, enName: 'refrigerator',     viName: 'tủ lạnh',           module: ObjectModule.indoor),
    152: ClassLabel(id: 152, enName: 'washing_machine',  viName: 'máy giặt',          module: ObjectModule.indoor),
    153: ClassLabel(id: 153, enName: 'gas_stove',        viName: 'bếp gas',           module: ObjectModule.indoor),
    154: ClassLabel(id: 154, enName: 'microwave',        viName: 'lò vi sóng',        module: ObjectModule.indoor),
    155: ClassLabel(id: 155, enName: 'rice_cooker',      viName: 'nồi cơm điện',      module: ObjectModule.indoor),

    // ── Vật dụng cá nhân (156–216) ──────────────────────────────────────
    156: ClassLabel(id: 156, enName: 'smartphone',       viName: 'điện thoại',        module: ObjectModule.personal),
    157: ClassLabel(id: 157, enName: 'wallet',           viName: 'ví',                module: ObjectModule.personal),
    158: ClassLabel(id: 158, enName: 'key',              viName: 'chìa khóa',         module: ObjectModule.personal),
    159: ClassLabel(id: 159, enName: 'backpack',         viName: 'balo',              module: ObjectModule.personal),
    160: ClassLabel(id: 160, enName: 'handbag',          viName: 'túi xách',          module: ObjectModule.personal),
    161: ClassLabel(id: 161, enName: 'helmet',           viName: 'mũ bảo hiểm',       module: ObjectModule.personal),
    162: ClassLabel(id: 162, enName: 'book',             viName: 'sách',              module: ObjectModule.personal),
    163: ClassLabel(id: 163, enName: 'notebook',         viName: 'vở',               module: ObjectModule.personal),
    164: ClassLabel(id: 164, enName: 'jacket',           viName: 'áo khoác',          module: ObjectModule.personal),
    165: ClassLabel(id: 165, enName: 'raincoat',         viName: 'áo mưa',            module: ObjectModule.personal),
    166: ClassLabel(id: 166, enName: 'glasses',          viName: 'kính mắt',          module: ObjectModule.personal),
    167: ClassLabel(id: 167, enName: 'watch',            viName: 'đồng hồ đeo tay',   module: ObjectModule.personal),
    168: ClassLabel(id: 168, enName: 'headphones',       viName: 'tai nghe',          module: ObjectModule.personal),
    169: ClassLabel(id: 169, enName: 'phone_charger',    viName: 'sạc điện thoại',    module: ObjectModule.personal),
    170: ClassLabel(id: 170, enName: 'power_bank',       viName: 'pin dự phòng',      module: ObjectModule.personal),
    171: ClassLabel(id: 171, enName: 'water_bottle',     viName: 'bình nước',         module: ObjectModule.personal),
    172: ClassLabel(id: 172, enName: 'glass_cup',        viName: 'ly nước',           module: ObjectModule.personal),
    173: ClassLabel(id: 173, enName: 'tea_cup',          viName: 'tách trà',          module: ObjectModule.personal),
    174: ClassLabel(id: 174, enName: 'chopsticks',       viName: 'đũa',              module: ObjectModule.personal),
    175: ClassLabel(id: 175, enName: 'spoon',            viName: 'muỗng',             module: ObjectModule.personal),
    176: ClassLabel(id: 176, enName: 'fork',             viName: 'nĩa',              module: ObjectModule.personal),
    177: ClassLabel(id: 177, enName: 'knife',            viName: 'dao',              module: ObjectModule.personal),
    178: ClassLabel(id: 178, enName: 'bowl',             viName: 'bát',              module: ObjectModule.personal),
    179: ClassLabel(id: 179, enName: 'plate',            viName: 'đĩa',             module: ObjectModule.personal),
    180: ClassLabel(id: 180, enName: 'lunch_box',        viName: 'hộp cơm',           module: ObjectModule.personal),
    181: ClassLabel(id: 181, enName: 'bank_card',        viName: 'thẻ ngân hàng',     module: ObjectModule.personal),
    182: ClassLabel(id: 182, enName: 'identity_card',    viName: 'giấy tờ tùy thân',  module: ObjectModule.personal),
    183: ClassLabel(id: 183, enName: 'paper_money',      viName: 'tiền giấy',         module: ObjectModule.personal),
    184: ClassLabel(id: 184, enName: 'coin',             viName: 'tiền xu',           module: ObjectModule.personal),
    185: ClassLabel(id: 185, enName: 'face_mask',        viName: 'khẩu trang',        module: ObjectModule.personal),
    186: ClassLabel(id: 186, enName: 'tissue',           viName: 'khăn giấy',         module: ObjectModule.personal),
    187: ClassLabel(id: 187, enName: 'pen',              viName: 'bút',              module: ObjectModule.personal),
    188: ClassLabel(id: 188, enName: 'ruler',            viName: 'thước kẻ',          module: ObjectModule.personal),
    189: ClassLabel(id: 189, enName: 'calculator',       viName: 'máy tính cầm tay',  module: ObjectModule.personal),
    190: ClassLabel(id: 190, enName: 'laptop',           viName: 'laptop',            module: ObjectModule.personal),
    191: ClassLabel(id: 191, enName: 'computer_mouse',   viName: 'chuột máy tính',    module: ObjectModule.personal),
    192: ClassLabel(id: 192, enName: 'keyboard',         viName: 'bàn phím',          module: ObjectModule.personal),
    193: ClassLabel(id: 193, enName: 'portable_hard_drive', viName: 'ổ cứng di động', module: ObjectModule.personal),
    194: ClassLabel(id: 194, enName: 'usb_flash_drive',  viName: 'USB',               module: ObjectModule.personal),
    195: ClassLabel(id: 195, enName: 'tv_remote',        viName: 'điều khiển tivi',   module: ObjectModule.personal),
    196: ClassLabel(id: 196, enName: 'ac_remote',        viName: 'điều khiển điều hòa', module: ObjectModule.personal),
    197: ClassLabel(id: 197, enName: 'medicine',         viName: 'thuốc',             module: ObjectModule.personal),
    198: ClassLabel(id: 198, enName: 'scissors',         viName: 'kéo',              module: ObjectModule.personal),
    199: ClassLabel(id: 199, enName: 'comb',             viName: 'lược',             module: ObjectModule.personal),
    200: ClassLabel(id: 200, enName: 'toothbrush',       viName: 'bàn chải đánh răng', module: ObjectModule.personal),
    201: ClassLabel(id: 201, enName: 'toothpaste',       viName: 'kem đánh răng',     module: ObjectModule.personal),
    202: ClassLabel(id: 202, enName: 'soap',             viName: 'xà phòng',          module: ObjectModule.personal),
    203: ClassLabel(id: 203, enName: 'shampoo',          viName: 'dầu gội',           module: ObjectModule.personal),
    204: ClassLabel(id: 204, enName: 'towel',            viName: 'khăn tắm',          module: ObjectModule.personal),
    205: ClassLabel(id: 205, enName: 'sneakers',         viName: 'giày thể thao',     module: ObjectModule.personal),
    206: ClassLabel(id: 206, enName: 'sandals',          viName: 'dép',              module: ObjectModule.personal),
    207: ClassLabel(id: 207, enName: 'high_heels',       viName: 'guốc',             module: ObjectModule.personal),
    208: ClassLabel(id: 208, enName: 'socks',            viName: 'tất',              module: ObjectModule.personal),
    209: ClassLabel(id: 209, enName: 'shirt',            viName: 'áo sơ mi',          module: ObjectModule.personal),
    210: ClassLabel(id: 210, enName: 't_shirt',          viName: 'áo thun',           module: ObjectModule.personal),
    211: ClassLabel(id: 211, enName: 'pants',            viName: 'quần dài',          module: ObjectModule.personal),
    212: ClassLabel(id: 212, enName: 'shorts',           viName: 'quần đùi',          module: ObjectModule.personal),
    213: ClassLabel(id: 213, enName: 'skirt',            viName: 'váy',              module: ObjectModule.personal),
    214: ClassLabel(id: 214, enName: 'cap',              viName: 'mũ lưỡi trai',      module: ObjectModule.personal),
    215: ClassLabel(id: 215, enName: 'belt',             viName: 'thắt lưng',         module: ObjectModule.personal),
    216: ClassLabel(id: 216, enName: 'tie',              viName: 'cà vạt',            module: ObjectModule.personal),

    // ── Thực phẩm & Đồ uống (217–237) ──────────────────────────────────
    217: ClassLabel(id: 217, enName: 'apple',            viName: 'táo',              module: ObjectModule.food),
    218: ClassLabel(id: 218, enName: 'banana',           viName: 'chuối',            module: ObjectModule.food),
    219: ClassLabel(id: 219, enName: 'orange',           viName: 'cam',              module: ObjectModule.food),
    220: ClassLabel(id: 220, enName: 'mango',            viName: 'xoài',             module: ObjectModule.food),
    221: ClassLabel(id: 221, enName: 'watermelon',       viName: 'dưa hấu',          module: ObjectModule.food),
    222: ClassLabel(id: 222, enName: 'bread',            viName: 'bánh mì',          module: ObjectModule.food),
    223: ClassLabel(id: 223, enName: 'cooked_rice',      viName: 'cơm',              module: ObjectModule.food),
    224: ClassLabel(id: 224, enName: 'pho',              viName: 'phở',              module: ObjectModule.food),
    225: ClassLabel(id: 225, enName: 'instant_noodles',  viName: 'mì tôm',           module: ObjectModule.food),
    226: ClassLabel(id: 226, enName: 'biscuit',          viName: 'bánh quy',         module: ObjectModule.food),
    227: ClassLabel(id: 227, enName: 'candy',            viName: 'kẹo',              module: ObjectModule.food),
    228: ClassLabel(id: 228, enName: 'chocolate',        viName: 'sô cô la',         module: ObjectModule.food),
    229: ClassLabel(id: 229, enName: 'water_bottle_pet', viName: 'chai nước lọc',    module: ObjectModule.food),
    230: ClassLabel(id: 230, enName: 'soda_can',         viName: 'lon nước ngọt',    module: ObjectModule.food),
    231: ClassLabel(id: 231, enName: 'milk_box',         viName: 'hộp sữa',          module: ObjectModule.food),
    232: ClassLabel(id: 232, enName: 'wine_bottle',      viName: 'chai rượu',        module: ObjectModule.food),
    233: ClassLabel(id: 233, enName: 'beer_can',         viName: 'lon bia',          module: ObjectModule.food),
    234: ClassLabel(id: 234, enName: 'vegetable',        viName: 'rau',              module: ObjectModule.food),
    235: ClassLabel(id: 235, enName: 'meat',             viName: 'thịt',             module: ObjectModule.food),
    236: ClassLabel(id: 236, enName: 'fish',             viName: 'cá',               module: ObjectModule.food),
    237: ClassLabel(id: 237, enName: 'egg',              viName: 'trứng',            module: ObjectModule.food),

    // ── Môi trường & Tự nhiên (238–257) ─────────────────────────────────
    238: ClassLabel(id: 238, enName: 'sky',              viName: 'bầu trời',          module: ObjectModule.nature),
    239: ClassLabel(id: 239, enName: 'cloud',            viName: 'mây',              module: ObjectModule.nature),
    240: ClassLabel(id: 240, enName: 'sun',              viName: 'mặt trời',         module: ObjectModule.nature),
    241: ClassLabel(id: 241, enName: 'moon',             viName: 'mặt trăng',        module: ObjectModule.nature),
    242: ClassLabel(id: 242, enName: 'star',             viName: 'sao',              module: ObjectModule.nature),
    243: ClassLabel(id: 243, enName: 'mountain',         viName: 'núi',              module: ObjectModule.nature),
    244: ClassLabel(id: 244, enName: 'hill',             viName: 'đồi',              module: ObjectModule.nature),
    245: ClassLabel(id: 245, enName: 'river',            viName: 'sông',             module: ObjectModule.nature),
    246: ClassLabel(id: 246, enName: 'lake',             viName: 'hồ',               module: ObjectModule.nature),
    247: ClassLabel(id: 247, enName: 'sea',              viName: 'biển',             module: ObjectModule.nature),
    248: ClassLabel(id: 248, enName: 'beach',            viName: 'bãi biển',         module: ObjectModule.nature),
    249: ClassLabel(id: 249, enName: 'sand',             viName: 'cát',              module: ObjectModule.nature),
    250: ClassLabel(id: 250, enName: 'stone',            viName: 'đá',               module: ObjectModule.nature),
    251: ClassLabel(id: 251, enName: 'grass',            viName: 'cỏ',               module: ObjectModule.nature),
    252: ClassLabel(id: 252, enName: 'flower',           viName: 'hoa',              module: ObjectModule.nature),
    253: ClassLabel(id: 253, enName: 'leaf',             viName: 'lá',               module: ObjectModule.nature),
    254: ClassLabel(id: 254, enName: 'insect',           viName: 'côn trùng',        module: ObjectModule.nature),
    255: ClassLabel(id: 255, enName: 'bird',             viName: 'chim',             module: ObjectModule.nature),
    256: ClassLabel(id: 256, enName: 'fish_underwater',  viName: 'cá dưới nước',     module: ObjectModule.nature),
    257: ClassLabel(id: 257, enName: 'bush',             viName: 'bụi rậm',          module: ObjectModule.nature),

    // ── Y tế & An toàn (258–270) ────────────────────────────────────────
    258: ClassLabel(id: 258, enName: 'first_aid_kit',    viName: 'hộp sơ cứu',       module: ObjectModule.medical),
    259: ClassLabel(id: 259, enName: 'fire_extinguisher', viName: 'bình chữa cháy',  module: ObjectModule.medical),
    260: ClassLabel(id: 260, enName: 'emergency_exit',   viName: 'lối thoát hiểm',   module: ObjectModule.medical),
    261: ClassLabel(id: 261, enName: 'danger_sign',      viName: 'biển báo nguy hiểm', module: ObjectModule.medical),
    262: ClassLabel(id: 262, enName: 'prohibition_sign', viName: 'biển báo cấm',     module: ObjectModule.medical),
    263: ClassLabel(id: 263, enName: 'mandatory_sign',   viName: 'biển báo bắt buộc', module: ObjectModule.medical),
    264: ClassLabel(id: 264, enName: 'quarantine_area',  viName: 'khu vực cách ly',   module: ObjectModule.medical),
    265: ClassLabel(id: 265, enName: 'medical_wheelchair', viName: 'xe lăn y tế',    module: ObjectModule.medical),
    266: ClassLabel(id: 266, enName: 'stretcher',        viName: 'cáng cứu thương',   module: ObjectModule.medical),
    267: ClassLabel(id: 267, enName: 'ventilator',       viName: 'máy trợ thở',       module: ObjectModule.medical),
    268: ClassLabel(id: 268, enName: 'crutch',           viName: 'nạng',             module: ObjectModule.medical),
    269: ClassLabel(id: 269, enName: 'magnifying_glass', viName: 'kính lúp',          module: ObjectModule.medical),
    270: ClassLabel(id: 270, enName: 'white_cane',       viName: 'gậy dò đường',      module: ObjectModule.medical),

    // ── Khác & Đặc biệt (271–300) ───────────────────────────────────────
    271: ClassLabel(id: 271, enName: 'license_plate',    viName: 'biển số xe',        module: ObjectModule.other),
    272: ClassLabel(id: 272, enName: 'qr_code',          viName: 'mã QR',             module: ObjectModule.other),
    273: ClassLabel(id: 273, enName: 'barcode',          viName: 'mã vạch',           module: ObjectModule.other),
    274: ClassLabel(id: 274, enName: 'company_logo',     viName: 'logo công ty',      module: ObjectModule.other),
    275: ClassLabel(id: 275, enName: 'street_name_sign', viName: 'bảng tên đường',    module: ObjectModule.other),
    276: ClassLabel(id: 276, enName: 'house_number',     viName: 'số nhà',            module: ObjectModule.other),
    277: ClassLabel(id: 277, enName: 'led_billboard',    viName: 'biển quảng cáo LED', module: ObjectModule.other),
    278: ClassLabel(id: 278, enName: 'light_box',        viName: 'hộp đèn',           module: ObjectModule.other),
    279: ClassLabel(id: 279, enName: 'security_camera',  viName: 'camera an ninh',    module: ObjectModule.other),
    280: ClassLabel(id: 280, enName: 'loudspeaker',      viName: 'loa phát thanh',    module: ObjectModule.other),
    281: ClassLabel(id: 281, enName: 'antenna',          viName: 'anten',             module: ObjectModule.other),
    282: ClassLabel(id: 282, enName: 'satellite_dish',   viName: 'chảo thu sóng',     module: ObjectModule.other),
    283: ClassLabel(id: 283, enName: 'drone',            viName: 'flycam',            module: ObjectModule.other),
    284: ClassLabel(id: 284, enName: 'balloon',          viName: 'bóng bay',          module: ObjectModule.other),
    285: ClassLabel(id: 285, enName: 'kite',             viName: 'diều',             module: ObjectModule.other),
    286: ClassLabel(id: 286, enName: 'plastic_waste',    viName: 'rác thải nhựa',     module: ObjectModule.other),
    287: ClassLabel(id: 287, enName: 'plastic_bag',      viName: 'túi ni lông',       module: ObjectModule.other),
    288: ClassLabel(id: 288, enName: 'foam_box',         viName: 'hộp xốp',           module: ObjectModule.other),
    289: ClassLabel(id: 289, enName: 'cigarette_butt',   viName: 'tàn thuốc',         module: ObjectModule.other),
    290: ClassLabel(id: 290, enName: 'road_paint',       viName: 'vết sơn trên đường', module: ObjectModule.other),
    291: ClassLabel(id: 291, enName: 'blood_puddle',     viName: 'vũng máu',          module: ObjectModule.other),
    292: ClassLabel(id: 292, enName: 'broken_glass',     viName: 'kính vỡ',           module: ObjectModule.other),
    293: ClassLabel(id: 293, enName: 'lock',             viName: 'ổ khóa',            module: ObjectModule.other),
    294: ClassLabel(id: 294, enName: 'iron_chain',       viName: 'xích sắt',          module: ObjectModule.other),
    295: ClassLabel(id: 295, enName: 'map',              viName: 'bản đồ',            module: ObjectModule.other),
    296: ClassLabel(id: 296, enName: 'menu',             viName: 'menu nhà hàng',     module: ObjectModule.other),
    297: ClassLabel(id: 297, enName: 'invoice',          viName: 'hóa đơn',           module: ObjectModule.other),
    298: ClassLabel(id: 298, enName: 'ticket',           viName: 'vé xe',             module: ObjectModule.other),
    299: ClassLabel(id: 299, enName: 'membership_card',  viName: 'thẻ thành viên',    module: ObjectModule.other),
    300: ClassLabel(id: 300, enName: 'lucky_money_envelope', viName: 'bao lì xì',     module: ObjectModule.other),
  };
}
