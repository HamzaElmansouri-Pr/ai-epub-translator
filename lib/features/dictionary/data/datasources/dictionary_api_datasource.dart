import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/exceptions.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/entities/dictionary_entry.dart';

abstract class DictionaryApiDataSource {
  Future<List<DictionaryEntry>> lookupWord(String word);
}

@LazySingleton(as: DictionaryApiDataSource)
class DictionaryApiDataSourceImpl implements DictionaryApiDataSource {
  final Dio dio;

  DictionaryApiDataSourceImpl(this.dio);

  @override
  Future<List<DictionaryEntry>> lookupWord(String word) async {
    try {
      final response = await dio.get('https://api.dictionaryapi.dev/api/v2/entries/en/$word');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => DictionaryEntry.fromJson(json)).toList();
      } else {
        throw ServerException('Failed to lookup word');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return []; // Word not found, return empty array rather than failure
      }
      throw ServerException('Failed to connect to Dictionary API');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}