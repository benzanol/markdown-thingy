extension WhereNonNullExtension<T> on Iterator<T?> {
  Iterable<T> whereNonNull() sync* {
    while (moveNext()) {
      final cur = current;
      if (cur != null) yield cur;
    }
  }
}

extension PipeExtension<T> on T {
  R pipe<R>(R Function(T) fn) => fn(this);
}
