/// Base contract for use cases in Clean Architecture
abstract class UseCase<Type, Params> {
  Future<Type> call(Params params);
}

class NoParams {
  const NoParams();
}
