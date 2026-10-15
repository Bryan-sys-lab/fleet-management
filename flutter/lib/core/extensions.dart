/// Small collection helpers used across the app.
extension HelixIterableExtension<T> on Iterable<T> {
  T? firstMatchOrNull([bool Function(T element)? test]) {
    for (final element in this) {
      if (test == null || test(element)) return element;
    }
    return null;
  }
}

extension HelixListExtension<T> on List<T> {
  T? firstMatchOrNull([bool Function(T element)? test]) {
    for (final element in this) {
      if (test == null || test(element)) return element;
    }
    return null;
  }

  T? firstOrNullSafe([bool Function(T element)? test]) => firstMatchOrNull(test);
}

extension HelixMapExtension<K, V> on Map<K, V> {
  V? maybeGet(K key) => containsKey(key) ? this[key] : null;
}
