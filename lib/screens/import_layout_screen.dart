import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/project_model.dart';
import 'project_details_screen.dart';

class ImportLayoutScreen extends StatefulWidget {
  const ImportLayoutScreen({super.key});

  @override
  State<ImportLayoutScreen> createState() => _ImportLayoutScreenState();
}

class _ImportLayoutScreenState extends State<ImportLayoutScreen> {
  static const int _maxFileSize = 100 * 1024;

  static const Set<String> _supportedTypes = {
    'button',
    'label',
    'toggle',
    'slider',
    'joystick',
    'led',
    'gauge',
    'knob',
    'stepper',
    'rgb',
    'bar',
    'digit',
    'accel',
    'buzzer',
  };

  bool _loading = false;
  String? _error;
  String? _fileName;
  ProjectModel? _project;

  int _readInteger(
      dynamic value,
      String field,
      int minimum,
      int maximum,
      ) {
    if (value is! num ||
        !value.isFinite ||
        value != value.roundToDouble() ||
        value < minimum ||
        value > maximum) {
      throw FormatException(
        '$field must be a whole number between $minimum and $maximum.',
      );
    }

    return value.toInt();
  }

  ProjectModel _parseLayout(String text, String fileName) {
    final dynamic decoded = jsonDecode(text);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid layout. The JSON must contain an object.',
      );
    }

    if (decoded['protocol'] != 'GRIDMOTE' || decoded['version'] != 2) {
      throw const FormatException(
        'Please select a GRIDMOTE version 2 layout.',
      );
    }

    final dynamic canvas = decoded['canvas'];

    if (canvas is! Map<String, dynamic>) {
      throw const FormatException(
        'The layout is missing its canvas configuration.',
      );
    }

    final canvasWidth = _readInteger(
      canvas['width'],
      'Canvas width',
      1,
      65535,
    );

    final canvasHeight = _readInteger(
      canvas['height'],
      'Canvas height',
      1,
      65535,
    );

    final dynamic rawWidgets = decoded['widgets'];

    if (rawWidgets is! List) {
      throw const FormatException(
        'The layout must contain a widgets list.',
      );
    }

    if (rawWidgets.length > 32) {
      throw const FormatException(
        'A layout can contain a maximum of 32 widgets.',
      );
    }

    final widgets = <Map<String, dynamic>>[];
    final usedIds = <int>{};

    for (int index = 0; index < rawWidgets.length; index++) {
      final dynamic widgetData = rawWidgets[index];
      final widgetNumber = index + 1;

      if (widgetData is! Map<String, dynamic>) {
        throw FormatException(
          'Widget $widgetNumber contains invalid data.',
        );
      }

      final id = _readInteger(
        widgetData['id'],
        'Widget $widgetNumber ID',
        0,
        31,
      );

      if (!usedIds.add(id)) {
        throw FormatException(
          'Duplicate widget ID: $id.',
        );
      }

      if (id != index) {
        throw const FormatException(
          'Widget IDs must start at 0 and follow their list order.',
        );
      }

      final dynamic type = widgetData['type'];

      if (type is! String || !_supportedTypes.contains(type)) {
        throw FormatException(
          'Widget $widgetNumber has an unsupported type: $type.',
        );
      }

      final dynamic label = widgetData['label'];

      if (label is! String) {
        throw FormatException(
          'Widget $widgetNumber must have a text label.',
        );
      }

      if (utf8.encode(label).length > 96) {
        throw FormatException(
          'Widget $widgetNumber label exceeds 96 UTF-8 bytes.',
        );
      }

      final x = _readInteger(
        widgetData['x'],
        'Widget $widgetNumber X position',
        0,
        canvasWidth,
      );

      final y = _readInteger(
        widgetData['y'],
        'Widget $widgetNumber Y position',
        0,
        canvasHeight,
      );

      final width = _readInteger(
        widgetData['w'],
        'Widget $widgetNumber width',
        1,
        canvasWidth,
      );

      final height = _readInteger(
        widgetData['h'],
        'Widget $widgetNumber height',
        1,
        canvasHeight,
      );

      if (x + width > canvasWidth || y + height > canvasHeight) {
        throw FormatException(
          'Widget $widgetNumber extends outside the canvas.',
        );
      }

      widgets.add({
        'id': id,
        'type': type,
        'label': label,
        'x': x,
        'y': y,
        'w': width,
        'h': height,
      });
    }

    final projectName = fileName.replaceFirst(
      RegExp(r'\.json$', caseSensitive: false),
      '',
    );

    return ProjectModel(
      id: 'import-${DateTime.now().microsecondsSinceEpoch}',
      name: projectName.isEmpty ? 'Imported Layout' : projectName,
      description: 'Imported from $fileName',
      canvasWidth: canvasWidth.toDouble(),
      canvasHeight: canvasHeight.toDouble(),
      widgets: widgets,
    );
  }

  Future<void> _selectFile() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      // Keep the previous layout if the user cancels.
      if (file == null) return;

      // file_picker 13 uses length() instead of the old size property.
      final fileSize = await file.length();

      if (fileSize != null && fileSize > _maxFileSize) {
        throw const FormatException(
          'File is too large. Maximum size is 100 KB.',
        );
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > _maxFileSize) {
        throw const FormatException(
          'File is too large. Maximum size is 100 KB.',
        );
      }

      if (bytes.isEmpty) {
        throw const FormatException(
          'The selected file is empty.',
        );
      }

      String text = utf8.decode(bytes);

      // Remove a UTF-8 byte order mark if present.
      if (text.startsWith('\uFEFF')) {
        text = text.substring(1);
      }

      final project = _parseLayout(text, file.name);

      if (!mounted) return;

      setState(() {
        _fileName = file.name;
        _project = project;
        _error = null;
      });
    } on FormatException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _project = null;
        _fileName = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not open the file. Please select it again.';
        _project = null;
        _fileName = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    final error = _error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Layout'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.file_upload_outlined,
              size: 76,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 24),
            const Text(
              'Load Your Design',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select the JSON layout exported from your GRIDMOTE web editor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _selectFile,
              icon: const Icon(Icons.folder_open),
              label: Text(
                _loading ? 'Reading File...' : 'Choose JSON File',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'GRIDMOTE v2 • .json files • Maximum 100 KB',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            if (project != null) ...[
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Color(0xFF4ADE80),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Layout Loaded',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fileName ?? '',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Divider(height: 28),
                      Text('Widgets: ${project.widgetCount}'),
                      const SizedBox(height: 8),
                      Text(
                        'Canvas: ${project.canvasWidth.toInt()}'
                            ' × ${project.canvasHeight.toInt()}',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProjectDetailsScreen(
                                      project: project,
                                    ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.dashboard_outlined),
                          label: const Text('View Project Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Text(
    'Open View Project Details, then tap Save to My Projects '
    'to keep this layout on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}