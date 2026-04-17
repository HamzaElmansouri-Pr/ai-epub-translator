$content = Get-Content -Path 'lib\core\services\background_service.dart' -Raw
$content = $content -replace \"import 'package:epub_translate_meaning/features/library/data/models/book_model\.dart';\", \"import 'package:epub_translate_meaning/features/library/domain/entities/book.dart';
import 'package:epub_translate_meaning/features/library/data/models/book_model.dart';\"
Set-Content -Path 'lib\core\services\background_service.dart' -Value $content
