import png

reader = png.Reader(filename='kana.png')
width, height, pixels, metadata = reader.read()
pixel_list = list(pixels)

with open("kana.bin", "wb") as output:
    bytes_left = 8192
    for i in range(0, len(pixel_list[0]), 16 * 4):
        for r in range(0, 2):
            for c in range(0, 2):
                for j in range(0, 8):
                    byte = 0
                    for k in range(0, 8):
                        color = pixel_list[r * 8 + j][i + c * 8 * 4 + k * 4 + 3]
                        bit = 0
                        if color != 0:
                            bit = 1
                        byte = byte | (bit << (7 - k))
                    output.write(bytearray([byte]))
                    bytes_left -= 1