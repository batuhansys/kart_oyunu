/// Basit, bağımlılıksız bir Result tipi. Hata yönetimini exception
/// fırlatıp yakalamak yerine açık ve tip güvenli şekilde yapmayı
/// sağlar. Dart 3'ün sealed class + pattern matching özelliğini
/// kullanır, ek bir paket gerektirmez.
sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(String message) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.value);
    if (self is Failure<T>) return failure(self.message);
    throw StateError('Bilinmeyen Result alt tipi: $runtimeType');
  }

  bool get isSuccess => this is Success<T>;
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}
