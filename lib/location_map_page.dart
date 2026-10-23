import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationMapPage extends StatefulWidget {
  const LocationMapPage({super.key});

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  static const Color _background = Color(0xFF07130F);
  static const Color _surface = Color(0xFF10231B);
  static const Color _border = Color(0xFF254638);
  static const Color _green = Color(0xFF35D49A);
  static const Color _muted = Color(0xFF9BB5A8);

  // This is only the initial map camera position, NOT the phone's location.
  static const LatLng _initialCamera = LatLng(9.0820, 8.6753);

  GoogleMapController? _mapController;
  MapType _mapType = MapType.normal;
  Position? _position;

  bool _loading = false;
  bool _permissionGranted = false;
  bool _serviceEnabled = false;

  String? _message;
  String _status = 'Location not checked';

  Set<Marker> get _markers {
    final position = _position;
    if (position == null) return {};

    return {
      Marker(
        markerId: const MarkerId('this_phone'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: InfoWindow(
          title: 'This phone',
          snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(0)} m',
        ),
      ),
    };
  }

  Future<void> _locatePhone() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _message = null;
      _status = 'Checking location permission...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _serviceEnabled = false;
          _permissionGranted = false;
          _status = 'Phone location is turned off';
          _message = 'Turn on Location in your phone settings, then try again.';
        });
        return;
      }

      _serviceEnabled = true;

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _permissionGranted = false;
          _status = 'Location permission denied';
          _message = 'Allow location access if you want SAFEFAMILY to locate this phone.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _permissionGranted = false;
          _status = 'Permission blocked';
          _message =
              'Open app settings and allow location permission to continue.';
        });
        return;
      }

      _permissionGranted = true;

      if (!mounted) return;
      setState(() => _status = 'Getting this phoneâ€™s location...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _status = 'Location updated successfully';
        _message = null;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _status = 'Could not get location';
        _message =
            'Check GPS, location permission and signal, then try again. '
            'Details: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'Not available';

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.day}/${local.month}/${local.year} Â· '
        '$hour:$minute $period';
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _mapModeButton(String label, MapType type, IconData icon) {
    final selected = _mapType == type;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mapType = type),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? _green : _surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: selected ? _green : _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? _background : Colors.white70,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _background : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationStatusCard() {
    final position = _position;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.my_location_rounded, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This phone',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              else
                const Icon(Icons.shield_outlined, color: _green, size: 23),
            ],
          ),
          if (position != null) ...[
            const SizedBox(height: 15),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _detail(
                    'LATITUDE',
                    position.latitude.toStringAsFixed(6),
                  ),
                ),
                Expanded(
                  child: _detail(
                    'LONGITUDE',
                    position.longitude.toStringAsFixed(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded, size: 16, color: _green),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Accuracy Â±${position.accuracy.toStringAsFixed(0)} m',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Updated: ${_formatTime(position.timestamp)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF35281B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _message!,
                    style: const TextStyle(
                      color: Color(0xFFFFD8A8),
                      height: 1.45,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!_serviceEnabled)
                    TextButton.icon(
                      onPressed: _openLocationSettings,
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open location settings'),
                    )
                  else if (!_permissionGranted)
                    TextButton.icon(
                      onPressed: _openAppSettings,
                      icon: const Icon(Icons.app_settings_alt_rounded),
                      label: const Text('Open app settings'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.location_searching_rounded,
                      color: _green,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Safety centre',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Location and family safety',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Locate this phone',
                    onPressed: _loading ? null : _locatePhone,
                    icon: const Icon(Icons.refresh_rounded),
                    color: _green,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sectionLabel('Map view'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _mapModeButton('Street', MapType.normal, Icons.map_outlined),
                  const SizedBox(width: 10),
                  _mapModeButton(
                    'Satellite',
                    MapType.hybrid,
                    Icons.satellite_alt_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: _initialCamera,
                            zoom: 5,
                          ),
                          mapType: _mapType,
                          markers: _markers,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: true,
                          mapToolbarEnabled: false,
                          zoomControlsEnabled: false,
                          onMapCreated: (controller) {
                            _mapController = controller;
                          },
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: _background.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _border),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: _green,
                                size: 19,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'The initial map view is not your location. '
                                  'Locate this phone to place your GPS marker.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FloatingActionButton.small(
                          heroTag: 'safefamily_locate_phone',
                          backgroundColor: _green,
                          foregroundColor: _background,
                          onPressed: _loading ? null : _locatePhone,
                          child: const Icon(Icons.my_location_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _locationStatusCard(),
              const SizedBox(height: 10),
              const Text(
                'Only this phone is located in this first version. '
                'Family sharing is not active yet.',
                style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
