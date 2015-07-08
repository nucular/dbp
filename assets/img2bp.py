"""
A simple converter from various image formats (to be precise, all that PIL can
read) to a BytePusher program.

by nucular, licensed under Creative Commons 0 (CC 0)
"""

import sys
try:
    from PIL import Image
except ImportError:
    from Pillow import Image

program = ""
pc = 0

def getColor(r, g, b, *args):
    """Get a matching palette index for a RGB color."""
    return (r * 6 / 256) * 36 + (g * 6 / 256) * 6 + (b * 6 / 256)

def write1(v):
    global program, pc
    program += chr(v & 255)
    pc += 1

def write2(v):
    write1(v>>8)
    write1(v)

def write3(v):
    write1(v>>16)
    write2(v)

def op(a, b, c):
    write3(a)
    write3(b)
    write3(c)

def main():
    global program, pc

    if len(sys.argv) < 3:
        print("Usage: %s INPUT OUTPUT" % sys.argv[0])
        return
    else:
        inp = sys.argv[1]
        out = sys.argv[2]

    print("Loading image.")
    try:
        img = Image.open(inp)
    except Exception as e:
        print("Unable to load image: %s" % e)
        return

    if img.size[0] < 256 or img.size[1] < 256:
        print("Image size has to be at least 256x256 px")
        return

    elif img.size != (256, 256):
        print("Image is larger than 256x256 px, using upper left area")

    print("Format: %s, Mode: %s" % (img.format, img.mode))

    if img.mode != "RGB":
        print("Converting to RGB")
        img.convert("RGB")

    print("Writing header")
    write2(0x0000) # Key table
    write3(0x000008) # Program counter
    write1(0x01) # Graphics location
    write2(0x0002) # Sound location
    op(0x000000, 0x000000, 0x000008) # Halt

    print("Writing blank space")
    program += "\0"*0xFFF8
    pc += 0xFFF8

    print("Writing image data")
    for y in range(0, 256):
        for x in range(0, 256):
            write1(getColor(*img.getpixel((x, y))))

    print("Trimming trailing zeros")
    while program[-1] == "\0":
        program = program[:-1]

    print("Writing file")
    with open(out, "wb") as stream:
        stream.write(program)

    print("Done!")


if __name__ == "__main__":
    main()