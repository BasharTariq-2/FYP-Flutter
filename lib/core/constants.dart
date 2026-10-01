class AppConstants {
  // API Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 10;

  // Batch Types
  static const List<String> batchTypes = ['Caged', 'Free Range'];

  // Batch Status
  static const List<String> batchStatus = ['Active', 'Completed', 'Discarded'];

  // Egg Grades
  static const List<String> eggGrades = ['A', 'B', 'C' /*, 'Broken' */];

  // Feed Types
  static const List<Map<String, dynamic>> feedTypes = [
    {'id': 1, 'name': 'Starter Feed'},
    {'id': 2, 'name': 'Grower Feed'},
    {'id': 3, 'name': 'Finisher Feed'},
  ];

  // Health Standards - Default values
  static const Map<String, Map<int, Map<String, double>>> growthStandards = {
    'Caged': {
      1: {'minWeight': 80, 'maxWeight': 120, 'minTemp': 32, 'maxTemp': 35},
      2: {'minWeight': 200, 'maxWeight': 280, 'minTemp': 30, 'maxTemp': 33},
      3: {'minWeight': 400, 'maxWeight': 500, 'minTemp': 28, 'maxTemp': 31},
      4: {'minWeight': 600, 'maxWeight': 750, 'minTemp': 26, 'maxTemp': 29},
    },
    'Free Range': {
      1: {'minWeight': 70, 'maxWeight': 110, 'minTemp': 32, 'maxTemp': 35},
      2: {'minWeight': 180, 'maxWeight': 260, 'minTemp': 30, 'maxTemp': 33},
      3: {'minWeight': 370, 'maxWeight': 470, 'minTemp': 28, 'maxTemp': 31},
      4: {'minWeight': 570, 'maxWeight': 720, 'minTemp': 26, 'maxTemp': 29},
    },
  };
}