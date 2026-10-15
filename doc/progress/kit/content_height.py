# Prints the last non-white row of a PNG screenshot (the content height).
# Usage: python3 kit/content_height.py shot.png
import sys, zlib, struct
def rows(path):
    data = open(path, 'rb').read(); pos = 8; idat = b''
    while pos < len(data):
        n, typ = struct.unpack('>I4s', data[pos:pos + 8]); body = data[pos + 8:pos + 8 + n]; pos += 12 + n
        if typ == b'IHDR': w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
        elif typ == b'IDAT': idat += body
    bpp = {2: 3, 6: 4, 0: 1, 4: 2}[ctype]; stride = w * bpp; raw = zlib.decompress(idat); prev = bytearray(stride); i = 0
    for _ in range(h):
        f = raw[i]; line = bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line; yield line, bpp
last = 0
for y, (line, bpp) in enumerate(rows(sys.argv[1])):
    if any(line[x] < 245 for x in range(0, len(line), bpp)): last = y
print(last + 1)
