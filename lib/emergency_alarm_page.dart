import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmergencyAlarmPage extends StatefulWidget {
  const EmergencyAlarmPage({super.key});

  @override
  State<EmergencyAlarmPage> createState() => _EmergencyAlarmPageState();
}

class _EmergencyAlarmPageState extends State<EmergencyAlarmPage> {
  static const _channel = MethodChannel(
    'com.aderiktech.safefamily/emergency_alarm',
  );

  bool _siren = false;
  bool _torch = false;
  bool _busy = false;
  String? _error;

  Future<void> _toggle(String method, bool current, bool isSiren) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _channel.invokeMethod<void>(
        current ? (isSiren ? 'stopSiren' : 'stopTorch') : method,
      );
      if (mounted) {
        setState(() {
          if (isSiren) {
            _siren = !current;
          } else {
            _torch = !current;
          }
        });
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Alarm action failed.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Alarm action failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopAll() async {
    try {
      await _channel.invokeMethod<void>('stopSiren');
    } catch (_) {}
    try {
      await _channel.invokeMethod<void>('stopTorch');
    } catch (_) {}
    if (mounted) {
      setState(() {
        _siren = false;
        _torch = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _channel.invokeMethod<void>('stopSiren').catchError((_) {});
    _channel.invokeMethod<void>('stopTorch').catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _siren || _torch;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1110),
      appBar: AppBar(
        title: const Text('Local Emergency Alarm'),
        backgroundColor: const Color(0xFF0B1110),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF151F1C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? const Color(0xFFFF6675)
                      : const Color(0xFF16D9A0),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    active ? Icons.warning_rounded : Icons.shield_outlined,
                    size: 54,
                    color: active
                        ? const Color(0xFFFF6675)
                        : const Color(0xFF16D9A0),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    active ? 'ALARM ACTIVE' : 'LOCAL ALARM READY',
                    style: TextStyle(
                      color: active
                          ? const Color(0xFFFF6675)
                          : const Color(0xFF16D9A0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the sound and flashing light to attract attention nearby.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF9AAEA5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _toggle('startSiren', _siren, true),
              icon: Icon(_siren ? Icons.volume_off : Icons.volume_up),
              label: Text(_siren ? 'Stop siren' : 'Start loud siren'),
              style: FilledButton.styleFrom(
                backgroundColor: _siren
                    ? const Color(0xFFFF6675)
                    : const Color(0xFF16D9A0),
                foregroundColor: const Color(0xFF0B1110),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _toggle('startTorch', _torch, false),
              icon: Icon(_torch ? Icons.flashlight_off : Icons.flashlight_on),
              label: Text(
                _torch
                    ? 'Stop flashing flashlight'
                    : 'Start flashing flashlight',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _torch
                    ? const Color(0xFFFF6675)
                    : const Color(0xFF16D9A0),
                foregroundColor: const Color(0xFF0B1110),
                minimumSize: const Size.fromHeight(54),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: active ? _stopAll : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop all alarm effects'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF6675))),
            ],
            const SizedBox(height: 20),
            const Text(
              'This alarm operates on this phone only. It does not call 112, send SMS, or notify other phones. The existing Firebase SOS recording remains separate.',
              style: TextStyle(color: Color(0xFF9AAEA5), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
