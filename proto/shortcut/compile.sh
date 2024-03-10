proto_path=$(dirname $0)/..
out_path=$proto_path/../roadart/lib/proto
plugin=--plugin=$HOME/.pub-cache/bin/protoc-gen-dart
set -x
protoc --dart_out=grpc:$out_path --proto_path $proto_path label.proto $plugin
