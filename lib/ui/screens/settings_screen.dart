import 'package:flutter/material.dart';
import '../../core/local_db/sqlite_helper.dart';
import '../../core/local_db/entities/app_settings.dart';
import '../widgets/sos_button.dart';

/// Màn hình cài đặt duy nhất - UI chỉ phục vụ khâu setup ban đầu.
/// Sau khi cài đặt xong, app chuyển sang Headless Mode.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await SqliteHelper.instance.getSettings();
    setState(() => _settings = s);
  }

  Future<void> _updateSetting(AppSettings updated) async {
    await SqliteHelper.instance.updateSettings(updated);
    setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('CÀI ĐẶT SAVICAM', style: theme.textTheme.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildToggle('PHÁT ÂM THANH (TTS)', _settings.enableTts, (v) {
            _updateSetting(_settings.copyWith(enableTts: v));
          }),
          _buildToggle('RUNG PHẢN HỒI', _settings.enableVibration, (v) {
            _updateSetting(_settings.copyWith(enableVibration: v));
          }),
          _buildToggle('ĐỘ TƯƠNG PHẢN CAO', _settings.isHighContrast, (v) {
            _updateSetting(_settings.copyWith(isHighContrast: v));
          }),
          const SizedBox(height: 32),
          Semantics(
            label: 'Nút SOS khẩn cấp. Nhấn giữ 2 giây để kích hoạt báo động đỏ.',
            child: const SosButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFFFF00),
        tileColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFFF00), width: 2),
        ),
      ),
    );
  }
}
