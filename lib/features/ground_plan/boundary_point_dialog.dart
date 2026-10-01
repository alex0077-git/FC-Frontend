import 'package:fc_frontend/data/models/boundary_point.dart';
import 'package:flutter/material.dart';

class BoundaryDialogResult {
  const BoundaryDialogResult.save(this.draft) : deleted = false;

  const BoundaryDialogResult.delete() : deleted = true, draft = null;

  final bool deleted;
  final BoundaryPointDraft? draft;
}

class BoundaryPointDraft {
  const BoundaryPointDraft({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
  });

  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
}

/// Popup for one boundary marker. Delete and Save close the dialog.
class BoundaryPointDialog extends StatefulWidget {
  const BoundaryPointDialog({super.key, required this.point});

  final BoundaryPoint point;

  @override
  State<BoundaryPointDialog> createState() => _BoundaryPointDialogState();
}

class _BoundaryPointDialogState extends State<BoundaryPointDialog> {
  late final TextEditingController _latitude = TextEditingController(
    text: widget.point.latitude.toStringAsFixed(6),
  );
  late final TextEditingController _longitude = TextEditingController(
    text: widget.point.longitude.toStringAsFixed(6),
  );
  late final TextEditingController _altitude = TextEditingController(
    text: widget.point.altitude.toStringAsFixed(1),
  );
  late final TextEditingController _speed = TextEditingController(
    text: widget.point.speed.toStringAsFixed(1),
  );
  String? _error;

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _altitude.dispose();
    _speed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Waypoint ${widget.point.order + 1}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Waypoint number'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${widget.point.order + 1}'),
          ),
          const SizedBox(height: 12),
          _Field(controller: _latitude, label: 'Latitude'),
          const SizedBox(height: 8),
          _Field(controller: _longitude, label: 'Longitude'),
          const SizedBox(height: 8),
          _Field(controller: _altitude, label: 'Altitude', suffix: 'm'),
          const SizedBox(height: 8),
          _Field(controller: _speed, label: 'Speed', suffix: 'm/s'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            const BoundaryDialogResult.delete(),
          ),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    final altitude = double.tryParse(_altitude.text.trim());
    final speed = double.tryParse(_speed.text.trim());
    if (latitude == null ||
        longitude == null ||
        altitude == null ||
        speed == null) {
      setState(() => _error = 'Enter a number in every field');
      return;
    }

    Navigator.of(context).pop(
      BoundaryDialogResult.save(
        BoundaryPointDraft(
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
          speed: speed,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
    );
  }
}
