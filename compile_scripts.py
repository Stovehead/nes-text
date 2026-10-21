import png

def png_to_binary(reader: png.Reader) -> bytearray:
    _, _, pixels, _ = reader.read()
    pixel_list = list(pixels)
    result = bytearray()
    for r in range(0, 2):
        for c in range(0, 2):
            for j in range(0, 8):
                byte = 0
                for k in range(0, 8):
                    color = pixel_list[r * 8 + j][c * 8 * 4 + k * 4 + 3]
                    bit = 0
                    if color != 0:
                        bit = 1
                    byte = byte | (bit << (7 - k))
                result.append(byte)
    return result

charmap = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわんをぁぃぅぇぉゃゅょっがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワンヲァィゥェォャュョッガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポヴ。ー　"
seenkanji = dict()

line = "私は自らの力で蘇るのではない。欲深な人間共によって蘇るのだ。"
output = bytearray()

for moji in line:
    if charmap.find(moji) == -1:
        if seenkanji.get(moji) == None:
            seenkanji[moji] = len(seenkanji)
        index = seenkanji[moji]
        output.append(index // 256 + 252)
        output.append(index % 256)
    else:
        output.append(charmap.index(moji))

print(".byte ", end="")

for moji in output:
    print("$", end="")
    print("{:02X}".format(moji), end="")
    print(", ", end="")

print()

banks = [open("kanjibank0.bin", "wb"), open("kanjibank1.bin", "wb"), open("kanjibank2.bin", "wb"), open("kanjibank3.bin", "wb")]

for kanji, i in seenkanji.items():
    banks[i // 256].write(png_to_binary(png.Reader(filename="kanji/" + kanji + ".png")))