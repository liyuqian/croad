# C Road -- see road with a camera

Use a single smart-phone camera to see:
1. The heading of the raod
2. The distance forward we can drive or see
3. The right-side distance we can drift
4. The left-side distance we can drift

They are represented by 4 numbers $(h, d, r, l)$.
- The $h$ is in radian where 0 means that the road is perfectly aligned with the
  camera's forward direction (y-axis of the camera image). Positive $h$ means
  that the road is rotated left, and negative $h$ means that the road is rotated
  right.
- The distances $d, r, l$ are in pixels. The measurement starts from the
  vehicle's front-center pixel $(x_0, y_0)$.  That is, the pixel $(x_0, y_0)$ in
  the camera image is the center of the vehicle, and the pixel $(x_0, y_0 - 1)$
  is the road ($y$-axis points downward so $y_0 - 1$ is one pixel upward).
- For basic models, $l$ could be 0 so we only detect the right-side distance.
- The trapezoid (projected rectangle) defined by $(h, d, r, l)$ in the camerage
  image should be free of any obstacles (cars, trucks, pedestrians, curbs) or
  lane boundaries we can't cross.
