import 'package:flutter/material.dart';

class GlobalValueKey extends GlobalObjectKey {
  const GlobalValueKey(super.value);

  @override
  bool operator ==(Object other) => (
    other.runtimeType == runtimeType
    && other is GlobalValueKey
    && other.value == value
  );

  @override
  int get hashCode => value.hashCode;
}
