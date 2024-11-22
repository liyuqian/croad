// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'labeler.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LabelResultImpl _$$LabelResultImplFromJson(Map<String, dynamic> json) =>
    _$LabelResultImpl(
      imagePath: json['imagePath'] as String,
      xRatio: (json['xRatio'] as num).toDouble(),
      yRatio: (json['yRatio'] as num).toDouble(),
      leftRatio: (json['leftRatio'] as num).toDouble(),
      rightRatio: (json['rightRatio'] as num).toDouble(),
      yRatioObstacleMax: (json['yRatioObstacleMax'] as num).toDouble(),
      xRatioObstacleMin: (json['xRatioObstacleMin'] as num).toDouble(),
      xRatioObstacleMax: (json['xRatioObstacleMax'] as num).toDouble(),
    );

Map<String, dynamic> _$$LabelResultImplToJson(_$LabelResultImpl instance) =>
    <String, dynamic>{
      'imagePath': instance.imagePath,
      'xRatio': instance.xRatio,
      'yRatio': instance.yRatio,
      'leftRatio': instance.leftRatio,
      'rightRatio': instance.rightRatio,
      'yRatioObstacleMax': instance.yRatioObstacleMax,
      'xRatioObstacleMin': instance.xRatioObstacleMin,
      'xRatioObstacleMax': instance.xRatioObstacleMax,
    };
