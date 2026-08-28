# The cartridge

It is **32 KB** taking up two pages of the MSX map, from 0x4000 to 0xBFFF, and
an MSX1 handles them comfortably: no megaROM, no bank switching, no extra sound
hardware.

## The sixteen bytes the BIOS reads

    4000:  41 42 10 40 00 00 00 00 00 00 00 00 00 00 00 00
           A  B  INIT=0x4010

The header declares `AB` and an INIT vector, and leaves the other three pointers
—STATEMENT, DEVICE and TEXT— at zero. The cartridge adds no BASIC statements and
does not declare itself as a device: it boots and takes the machine.

But the BIOS only maps **page 1** when it reads that header, so the top half of
the cartridge does not exist yet when INIT starts. The first thing 0x4010 does is
switch it on itself: it reads its own slot with `RSLREG`, keeps the two bits for
page 1 and calls `ENASLT` with H = 0x80, which is page 2. From that call on there
are 32 KB in sight.

The rest of the startup is short: it writes `jp 0x4071` into the interrupt hook
`H.KEYI` (0xFD9A), puts the stack at 0xE400, clears in one go the 1024 bytes from
0xE000 to 0xE3FF —which are every variable the game has—, sets up the PSG and the
VDP, and drops into a jump to itself it never leaves. The rest is in [The
code](THE-CODE.html).

## The VDP, with the two tables swapped

It is SCREEN 2 with 16×16 sprites, and the eight registers are loaded from the
list at 0x4A1A:

| table | where |
| --- | ---: |
| colours | 0x0000 |
| sprite patterns | 0x1800 |
| patterns | 0x2000 |
| names | 0x3800 |
| sprite attributes | 0x3B00 |

The striking part is the order: R3 = 0x7F and R4 = 0x07 put **the colours at the
bottom and the patterns on top**, exactly the other way round from what the usual
values give (0xFF and 0x03). It works just the same, but anyone reading a dump
assuming the usual layout will read one thing for the other.

There is another detail that throws you when reading the drawing lists: the VRAM
destinations they carry are sixteen bits and **fall outside video memory**, which
on an MSX1 is 16 KB. 0x7962 is not a bug: `SETWRT` swallows the top two bits and
writes to 0x3962, that is, row 11, column 2 of the name table. Every list in the
cartridge is written that way.

## The two drawing interpreters

Almost everything that reaches the screen is a list that goes through one of
these two.

**Format A** is read by 0x4099, and it is the simple one: two bytes of VRAM
destination and then the bytes as they are, with 0xFE for "another destination
follows" and 0xFF to finish. The clever part is that it has **two doors**:
entering at 0x409D the bytes pass through untouched and the list draws, and
entering at 0x4099 an `and c` with C = 0 turns them all into zero and the very
same list **erases**. There is no second table to switch off what was switched
on.

**Format B** is read by 0x468F, and it compresses: each order is a seven-bit
counter, and bit 7 says whether what follows is that many literal bytes or a
single byte to be repeated that many times. The font, the tile drawings and the
backgrounds all come up through it.

## The letters and the tiles

The tile numbers of the labels are **shifted ASCII**. The font at 0x83B1 is 48
patterns going to tiles 0xC0 through 0xEF: the ten digits, the copyright circle,
the hyphen and A to Z, so that a letter's tile is its ASCII plus 0x90. That is
why the cartridge's labels read in clear in a dump, with nothing to decode. The
same block is copied to the colour table and to the pattern table, so the
letters come out coloured.

A tile's drawing is **six consecutive tiles**, two wide by three tall, and the
table at 0x4735 gives the first of the six from the tile's code: one row per
suit, another for the honours, and all of them stepping down six at a time. In
the honours row there are two values that are not tiles: code 0x38 draws the
back and 0x39 the empty slot.

## The sound

The cartridge brings its own player, at 0x9C4A. You ask for a sound with its
number in A, and that number is also its **priority**: if the channel is already
carrying a higher one, the request is ignored. Below 0x8D they are effects and
all go to the same channel; above that they are music on three channels.

Each channel is eleven bytes of RAM —counter, duration, number, pointer, octave,
volume, repeat count— and the driver takes **one step per frame** from the
interrupt. A sound's orders are one byte each: 0x2n sets the duration, 0x1n sends
a noise to PSG register 6, 0xFE repeats and 0xFF ends; in an effect, the high
nibble is the volume and the next twelve bits the period.

The pitches come from twelve divisors at 0x9FD9, one per semitone, and the octave
is got by **doubling the period** as many times as the note's register says: the
more it doubles, the lower it sounds. There are 33 sounds in the pointer table at
0x9CA3, and thirty-one places in the cartridge ask for one.

## The last 8,219 bytes

From 0x9FE5 to 0xBFFF there are **8,219 bytes of 0xFF in a row**, and not one
instruction in the cartridge points there. The content ends at 0x9FE4,
twenty-seven bytes short of the 24 KB boundary, which means the program was
written to fit in 24.

What the binary does **not** say is which chip the cartridge carried, because
0xFF is what you get back from both an unprogrammed EPROM and an unconnected
bus. It could be a 32 KB memory with the last bank blank or a 24 KB one the
dumper read eight too many from, and from the dump the two are identical.

## The mark that is not there

Many Konami cartridges of this period hide their RC-7xx catalogue number and the
game's title in katakana at the end of the ROM; it was **Manuel Pazos**
([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)) who found that out.

This one does not carry it. In all 32768 bytes there is not one `RC-7` in ASCII,
nor the word `KONAMI`, nor anything resembling that signature: the last byte with
content belongs to the semitone table, and behind it there is only filler. The
RC-707 of this cartridge comes from the catalogue, not from the binary.
