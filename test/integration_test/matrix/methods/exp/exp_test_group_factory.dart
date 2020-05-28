import 'dart:math' as math;
import 'package:ml_linalg/dtype.dart';
import 'package:ml_linalg/linalg.dart';
import 'package:ml_tech/unit_testing/matchers/iterable_2d_almost_equal_to.dart';
import 'package:test/test.dart';

import '../../../../dtype_to_title.dart';

void matrixExpTestGroupFactory(DType dtype) =>
    group(dtypeToMatrixTestTitle[dtype], () {
      group('exp method', () {
        test('should raise euler\'s numbers to elements of matrix', () {
          final matrix = Matrix.fromList([
            [1, 2, 3, 4],
            [5, 6, 7, 8],
          ], dtype: dtype);
          final result = matrix.exp();

          expect(result, iterable2dAlmostEqualTo([
            [math.exp(1), math.exp(2), math.exp(3), math.exp(4)],
            [math.exp(5), math.exp(6), math.exp(7), math.exp(8)],
          ], 1e-3));
          expect(result.dtype, dtype);
        });
      });
    });
