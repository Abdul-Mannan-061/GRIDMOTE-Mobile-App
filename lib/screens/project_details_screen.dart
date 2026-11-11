import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/project_storage.dart';
import 'live_control_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailsScreen({
    super.key,
    required this.project,
  });

  @override
  State<ProjectDetailsScreen> createState() =>
      _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _saveProject() async {
    if (_saving || _saved) return;

    setState(() {
      _saving = true;
    });

    try {
      await ProjectStorage.saveProject(widget.project);

      if (!mounted) return;

      setState(() {
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project saved to My Projects.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save the project. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _openControlPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveControlScreen(
          project: widget.project,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.dashboard_outlined,
              size: 56,
              color: Color(0xFF38BDF8),
            ),
            const SizedBox(height: 16),
            Text(
              project.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              project.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow('Project ID', project.id),
                    const Divider(height: 28),
                    _infoRow(
                      'Widgets',
                      '${project.widgetCount}',
                    ),
                    const Divider(height: 28),
                    _infoRow(
                      'Canvas',
                      '${project.canvasWidth.toInt()}'
                          ' × ${project.canvasHeight.toInt()}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openControlPanel,
              icon: const Icon(Icons.sports_esports_outlined),
              label: const Text('Open Control Panel'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving || _saved ? null : _saveProject,
              icon: Icon(
                _saved ? Icons.check_circle : Icons.save_outlined,
              ),
              label: Text(
                _saving
                    ? 'Saving...'
                    : _saved
                    ? 'Saved to My Projects'
                    : 'Save to My Projects',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Widgets in This Layout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (project.widgets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('This layout has no widgets.'),
              ),
            for (final item in project.widgets)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        child: Text('${item['id']}'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['label']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Type: ${item['type']}'),
                            Text(
                              'Position: (${item['x']}, ${item['y']})',
                            ),
                            Text(
                              'Size: ${item['w']} × ${item['h']}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}