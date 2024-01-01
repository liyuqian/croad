# C Road -- see the road with a camera

Use a single smartphone camera to see:
1. $h$: the heading of the road
2. $d$: the distance that the vehicle can drive or see forward
3. $r$: the right-side distance that the vehicle can drift
4. $l$: the left-side distance that the vehicle can drift

Specifically:
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

Additionally, we also detect some camera parameters:
- $H_0$: the height of the horizon in pixels from the bottom center of the image
- $R_0$: the rotation of the horizon line in radian (0 means purely horizontal)

That is, the horizon line in the image should go through $(W / 2, H - H_0)$ of
the image with a tilt angle of $R_0$.

For $R_0$, smartphone sensors like accelerometers and gyroscopes could
provide direct readings.

The $H_0 and R_0$ have capital letters because they should be relatively
constant throughout the video. (Image width, height $W, H$ are also constants.)

In the future, we could also return a list of $(h_i, d_i, r_i, l_i)$ where the
$i$-th element corresponds to the road information at a given (constant) pixel
height $Y_i$. This allows us to express a curved road.
