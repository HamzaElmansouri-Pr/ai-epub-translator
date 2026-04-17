\ = Get-Content 'C:\Users\profa\OneDrive\Desktop\Project\Epub Translat App\lib\main.dart' -Raw
\ = \ -replace 'import ''core/di/injection.dart'';', "import 'core/di/injection.dart';
import 'core/services/background_service.dart';"
\ = \ -replace 'await configureDependencies\(\);', "await configureDependencies();

  // Initialize background service
  await initializeService();"
Set-Content -Path 'C:\Users\profa\OneDrive\Desktop\Project\Epub Translat App\lib\main.dart' -Value \
