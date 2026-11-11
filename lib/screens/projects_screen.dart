import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/project_storage.dart';
import 'import_layout_screen.dart';
import 'live_control_screen.dart';
import 'project_details_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    this.forControl = false,
  });

  final bool forControl;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<ProjectModel> _projects = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  List<ProjectModel> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _projects;
    }

    return _projects.where((project) {
      return project.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await ProjectStorage.loadProjects();

      if (!mounted) return;

      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not read saved projects. Please try again.';
        _loading = false;
      });
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _openImport() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ImportLayoutScreen(),
      ),
    );

    if (!mounted) return;
    await _loadProjects();
  }

  Future<void> _openProject(ProjectModel project) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.forControl
            ? LiveControlScreen(project: project)
            : ProjectDetailsScreen(project: project),
      ),
    );

    if (!mounted) return;
    await _loadProjects();
  }

  Future<void> _renameProject(ProjectModel project) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final formKey = GlobalKey<FormState>();
      var enteredName = project.name;

      final newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          void submit() {
            if (formKey.currentState!.validate()) {
              formKey.currentState!.save();
              Navigator.of(dialogContext).pop(enteredName.trim());
            }
          }

          return AlertDialog(
            title: const Text('Rename Project'),
            content: Form(
              key: formKey,
              child: TextFormField(
                initialValue: project.name,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Project name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Enter a project name.';
                  }

                  if (name.length > 60) {
                    return 'Use 60 characters or fewer.';
                  }

                  return null;
                },
                onSaved: (value) {
                  enteredName = value ?? '';
                },
                onFieldSubmitted: (_) => submit(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (!mounted || newName == null || newName == project.name) {
        return;
      }

      await ProjectStorage.renameProject(project, newName);

      if (!mounted) return;

      await _loadProjects();
      _message('Project renamed to "$newName".');
    } catch (_) {
      _message('Could not rename the project. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteProject(ProjectModel project) async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            title: const Text('Delete Project?'),
            content: Text(
              'Delete "${project.name}" from My Projects?\n\n'
                  'This removes the saved copy from this app. '
                  'You can import the original JSON again later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmed != true) return;

      await ProjectStorage.deleteProject(project.id);

      if (!mounted) return;

      await _loadProjects();
      _message('Project deleted.');
    } catch (_) {
      _message('Could not delete the project. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.forControl ? 'Choose Control Layout' : 'My Projects',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh projects',
            onPressed: _loading || _busy ? null : _loadProjects,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openImport,
        icon: const Icon(Icons.add),
        label: const Text('Import Layout'),
      ),
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 52, color: colors.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadProjects,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_projects.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open, size: 76, color: colors.primary),
              const SizedBox(height: 20),
              const Text(
                'No Saved Projects Yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Import a JSON layout, open its details, '
                    'then tap Save to My Projects.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openImport,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import Layout'),
              ),
            ],
          ),
        ),
      );
    }

    final visibleProjects = _filteredProjects;
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search projects by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                tooltip: 'Clear search',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProjects,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                const Text(
                  'Your Control Layouts',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasQuery
                      ? '${visibleProjects.length} of '
                      '${_projects.length} project(s) found'
                      : '${_projects.length} saved project(s)',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.forControl
                      ? 'Select the layout uploaded to your Arduino. '
                      'Then tap Start live.'
                      : 'Tap a project to open it. '
                      'Use the menu to rename or delete.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (visibleProjects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No matching projects',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try another name or clear your search.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Search'),
                        ),
                      ],
                    ),
                  ),
                for (final project in visibleProjects)
                  _projectCard(project),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _projectCard(ProjectModel project) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      key: ValueKey(project.id),
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          Icons.dashboard_outlined,
          size: 34,
          color: colors.primary,
        ),
        title: Text(
          project.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${project.widgetCount} widgets • '
                '${project.canvasWidth.toInt()} × '
                '${project.canvasHeight.toInt()}',
          ),
        ),
        trailing: widget.forControl
            ? const Icon(Icons.chevron_right)
            : PopupMenuButton<String>(
          tooltip: 'Project options',
          enabled: !_busy,
          onSelected: (action) async {
            if (action == 'rename') {
              await _renameProject(project);
            } else if (action == 'delete') {
              await _deleteProject(project);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 12),
                  Text('Rename'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openProject(project),
      ),
    );
  }
}