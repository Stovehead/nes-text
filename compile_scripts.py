import png

charmap = "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわんをぁぃぅぇぉゃゅょっがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽゔアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワンヲァィゥェォャュョッガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポヴ。ー　"
seenkanji = set()

line = "あなたのチッチッチッちがみたいちゅうちゅうちゅうちゅうしたい"
output = bytearray()

for moji in line:
    if charmap.find(moji) == -1:
        seenkanji.add(moji)
        output.append(255)
    else:
        output.append(charmap.index(moji))

print(".byte ", end="")

for moji in output:
    print("$", end="")
    print("{:02X}".format(moji), end="")
    print(", ", end="")

print()

print(seenkanji)