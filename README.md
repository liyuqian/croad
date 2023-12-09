# C Road -- see road with a camera

Use a single smart-phone camera to see:
1. The heading of the raod
2. The distance forward we can drive or see
3. The right-side distance we can drift
4. The left-side distance we can drift
5. The curvature of the road

They are represented by 5 numbers $(h, d, r, l, c)$.
- The $h$ is in radian where 0 means that the road is perfectly aligned with the
  camera's forward direction. Positive $h$ means that the road is rotated left,
  and negative $h$ means that the road is rotated right.
- The circular band with length $d$ and width $l + r$ is free of any obstacles
  (cars, trucks, pedestrians, curbs) or lane boundaries we can't cross.
- The curvature $c$ has a unit of $m^{-1}$. Its inverse is the circle's radius.
- For basic models, $l$ and $c$ are always 0 so we are only approximating the
  road with straight sections, and we only detect the right-side distance.
