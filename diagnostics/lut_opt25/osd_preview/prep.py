import sys
from pathlib import Path
from PIL import Image
import numpy as np
png, out = sys.argv[1], sys.argv[2]
a = np.asarray(Image.open(png).convert('RGB'), np.uint32)
w = (a[:,:,0] << 16) | (a[:,:,1] << 8) | a[:,:,2]
Path(out).write_text(''.join(f'{v:06x}\n' for v in w.reshape(-1)), encoding='ascii')
