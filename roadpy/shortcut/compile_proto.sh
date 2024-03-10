# `source shortcut/start_env` is required before this
out_path=./
python -m grpc_tools.protoc --python_out=$out_path --pyi_out=$out_path \
  --grpc_python_out=$out_path --proto_path ../ proto/label.proto