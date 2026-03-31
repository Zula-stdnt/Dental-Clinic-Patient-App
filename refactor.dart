import 'dart:io';

void main() async {
  final dirPath =
      r'c:\xampp\htdocs\Dental_Clinic_Project\github\Patients_App - Copy\lib';
  final dir = Directory(dirPath);
  final libPath = dir.path;
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) => f.path.endsWith('.dart') && !f.path.endsWith('config.dart'),
      );

  final urlPrefix =
      'http://[IP_ADDRESS]/Dental_Clinic_Project/Patients_App_API';

  for (var file in files) {
    try {
      var content = await file.readAsString();
      if (content.contains(urlPrefix)) {
        // Replace URL
        content = content.replaceAll(urlPrefix, r'${ApiConfig.baseUrl}');

        // Find if ApiConfig is already imported
        if (!content.contains('config.dart')) {
          String fileStr = file.path.replaceAll('\\', '/');
          String libStr = libPath.replaceAll('\\', '/');

          String relativeFilePath = fileStr;
          if (fileStr.startsWith(libStr)) {
            relativeFilePath = fileStr.substring(libStr.length);
          }
          if (relativeFilePath.startsWith('/')) {
            relativeFilePath = relativeFilePath.substring(1);
          }

          int depth = relativeFilePath.split('/').length - 1;
          String importPath = 'config.dart';
          if (depth > 0) {
            importPath = List.filled(depth, '..').join('/') + '/config.dart';
          }

          final importStmt = "import '$importPath';";

          // Find last import statement
          final importRegex = RegExp(r'''import\s+['"].*?['"];''');
          final imports = importRegex.allMatches(content);

          if (imports.isNotEmpty) {
            final lastImport = imports.last;
            content = content.replaceRange(
              lastImport.end,
              lastImport.end,
              '\n$importStmt',
            );
          } else {
            content = "$importStmt\n" + content;
          }
        }

        await file.writeAsString(content);
        print('Updated ${file.path}');
      }
    } catch (e) {
      print('Error processing ${file.path}: $e');
    }
  }
}
