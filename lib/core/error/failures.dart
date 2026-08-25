abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred.']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Failed to load local cache.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Please check your internet connection.']);
}
