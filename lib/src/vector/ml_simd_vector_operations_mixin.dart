import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ml_linalg/matrix.dart';
import 'package:ml_linalg/norm.dart';
import 'package:ml_linalg/src/vector/ml_simd_operations_helper.dart';
import 'package:ml_linalg/src/vector/ml_vector_data_store.dart';
import 'package:ml_linalg/src/vector/ml_vector_factory.dart';
import 'package:ml_linalg/src/vector/ml_typed_data_helper.dart';
import 'package:ml_linalg/vector.dart';

abstract class MLSimdVectorOperationsMixin<E, S extends List<E>>
    implements
        IterableMixin<double>,
        MLSimdOperationsHelper<E, S>,
        MLTypedListFactory,
        MLVectorDataStore<E, S>,
        MLVectorFactory<E, S>,
        MLVector {
  S get dataWithoutLastBucket => sublist(data, 0, data.length - 1);

  @override
  Iterator<double> get iterator =>
      getIterator((data as TypedData).buffer, length);

  bool get _isLastBucketNotFull => length % bucketSize > 0;

  @override
  MLVector operator +(Object value) {
    if (value is MLVector) {
      return _elementWiseVectorOperation(value, simdSum);
    } else if (value is MLMatrix) {
      final other = value.toVector();
      return _elementWiseVectorOperation(other, simdSum);
    } else if (value is num) {
      return _elementWiseSimdScalarOperation(
          createSimdFilled(value.toDouble()), simdSum);
    }
    throw UnsupportedError('Unsupported operand type: ${value.runtimeType}');
  }

  @override
  MLVector operator -(Object value) {
    if (value is MLVector) {
      return _elementWiseVectorOperation(value, simdSub);
    } else if (value is MLMatrix) {
      final other = value.toVector();
      return _elementWiseVectorOperation(other, simdSub);
    } else if (value is num) {
      return _elementWiseSimdScalarOperation(
          createSimdFilled(value.toDouble()), simdSub);
    }
    throw UnsupportedError('Unsupported operand type: ${value.runtimeType}');
  }

  @override
  MLVector operator *(Object value) {
    if (value is MLVector) {
      return _elementWiseVectorOperation(value, simdMul);
    } else if (value is MLMatrix) {
      return _matrixMul(value);
    } else if (value is num) {
      return _elementWiseFloatScalarOperation(value.toDouble(), simdScale);
    }
    throw UnsupportedError('Unsupported operand type: ${value.runtimeType}');
  }

  @override
  MLVector operator /(Object value) {
    if (value is MLVector) {
      return _elementWiseVectorOperation(value, simdDiv);
    } else if (value is num) {
      return _elementWiseFloatScalarOperation(1 / value, simdScale);
    }
    throw UnsupportedError('Unsupported operand type: ${value.runtimeType}');
  }

  @override
  MLVector toIntegerPower(int power) => _elementWisePow(power);

  /// Returns a vector filled with absolute values of an each component of [this] vector
  @override
  MLVector abs() =>
      _elementWiseSelfOperation((E element, [int i]) => simdAbs(element));

  @override
  double dot(MLVector vector) => (this * vector).sum();

  /// Returns sum of all vector components
  @override
  double sum() => singleSIMDSum(data.reduce(simdSum));

  @override
  double distanceTo(MLVector vector, [Norm norm = Norm.euclidean]) =>
      (this - vector).norm(norm);

  @override
  double mean() => sum() / length;

  @override
  double norm([Norm norm = Norm.euclidean]) {
    final power = _getPowerByNormType(norm);
    if (power == 1) {
      return abs().sum();
    }
    return math.pow(toIntegerPower(power).sum(), 1 / power) as double;
  }

  @override
  double max() {
    if (_isLastBucketNotFull) {
      var max = -double.infinity;
      final listOnlyWithFullBuckets = dataWithoutLastBucket;
      if (listOnlyWithFullBuckets.isNotEmpty) {
        max = getMaxLane(listOnlyWithFullBuckets.reduce(selectMax));
      }
      return simdToList(data.last)
          .take(length % bucketSize)
          .fold(max, math.max);
    } else {
      return getMaxLane(data.reduce(selectMax));
    }
  }

  @override
  double min() {
    if (_isLastBucketNotFull) {
      var min = double.infinity;
      final listOnlyWithFullBuckets = dataWithoutLastBucket;
      if (listOnlyWithFullBuckets.isNotEmpty) {
        min = getMinLane(listOnlyWithFullBuckets.reduce(selectMin));
      }
      return simdToList(data.last)
          .take(length % bucketSize)
          .fold(min, math.min);
    } else {
      return getMinLane(data.reduce(selectMin));
    }
  }

  @override
  MLVector query(Iterable<int> indexes) {
    final list = createTypedList(indexes.length);
    int i = 0;
    for (final idx in indexes) {
      list[i++] = this[idx];
    }
    return createVectorFrom(list);
  }

  @override
  MLVector unique() {
    final unique = <double>[];
    for (int i = 0; i < length; i++) {
      final el = this[i];
      if (!unique.contains(el)) {
        unique.add(el);
      }
    }
    return createVectorFrom(unique);
  }

  @override
  double operator [](int index) {
    if (index >= length) throw RangeError.index(index, this);
    final base = (index / bucketSize).floor();
    final offset = index - base * bucketSize;
    return getScalarByOffsetIndex(data[base], offset);
  }

  @override
  void operator []=(int index, double value) {
    if (!isMutable) throw _dontMutateError();
    if (index >= length) throw RangeError.index(index, this);
    final base = (index / bucketSize).floor();
    final offset = index - base * bucketSize;
    data[base] = mutateSimdValueWithScalar(data[base], offset, value);
  }

  @override
  MLVector subvector(int start, [int end]) {
    final collection = bufferAsTypedList((data as TypedData).buffer, start,
        (end > length ? length : end) - start);
    return createVectorFrom(collection);
  }

  /// Returns exponent depending on vector norm type (for Euclidean norm - 2, Manhattan - 1)
  int _getPowerByNormType(Norm norm) {
    switch (norm) {
      case Norm.euclidean:
        return 2;
      case Norm.manhattan:
        return 1;
      default:
        throw UnsupportedError('Unsupported norm type!');
    }
  }

  /// Returns a SIMD value raised to the integer power
  E _simdToIntPow(E lane, int power) {
    if (power == 0) {
      return createSimdFilled(1.0);
    }

    final x = _simdToIntPow(lane, power ~/ 2);
    final sqrX = simdMul(x, x);

    if (power % 2 == 0) {
      return sqrX;
    }

    return simdMul(lane, sqrX);
  }

  /// Returns SIMD list (e.g. Float32x4List) as a result of converting iterable source
  ///
  /// All sequence of [collection] elements splits into groups with [_bucketSize] length
  S convertCollectionToSIMDList(List<double> collection) {
    final numOfBuckets = (collection.length / bucketSize).ceil();
    final source = collection is Float32List
        ? collection
        : createTypedListFromList(collection);
    final target = createSIMDList(numOfBuckets);

    for (int i = 0; i < numOfBuckets; i++) {
      final start = i * bucketSize;
      final end = start + bucketSize;
      final bucketAsList = source.sublist(start, math.min(end, source.length));
      target[i] = createSimdFromSimpleList(bucketAsList);
    }

    return target;
  }

  /// Returns a vector as a result of applying to [this] any element-wise operation with a simd value
  MLVector _elementWiseFloatScalarOperation(
      double scalar, E operation(E a, double b)) {
    final list = createSIMDList(data.length);
    for (int i = 0; i < data.length; i++) {
      list[i] = operation(data[i], scalar);
    }
    return createVectorFromSIMDList(list, length);
  }

  /// Returns a vector as a result of applying to [this] any element-wise operation with a simd value
  MLVector _elementWiseSimdScalarOperation(E simdVal, E operation(E a, E b)) {
    final list = createSIMDList(data.length);
    for (int i = 0; i < data.length; i++) {
      list[i] = operation(data[i], simdVal);
    }
    return createVectorFromSIMDList(list, length);
  }

  /// Returns a vector as a result of applying to [this] any element-wise operation with a vector (e.g. vector addition)
  MLVector _elementWiseVectorOperation(MLVector vector, E operation(E a, E b)) {
    if (vector.length != length) throw _mismatchLengthError();
    final list = createSIMDList(data.length);
    for (int i = 0; i < data.length; i++) {
      list[i] = operation(data[i], (vector as MLVectorDataStore<E, S>).data[i]);
    }
    return createVectorFromSIMDList(list, length);
  }

  MLVector _elementWiseSelfOperation(E operation(E element, [int index])) {
    final list = createSIMDList(data.length);
    for (int i = 0; i < data.length; i++) {
      list[i] = operation(data[i], i);
    }
    return createVectorFromSIMDList(list, length);
  }

  /// Returns a vector as a result of applying to [this] element-wise raising to the integer power
  MLVector _elementWisePow(int exp) {
    final list = createSIMDList(data.length);
    for (int i = 0; i < data.length; i++) {
      list[i] = _simdToIntPow(data[i], exp);
    }
    return createVectorFromSIMDList(list, length);
  }

  MLVector _matrixMul(MLMatrix matrix) {
    if (length != matrix.rowsNum) {
      throw Exception(
          'Multiplication by a matrix with diffrent number of rows than the vector length is not allowed:'
          'vector length: $length, matrix row number: ${matrix.rowsNum}');
    }
    final source = List<double>.generate(
        matrix.columnsNum, (int i) => dot(matrix.getColumn(i)));
    return createVectorFrom(source);
  }

  UnsupportedError _dontMutateError() =>
      UnsupportedError('mutation operations unsupported for immutable vectors');
  RangeError _mismatchLengthError() =>
      RangeError('Vectors length must be equal');
}