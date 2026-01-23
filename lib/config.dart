class ApiConfig {
  // For Android Emulator: use 10.0.2.2
  // For iOS Simulator: use localhost or 127.0.0.1
  // For Real Device: use your computer's local IP (e.g., 192.168.1.x)
  
  static const String baseUrl = 'http://192.168.100.63:3000';
  
  // Alternative: Automatically detect platform
  // static String get baseUrl {
  //   if (Platform.isAndroid) {
  //     return 'http://10.0.2.2:3000';
  //   } else if (Platform.isIOS) {
  //     return 'http://localhost:3000';
  //   } else {
  //     return 'http://localhost:3000';
  //   }
  // }
  
  // API Endpoints
  static const String getFilterOptions = '$baseUrl/get-filter-options';
  static const String getAllStudents = '$baseUrl/get-all-students';
  static const String getAllTeachers = '$baseUrl/get-all-teachers';
  static const String addStudent = '$baseUrl/add-student';
  static const String updateStudent = '$baseUrl/update-student';
  static const String deleteStudent = '$baseUrl/delete-student';
  static const String addTeacher = '$baseUrl/add-teacher';
  static const String updateTeacher = '$baseUrl/update-teacher';
  static const String deleteTeacher = '$baseUrl/delete-teacher';
  static const String addFilterOption = '$baseUrl/add-filter-option';
  static const String deleteFilterOption = '$baseUrl/delete-filter-option';
}