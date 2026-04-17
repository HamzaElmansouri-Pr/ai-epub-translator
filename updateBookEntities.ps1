$content = Get-Content -Path 'lib\features\library\domain\entities\book.dart' -Raw
$oldString = @"
  final String status; // 'want_to_read', 'reading', 'finished'
  final bool isFavorite;

  const Book({
