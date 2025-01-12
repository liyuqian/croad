# Video label management

Yaml file `data/train_videos.yaml` specifies a set of videos to generate the
labels for model training.
```yaml
videos:
  # Downloading videos may require authentications (e.g., Google drive).
  - url: https://...        # Where to download the video
    local_name: xyz1234.mp4 # Local name after downloading
    ranges:                 # Specify valid time ranges
      - begin_time: 00:00:00
        end_time: 00:01:00
      - begin_time: 00:02:00
        end_time: 00:04:00
  - url: https://...
    local_name: xyz1235.mp4
    ...
```

The tool `roadart/bin/videos_to_training.dart` will read that yaml and output
the training data (`tfrecords` for now, maybe `pt`, `hdf5` in the future).
The `videos_to_training.dart` will coordinate many scripts (e.g., `label.dart`,
`make_tfrecord.py`) to make the final training data.
```bash
  dart roadart/bin/videos_to_training.dart data/train_videos.yaml
```

# Links

Some links to the open-source 3rd party training data:
- https://github.com/commaai/comma10k
  - No restriction. MIT license.
- https://github.com/commaai/comma2k19
  - MIT license.
- https://registry.opendata.aws/
  - Search "driving".
- https://registry.opendata.aws/boreas/
  - https://creativecommons.org/licenses/by/4.0
- https://registry.opendata.aws/aev-a2d2/
  - https://creativecommons.org/licenses/by-nd/4.0
- https://waymo.com/open/data/perception/
  - Non-commercial use license. Research only.
- https://www.nuscenes.org/nuscenes
  - Non-commercial use license. Research only.
- https://www.cvlibs.net/datasets/kitti/
  - Non-commercial use license. Research only.

Some tools that might be useful:
- https://huggingface.co/facebook/detr-resnet-50
  - Detect objects (e.g., cars, trucks, pedestrians) offline
- [cv2.createLineSegmentDetector][1]
  - Detect curbs or boundaries
- https://github.com/duducosmos/defisheye
- https://github.com/Turoad/lanedet

[1]: https://docs.opencv.org/3.4/db/d73/classcv_1_1LineSegmentDetector.html
