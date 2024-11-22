// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'labeler.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

LabelResult _$LabelResultFromJson(Map<String, dynamic> json) {
  return _LabelResult.fromJson(json);
}

/// @nodoc
mixin _$LabelResult {
  String get imagePath => throw _privateConstructorUsedError;
  double get xRatio =>
      throw _privateConstructorUsedError; // vashing (road direction) at x = xRatio * width
  double get yRatio =>
      throw _privateConstructorUsedError; // vashing (road direction) at y = yRatio * height
  double get leftRatio =>
      throw _privateConstructorUsedError; // leftRatio * (pi / 2) from vertical
  double get rightRatio =>
      throw _privateConstructorUsedError; // rightRatio * (pi / 2) from vertical
  double get yRatioObstacleMax =>
      throw _privateConstructorUsedError; // obs bottom at this ratio * height
  double get xRatioObstacleMin =>
      throw _privateConstructorUsedError; // obs left at this ratio * width
  double get xRatioObstacleMax => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $LabelResultCopyWith<LabelResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LabelResultCopyWith<$Res> {
  factory $LabelResultCopyWith(
          LabelResult value, $Res Function(LabelResult) then) =
      _$LabelResultCopyWithImpl<$Res, LabelResult>;
  @useResult
  $Res call(
      {String imagePath,
      double xRatio,
      double yRatio,
      double leftRatio,
      double rightRatio,
      double yRatioObstacleMax,
      double xRatioObstacleMin,
      double xRatioObstacleMax});
}

/// @nodoc
class _$LabelResultCopyWithImpl<$Res, $Val extends LabelResult>
    implements $LabelResultCopyWith<$Res> {
  _$LabelResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imagePath = null,
    Object? xRatio = null,
    Object? yRatio = null,
    Object? leftRatio = null,
    Object? rightRatio = null,
    Object? yRatioObstacleMax = null,
    Object? xRatioObstacleMin = null,
    Object? xRatioObstacleMax = null,
  }) {
    return _then(_value.copyWith(
      imagePath: null == imagePath
          ? _value.imagePath
          : imagePath // ignore: cast_nullable_to_non_nullable
              as String,
      xRatio: null == xRatio
          ? _value.xRatio
          : xRatio // ignore: cast_nullable_to_non_nullable
              as double,
      yRatio: null == yRatio
          ? _value.yRatio
          : yRatio // ignore: cast_nullable_to_non_nullable
              as double,
      leftRatio: null == leftRatio
          ? _value.leftRatio
          : leftRatio // ignore: cast_nullable_to_non_nullable
              as double,
      rightRatio: null == rightRatio
          ? _value.rightRatio
          : rightRatio // ignore: cast_nullable_to_non_nullable
              as double,
      yRatioObstacleMax: null == yRatioObstacleMax
          ? _value.yRatioObstacleMax
          : yRatioObstacleMax // ignore: cast_nullable_to_non_nullable
              as double,
      xRatioObstacleMin: null == xRatioObstacleMin
          ? _value.xRatioObstacleMin
          : xRatioObstacleMin // ignore: cast_nullable_to_non_nullable
              as double,
      xRatioObstacleMax: null == xRatioObstacleMax
          ? _value.xRatioObstacleMax
          : xRatioObstacleMax // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LabelResultImplCopyWith<$Res>
    implements $LabelResultCopyWith<$Res> {
  factory _$$LabelResultImplCopyWith(
          _$LabelResultImpl value, $Res Function(_$LabelResultImpl) then) =
      __$$LabelResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String imagePath,
      double xRatio,
      double yRatio,
      double leftRatio,
      double rightRatio,
      double yRatioObstacleMax,
      double xRatioObstacleMin,
      double xRatioObstacleMax});
}

/// @nodoc
class __$$LabelResultImplCopyWithImpl<$Res>
    extends _$LabelResultCopyWithImpl<$Res, _$LabelResultImpl>
    implements _$$LabelResultImplCopyWith<$Res> {
  __$$LabelResultImplCopyWithImpl(
      _$LabelResultImpl _value, $Res Function(_$LabelResultImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imagePath = null,
    Object? xRatio = null,
    Object? yRatio = null,
    Object? leftRatio = null,
    Object? rightRatio = null,
    Object? yRatioObstacleMax = null,
    Object? xRatioObstacleMin = null,
    Object? xRatioObstacleMax = null,
  }) {
    return _then(_$LabelResultImpl(
      imagePath: null == imagePath
          ? _value.imagePath
          : imagePath // ignore: cast_nullable_to_non_nullable
              as String,
      xRatio: null == xRatio
          ? _value.xRatio
          : xRatio // ignore: cast_nullable_to_non_nullable
              as double,
      yRatio: null == yRatio
          ? _value.yRatio
          : yRatio // ignore: cast_nullable_to_non_nullable
              as double,
      leftRatio: null == leftRatio
          ? _value.leftRatio
          : leftRatio // ignore: cast_nullable_to_non_nullable
              as double,
      rightRatio: null == rightRatio
          ? _value.rightRatio
          : rightRatio // ignore: cast_nullable_to_non_nullable
              as double,
      yRatioObstacleMax: null == yRatioObstacleMax
          ? _value.yRatioObstacleMax
          : yRatioObstacleMax // ignore: cast_nullable_to_non_nullable
              as double,
      xRatioObstacleMin: null == xRatioObstacleMin
          ? _value.xRatioObstacleMin
          : xRatioObstacleMin // ignore: cast_nullable_to_non_nullable
              as double,
      xRatioObstacleMax: null == xRatioObstacleMax
          ? _value.xRatioObstacleMax
          : xRatioObstacleMax // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LabelResultImpl implements _LabelResult {
  const _$LabelResultImpl(
      {required this.imagePath,
      required this.xRatio,
      required this.yRatio,
      required this.leftRatio,
      required this.rightRatio,
      required this.yRatioObstacleMax,
      required this.xRatioObstacleMin,
      required this.xRatioObstacleMax});

  factory _$LabelResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$LabelResultImplFromJson(json);

  @override
  final String imagePath;
  @override
  final double xRatio;
// vashing (road direction) at x = xRatio * width
  @override
  final double yRatio;
// vashing (road direction) at y = yRatio * height
  @override
  final double leftRatio;
// leftRatio * (pi / 2) from vertical
  @override
  final double rightRatio;
// rightRatio * (pi / 2) from vertical
  @override
  final double yRatioObstacleMax;
// obs bottom at this ratio * height
  @override
  final double xRatioObstacleMin;
// obs left at this ratio * width
  @override
  final double xRatioObstacleMax;

  @override
  String toString() {
    return 'LabelResult(imagePath: $imagePath, xRatio: $xRatio, yRatio: $yRatio, leftRatio: $leftRatio, rightRatio: $rightRatio, yRatioObstacleMax: $yRatioObstacleMax, xRatioObstacleMin: $xRatioObstacleMin, xRatioObstacleMax: $xRatioObstacleMax)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LabelResultImpl &&
            (identical(other.imagePath, imagePath) ||
                other.imagePath == imagePath) &&
            (identical(other.xRatio, xRatio) || other.xRatio == xRatio) &&
            (identical(other.yRatio, yRatio) || other.yRatio == yRatio) &&
            (identical(other.leftRatio, leftRatio) ||
                other.leftRatio == leftRatio) &&
            (identical(other.rightRatio, rightRatio) ||
                other.rightRatio == rightRatio) &&
            (identical(other.yRatioObstacleMax, yRatioObstacleMax) ||
                other.yRatioObstacleMax == yRatioObstacleMax) &&
            (identical(other.xRatioObstacleMin, xRatioObstacleMin) ||
                other.xRatioObstacleMin == xRatioObstacleMin) &&
            (identical(other.xRatioObstacleMax, xRatioObstacleMax) ||
                other.xRatioObstacleMax == xRatioObstacleMax));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      imagePath,
      xRatio,
      yRatio,
      leftRatio,
      rightRatio,
      yRatioObstacleMax,
      xRatioObstacleMin,
      xRatioObstacleMax);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$LabelResultImplCopyWith<_$LabelResultImpl> get copyWith =>
      __$$LabelResultImplCopyWithImpl<_$LabelResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LabelResultImplToJson(
      this,
    );
  }
}

abstract class _LabelResult implements LabelResult {
  const factory _LabelResult(
      {required final String imagePath,
      required final double xRatio,
      required final double yRatio,
      required final double leftRatio,
      required final double rightRatio,
      required final double yRatioObstacleMax,
      required final double xRatioObstacleMin,
      required final double xRatioObstacleMax}) = _$LabelResultImpl;

  factory _LabelResult.fromJson(Map<String, dynamic> json) =
      _$LabelResultImpl.fromJson;

  @override
  String get imagePath;
  @override
  double get xRatio;
  @override // vashing (road direction) at x = xRatio * width
  double get yRatio;
  @override // vashing (road direction) at y = yRatio * height
  double get leftRatio;
  @override // leftRatio * (pi / 2) from vertical
  double get rightRatio;
  @override // rightRatio * (pi / 2) from vertical
  double get yRatioObstacleMax;
  @override // obs bottom at this ratio * height
  double get xRatioObstacleMin;
  @override // obs left at this ratio * width
  double get xRatioObstacleMax;
  @override
  @JsonKey(ignore: true)
  _$$LabelResultImplCopyWith<_$LabelResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
