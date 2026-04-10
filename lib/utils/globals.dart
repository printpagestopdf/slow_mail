import 'package:flutter/widgets.dart';

extension ListExt on List {
  int insertPosSorted<T>(T item, int Function(T a, T b) compare) {
    int low = 0;
    int high = length;

    while (low < high) {
      final mid = (low + high) >> 1;
      if (compare(item, this[mid]) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  void insertSorted<T>(T item, int Function(T a, T b) compare, {bool Function(T)? dedup}) {
    if (dedup != null && dedup(item)) return;
    int low = insertPosSorted(item, compare);
    insert(low, item);
  }

  void insertAllSorted<T>(List<T> items, int Function(T a, T b) compare, {bool Function(List<T>)? dedup}) {
    if (dedup != null) dedup(items);
    items.sort(compare);
    int low = insertPosSorted(items.first, compare);
    insertAll(low, items);
  }
}

class SlowMailVersion {
  static String exporFileVersion = "1.0";
  static String exportFileType = "SlowMailAccounts";
}

class NavService {
  static final navKey = GlobalKey<NavigatorState>();
}

class MessageException implements Exception {
  String cause;
  MessageException(this.cause);

  @override
  String toString() {
    return cause;
  }
}

class WrongPasswordException extends MessageException {
  WrongPasswordException(super.cause);
}

extension NestedMapAccess on Map {
  dynamic getPathValue(String path) {
    return getNestedValue(path.split("/"));
  }

  void setPathValue(String path, dynamic value) {
    dynamic p = this;
    for (final key in path.split("/")) {
      if (!containsKey(key)) p[key] = null;
      p = p[key];
    }
    p = value;
  }

  bool hasKeyChain(List keys) {
    dynamic current = this;
    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return false;
      }
    }
    return true;
  }

  dynamic getNestedValue(List keys) {
    dynamic current = this;
    for (final key in keys) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }
}
