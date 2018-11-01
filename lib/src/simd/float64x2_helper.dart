import 'dart:math' as math;
import 'dart:typed_data';

import 'package:linalg/src/simd/simd_helper.dart';

class Float64x2Helper implements SIMDHelper<Float64x2List, Float64List, Float64x2> {

  @override
  final bucketSize = 2;

  const Float64x2Helper();

  @override
  Float64x2 createSIMDFilled(double value) => Float64x2.splat(value);

  @override
  Float64x2 createSIMDFromSimpleList(List<double> list) {
    final x = list.isNotEmpty ? list[0] ?? 0.0 : 0.0;
    final y = list.length > 1 ? list[1] ?? 0.0 : 0.0;
    return Float64x2(x, y);
  }

  @override
  Float64x2 simdSum(Float64x2 a, Float64x2 b) => a + b;

  @override
  Float64x2 simdSub(Float64x2 a, Float64x2 b) => a - b;

  @override
  Float64x2 simdMul(Float64x2 a, Float64x2 b) => a * b;

  @override
  Float64x2 simdDiv(Float64x2 a, Float64x2 b) => a / b;

  @override
  Float64x2 simdAbs(Float64x2 a) => a.abs();

  @override
  double singleSIMDSum(Float64x2 a) => (a.x.isNaN ? 0.0 : a.x) + (a.y.isNaN ? 0.0 : a.y);

  @override
  Float64x2List createSIMDList(int length) => Float64x2List(length);

  @override
  Float64List createTypedList(int length) => Float64List(length);

  @override
  Float64List createTypedListFromList(List<double> list) => Float64List.fromList(list);

  @override
  Float64List createTypedListFromByteBuffer(ByteBuffer buffer) => Float64List.view(buffer);

  @override
  double getScalarByOffsetIndex(Float64x2 value, int offset) {
    switch (offset) {
      case 0:
        return value.x;
      case 1:
        return value.y;
      default:
        throw RangeError('wrong offset');
    }
  }

  @override
  Float64x2 selectMax(Float64x2 a, Float64x2 b) => a.max(b);

  @override
  double getMaxLane(Float64x2 a) => math.max(a.x, a.y);

  @override
  Float64x2 selectMin(Float64x2 a, Float64x2 b) => a.min(b);

  @override
  double getMinLane(Float64x2 a) => math.min(a.x, a.y);

  @override
  List<double> simdToList(Float64x2 a) => <double>[a.x, a.y];

  @override
  List<double> takeFirstNLanes(Float64x2 a, int n) => simdToList(a)
      .take(n)
      .toList();

  @override
  Float64x2List sublist(Float64x2List list, int start, [int end]) =>
      list.buffer.asFloat64x2List(start * Float64x2List.bytesPerElement, end);

  @override
  Float64List bufferAsTypedList(ByteBuffer buffer, int start, int length) =>
      buffer.asFloat64List(start * Float64List.bytesPerElement, length);
}