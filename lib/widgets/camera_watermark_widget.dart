import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Widget de marca d'água para câmeras em tempo real
/// Exibe data, hora e localização GPS atualizadas continuamente
class CameraWatermarkWidget extends StatefulWidget {
  final Alignment alignment;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final bool showIcon;

  const CameraWatermarkWidget({
    super.key,
    this.alignment = Alignment.bottomLeft,
    this.padding = const EdgeInsets.all(12),
    this.backgroundColor = const Color(0xCC000000),
    this.textColor = Colors.white,
    this.fontSize = 11,
    this.showIcon = true,
  });

  @override
  State<CameraWatermarkWidget> createState() => _CameraWatermarkWidgetState();
}

class _CameraWatermarkWidgetState extends State<CameraWatermarkWidget> {
  Timer? _dateTimeTimer;
  Timer? _locationTimer;
  String _currentDateTime = '';
  String _currentLocation = 'Obtendo localização...';
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _updateLocation();

    // Atualizar data/hora a cada segundo
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateDateTime();
    });

    // Atualizar localização a cada 60 segundos
    _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _updateLocation();
    });
  }

  @override
  void dispose() {
    _dateTimeTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  void _updateDateTime() {
    setState(() {
      _currentDateTime =
          DateFormat('dd/MM/yyyy - HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      ).timeout(const Duration(seconds: 4));

      // Tentar obter endereço
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 2));

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          List<String> parts = [];

          if (place.street?.isNotEmpty == true) {
            parts.add(place.street!);
          }
          if (place.subThoroughfare?.isNotEmpty == true) {
            parts.add(place.subThoroughfare!);
          }
          if (place.subLocality?.isNotEmpty == true) {
            parts.add(place.subLocality!);
          }
          if (place.locality?.isNotEmpty == true) {
            String city = place.locality!;
            if (place.administrativeArea?.isNotEmpty == true) {
              city += ' - ${place.administrativeArea}';
            }
            parts.add(city);
          }
          if (place.postalCode?.isNotEmpty == true) {
            parts.add(place.postalCode!);
          }

          setState(() {
            _currentLocation = parts.isNotEmpty
                ? parts.join(', ')
                : 'Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}';
            _isLoadingLocation = false;
          });
        } else {
          _setCoordinatesAsLocation(position);
        }
      } catch (e) {
        _setCoordinatesAsLocation(position);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = 'GPS indisponível';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _setCoordinatesAsLocation(Position position) {
    if (mounted) {
      setState(() {
        _currentLocation =
            'Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}';
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: Container(
        margin: widget.padding,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data e Hora
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showIcon) ...[
                  Icon(
                    Icons.calendar_today,
                    color: widget.textColor.withValues(alpha: 0.9),
                    size: widget.fontSize + 2,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _currentDateTime,
                  style: GoogleFonts.robotoMono(
                    color: widget.textColor,
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        offset: const Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Localização
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showIcon) ...[
                  _isLoadingLocation
                      ? SizedBox(
                          width: widget.fontSize + 2,
                          height: widget.fontSize + 2,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : Icon(
                          Icons.location_on,
                          color: widget.textColor.withValues(alpha: 0.9),
                          size: widget.fontSize + 2,
                        ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    _currentLocation,
                    style: GoogleFonts.robotoMono(
                      color: widget.textColor.withValues(alpha: 0.95),
                      fontSize: widget.fontSize - 1,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          offset: const Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
