import sys
import numpy as np
from PIL import Image
v = np.array([int(l, 16) for l in open(sys.argv[1]).read().split()], np.uint32).reshape(480, 640)
Image.fromarray(np.stack([(v >> 16) & 255, (v >> 8) & 255, v & 255], -1).astype(np.uint8)).save(sys.argv[2])
