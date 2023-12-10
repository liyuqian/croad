# C Road -- see the road with a camera

Use a single smart-phone camera to see:
1. The heading of the road
2. The distance that the vehicle can drive or see forward
3. The right-side distance that the vehicle can drift
4. The left-side distance that the vehicle can drift

They are represented by 4 numbers $(h, d, r, l)$.
- The $h$ is in radians where 0 means the road perfectly aligns with the
  camera's forward direction (y-axis of the camera image). Positive $h$ implies
  the road is rotated left, and negative $h$ means the road is rotated right.
- The distances $d, r, l$ are in pixels. The measurement starts from the
  bottom center image pixel $(W / 2, H)$ for the camera image with width $W$ and
  height $H$. Note that $l, r$ could be greater than $W / 2$ to extend the space
  to the invisible part of the image. Distances $l, r$ could also be negative,
  meaning that the vehicle should steer to avoid some obstacles.
- For basic models, $l$ could be 0, so we only detect the right-side distance.
- The trapezoid (projected rectangle) defined by $(h, d, r, l)$ in the camera
  image should be free of any obstacles (cars, trucks, pedestrians, curbs) or
  lane boundaries we can't cross.
