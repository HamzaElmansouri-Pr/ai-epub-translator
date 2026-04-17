import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:epub_translate_meaning/core/error/exceptions.dart';
import 'package:epub_translate_meaning/core/error/failures.dart';
import 'package:epub_translate_meaning/features/dictionary/data/datasources/dictionary_api_datasource.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/entities/dictionary_entry.dart';
import 'package:epub_translate_meaning/features/dictionary/domain/repositories/dictionary_repository.dart';

@LazySingleton(as: DictionaryRepository)
class DictionaryRepositoryImpl implements DictionaryRepository {
  final DictionaryApiDataSource remoteDataSource;

  DictionaryRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<DictionaryEntry>>> lookupWord(String word) async {
    try {
      final entries = await remoteDataSource.lookupWord(word);
      return Right(entries);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error occurred'));
    }
  }
}