import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class FileFailure extends Failure {
  const FileFailure(super.message);
}

class AllProvidersExhaustedFailure extends Failure {
  const AllProvidersExhaustedFailure(super.message);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message);
}
