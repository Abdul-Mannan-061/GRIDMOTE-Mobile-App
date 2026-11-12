import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project_model.dart';
import 'auth_service.dart';

class ProjectStorage {
  static final Map<String, Future<Directory>> _directories = {};

  static void _validateId(String id) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid project ID.');
    }
  }

  static Future<Directory> _projectsDirectory() async {
    final auth = AuthService.instance;
    final user = auth.currentUser;

    if (user == null) {
      throw const AuthException('Log in to access projects.');
    }

    // Capture the user before any await.
    final userId = user.id;
    final ownsLegacyProjects = userId == auth.legacyOwnerId;

    final pending = _directories.putIfAbsent(
      userId,
          () => _prepareDirectory(userId, ownsLegacyProjects),
    );

    try {
      return await pending;
    } catch (_) {
      _directories.remove(userId);
      rethrow;
    }
  }

  static Future<Directory> _prepareDirectory(
      String userId,
      bool ownsLegacyProjects,
      ) async {
    _validateId(userId);

    final documents = await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${documents.path}/gridmote_users/$userId/projects',
    );

    await directory.create(recursive: true);

    if (ownsLegacyProjects) {
      final marker = File('${directory.path}/.legacy_migrated');

      if (!await marker.exists()) {
        final legacy = Directory(
          '${documents.path}/gridmote_projects',
        );

        if (await legacy.exists()) {
          await for (final entry in legacy.list(followLinks: false)) {
            if (entry is! File || !entry.path.endsWith('.json')) {
              continue;
            }

            final filename = entry.uri.pathSegments.last;
            final id = filename.substring(0, filename.length - 5);
            _validateId(id);

            final destination = File('${directory.path}/$filename');

            // Retrying a partial migration never overwrites a copied file.
            if (!await destination.exists()) {
              final temporary = await entry.copy(
                '${destination.path}.migration',
              );

              await temporary.rename(destination.path);
            }
          }
        }

        // Prevent deleted/renamed projects being copied again later.
        await marker.writeAsString('complete', flush: true);
      }
    }

    return directory;
  }

  static Future<void> _writeProject(
      Directory directory,
      ProjectModel project,
      ) async {
    _validateId(project.id);

    final destination = '${directory.path}/${project.id}.json';
    final temporary = File('$destination.tmp');

    final data = {
      'storageVersion': 1,
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'canvasWidth': project.canvasWidth,
      'canvasHeight': project.canvasHeight,
      'widgets': project.widgets,
    };

    await temporary.writeAsString(
      jsonEncode(data),
      flush: true,
    );

    await temporary.rename(destination);
  }

  static Future<void> saveProject(ProjectModel project) async {
    final directory = await _projectsDirectory();
    await _writeProject(directory, project);
  }

  static Future<void> renameProject(
      ProjectModel project,
      String newName,
      ) async {
    final name = newName.trim();

    if (name.isEmpty || name.length > 60) {
      throw const FormatException(
        'Project name must contain 1 to 60 characters.',
      );
    }

    _validateId(project.id);

    final directory = await _projectsDirectory();
    final file = File('${directory.path}/${project.id}.json');

    if (!await file.exists()) {
      throw const FormatException('Saved project was not found.');
    }

    await _writeProject(
      directory,
      ProjectModel(
        id: project.id,
        name: name,
        description: project.description,
        canvasWidth: project.canvasWidth,
        canvasHeight: project.canvasHeight,
        widgets: project.widgets,
      ),
    );
  }

  static Future<void> deleteProject(String id) async {
    _validateId(id);

    final directory = await _projectsDirectory();
    final file = File('${directory.path}/$id.json');

    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<List<ProjectModel>> loadProjects() async {
    final directory = await _projectsDirectory();
    final projects = <ProjectModel>[];

    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File || !entry.path.endsWith('.json')) {
        continue;
      }

      final dynamic decoded = jsonDecode(
        await entry.readAsString(),
      );

      if (decoded is! Map<String, dynamic> ||
          decoded['storageVersion'] != 1 ||
          decoded['id'] is! String ||
          decoded['name'] is! String ||
          decoded['description'] is! String ||
          decoded['canvasWidth'] is! num ||
          decoded['canvasHeight'] is! num ||
          decoded['widgets'] is! List) {
        throw const FormatException(
          'A saved project contains invalid data.',
        );
      }

      final id = decoded['id'] as String;
      _validateId(id);

      final widgets = <Map<String, dynamic>>[];

      for (final widget in decoded['widgets'] as List) {
        if (widget is! Map<String, dynamic>) {
          throw const FormatException(
            'A saved widget contains invalid data.',
          );
        }

        widgets.add(Map<String, dynamic>.from(widget));
      }

      projects.add(
        ProjectModel(
          id: id,
          name: decoded['name'] as String,
          description: decoded['description'] as String,
          canvasWidth: (decoded['canvasWidth'] as num).toDouble(),
          canvasHeight: (decoded['canvasHeight'] as num).toDouble(),
          widgets: widgets,
        ),
      );
    }

    projects.sort(
          (first, second) => first.name.toLowerCase().compareTo(
        second.name.toLowerCase(),
      ),
    );

    return projects;
  }
}
