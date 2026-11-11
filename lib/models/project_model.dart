class ProjectModel {
  final String id;
  final String name;
  final String description;
  final double canvasWidth;
  final double canvasHeight;
  final List<Map<String, dynamic>> widgets;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    this.canvasWidth = 360,
    this.canvasHeight = 650,
    required this.widgets,
  });

  int get widgetCount => widgets.length;
}