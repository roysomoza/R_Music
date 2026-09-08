import cv2
import numpy as np

# Load the image
img = cv2.imread('r_music_app_icon_v2.png', cv2.IMREAD_UNCHANGED)

# We want to find the dark rounded rectangles.
# Convert to grayscale
if img.shape[2] == 4:
    # If it has an alpha channel, create a mask of non-transparent pixels
    # Wait, the background is white.
    gray = cv2.cvtColor(img, cv2.COLOR_BGRA2GRAY)
else:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

# Threshold to find the dark boxes. The dark boxes are very dark (e.g. RGB around 10,10,10)
# We can just threshold for values < 50
_, thresh = cv2.threshold(gray, 50, 255, cv2.THRESH_BINARY_INV)

# Find contours
contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

# We want the 512x512 box which should be on the right side.
# Let's find all bounding rects
rects = [cv2.boundingRect(c) for c in contours]

# Filter out very small noise
rects = [r for r in rects if r[2] > 100 and r[3] > 100]

# We should have at least two large rects (the left one and right one).
# The one on the right has a larger X coordinate.
# Let's sort by X coordinate descending
rects.sort(key=lambda r: r[0], reverse=True)

# The first one in sorted (largest X) should be the right box
if len(rects) > 0:
    x, y, w, h = rects[0]
    # Crop the image to this bounding box
    cropped = img[y:y+h, x:x+w]
    cv2.imwrite('app_icon_cropped.png', cropped)
    print(f"Cropped right icon at {x}, {y} with size {w}x{h}")
else:
    print("Could not find any icons.")
