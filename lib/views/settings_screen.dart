import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showEditSimDialog(BuildContext context, DialerProvider provider) {
    final sim1Ctrl = TextEditingController(text: provider.sim1Name);
    final sim2Ctrl = TextEditingController(text: provider.sim2Name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dual SIM Cards Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sim1Ctrl,
              decoration: const InputDecoration(labelText: 'SIM 1 Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sim2Ctrl,
              decoration: const InputDecoration(labelText: 'SIM 2 Label'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.setSimNames(sim1Ctrl.text.trim(), sim2Ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBlockedNumbersDialog(BuildContext context, DialerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Blocked Numbers'),
        content: SizedBox(
          width: double.maxFinite,
          child: provider.blockedNumbers.isEmpty
              ? const Text('No numbers blocked.')
              : ListView(
                  shrinkWrap: true,
                  children: provider.blockedNumbers.map((blockedNum) {
                    return ListTile(
                      title: Text(blockedNum),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: MiuiColors.callRed),
                        onPressed: () {
                          provider.toggleBlockContact(blockedNum);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Settings', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Display & Theme Section
          _buildSectionHeader('DISPLAY & THEME'),
          SwitchListTile(
            title: const Text('Dark Mode', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: const Text('Toggle dark and light theme', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            secondary: const Icon(Icons.brightness_4_outlined),
            value: isDark,
            onChanged: (_) => provider.toggleTheme(),
          ),

          const Divider(),

          // Dual SIM Cards Section
          _buildSectionHeader('SIM CARDS & NETWORK'),
          ListTile(
            leading: const Icon(Icons.sim_card_outlined),
            title: const Text('Dual SIM Card Names', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: Text('SIM 1: ${provider.sim1Name}  •  SIM 2: ${provider.sim2Name}',
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditSimDialog(context, provider),
          ),

          const Divider(),

          // Keypad Sound & Tones
          _buildSectionHeader('SOUND & TOUCH TONES'),
          ListTile(
            leading: const Icon(Icons.piano_outlined),
            title: const Text('Dial pad touch tones', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: Text('Current tone: ${provider.dialPadTones.toUpperCase()}',
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily)),
            trailing: DropdownButton<String>(
              value: provider.dialPadTones,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'piano', child: Text('Piano Keys')),
                DropdownMenuItem(value: 'standard', child: Text('Standard')),
                DropdownMenuItem(value: 'silent', child: Text('Silent')),
              ],
              onChanged: (val) {
                if (val != null) provider.setDialPadTones(val);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Vibrate on touch', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: const Text('Haptic feedback when pressing keys', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            secondary: const Icon(Icons.vibration_outlined),
            value: provider.hapticsEnabled,
            onChanged: (val) => provider.setHapticsEnabled(val),
          ),

          const Divider(),

          // Call Recording Section (Signature Xiaomi Feature)
          _buildSectionHeader('XIAOMI CALL RECORDING'),
          SwitchListTile(
            title: const Text('Record calls automatically', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: const Text('Auto-record all incoming and outgoing calls', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            secondary: const Icon(Icons.mic_none_outlined, color: MiuiColors.callRed),
            value: provider.autoRecordEnabled,
            onChanged: (val) => provider.setAutoRecordEnabled(val),
          ),

          const Divider(),

          // Harassment Filter & Blocklist
          _buildSectionHeader('SECURITY & BLOCKLIST'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Blocked numbers list', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: Text('${provider.blockedNumbers.length} numbers blocked',
                style: const TextStyle(fontFamily: MiuiTheme.fontFamily)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBlockedNumbersDialog(context, provider),
          ),

          const Divider(),

          // Battery & Background Auto-start
          _buildSectionHeader('BATTERY & BACKGROUND RUNNING'),
          ListTile(
            leading: const Icon(Icons.battery_saver_outlined, color: Colors.green),
            title: const Text('Unrestricted Battery & Auto-Start', style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            subtitle: const Text('Bypass battery restrictions for reliable incoming calls & lock screen alert',
                style: TextStyle(fontFamily: MiuiTheme.fontFamily)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => provider.requestIgnoreBatteryOptimizations(),
          ),

          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                const Text(
                  'Callvyn Dialer • MIUI Edition',
                  style: TextStyle(fontFamily: MiuiTheme.fontFamily, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  'Roboto Font Included • Version 1.0.0',
                  style: TextStyle(fontFamily: MiuiTheme.fontFamily, fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: MiuiTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: MiuiColors.primaryBlue,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
