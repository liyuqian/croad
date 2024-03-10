root_path=$(dirname $0)/../..
dart_out_path=$root_path/roadart/lib
dart_plugin=--plugin=$HOME/.pub-cache/bin/protoc-gen-dart
py_path=$root_path/roadpy
set -x

protoc --dart_out=grpc:$dart_out_path --proto_path $root_path proto/label.proto $dart_plugin

$py_path/environment/bin/python -m grpc_tools.protoc --python_out=$py_path \
  --pyi_out=$py_path --grpc_python_out=$py_path --proto_path $root_path proto/label.proto
