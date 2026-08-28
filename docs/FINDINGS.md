# Findings

Things that turned up while taking the cartridge apart and that do not fit on
any other page. Each one says where it comes from.

## The same 8 is both a state and a difficulty

When the demo starts, the cartridge writes an 8 into the state byte. That 8 never
gets dispatched —the next instruction goes through the routine that does `inc`,
so the state that runs is 9— and yet the 8 is written. The reason is three
instructions further down:

    418C:  ld a,008h
    418E:  ld (0E000h),a    ; the state... which will turn into 9
    418F:  rra              ; the same 8, rotated: out comes a 4
    4190:  ld (0E040h),a    ; and that 4 is THE DIFFICULTY

One byte serving two things that have nothing to do with each other, and as a
side effect it leaves the demo playing **on the middle difficulty**. You can see
it in memory —0xE040 is 4 for the whole cycle— and you can see it on screen,
because the top bar labels it: in the demo it reads セミプロ, and a game started
with key 1 reads アマ in the same place.

That is also the only way to reach state 8 for real, the difficulty screen: by
writing the 8 from the keyboard reader, which is somewhere else and does not go
through the `inc`. Which is why the demo never sees it.

## Four filler bytes for a round address

INIT writes the interrupt hook's jump by hand: `ld a,0C3h`, the address, and off
to `H.KEYI`. The address it writes is 0x4071, and the code before it ends with a
`ret` at 0x406C. The four spare bytes, 0x406D to 0x4070, are filled with 0xFF:
not rubbish and not assembler leftovers, they are there so the interrupt routine
starts exactly where INIT says it starts.

## The table's text lives in the gap inside the tiles

The playing screen is practically full: the 256 tiles of each third barely cover
the tile drawings, which spend six tiles each.

But the rows of tiles always fall **across two thirds**, and that leaves a gap.
In the middle third you only ever see the bottom row of the tiles above and the
top row of the tiles below: **the middle row of each tile is never drawn there**.
And that is where the text is tucked in.

Crossing the tile table with the name tables of 124 video memory dumps, of the 97
tiles the central bar uses **56 are exactly the middle pair of some tile**: the
東 is the two spare pairs from the tiles starting at 0xA6 and 0xAC, the 局 those
of the ones at 0xCA and 0xD0, and the whole call menu comes out of the gaps in
four more tiles. The other 41 are tiles of its own.

So the same tile number is half a mahjong tile in one third and a kanji in
another, without either getting in the way.

## The deal carries a real mahjong rule inside it

The deal animation goes in batches, and what decides how many tiles each batch
holds is 0x4E59: if the dealt counter is already 12, the next batch is **one**;
otherwise it is **four**. Four, four, four and one: thirteen, which is exactly
how a hand is dealt in Japanese mahjong.

It is not a drawing detail. The loop does not end until the counter reaches
thirteen.

## The opponent's demo hand is written into the cartridge

In a real game the machine's hand is built tile by tile. In the demo it is not:
0x78DD copies fourteen bytes from 0x7AEA and that is the whole deal on that side.

And that hand is a joke for anyone who knows how to look at it. The fourteen
bytes are `32 39 08 08 17 17 25 25 33 33 13 13 21 21`: **six pairs, a lone 南 and
a gap**, that is, seven pairs one 南 short —a chiitoitsu one tile away—. By the
time the scoring comes up, the opponent's memory has it sorted and it is still
the same: `08 08 13 13 17 17 21 21 25 25 32 33 33 39`.

It never completes it. The script is written so that the other side wins.

## Sound number 0 cannot be asked for

The sound pointer table starts at 0x9CA3, but the code indexes it from
**0x9CA1**, two bytes earlier, so that sound 1 lands on the first real entry.
That leaves entry 0 sitting on the end of the routine just above: 0x9CA1 is the
displacement of a `djnz` and 0x9CA2 the `ret` that follows it, so the "pointer"
for sound 0 is the bytes 0xE8 and 0xC9. Asking for it would mean jumping to
0xC9E8, outside the cartridge.

It never happens, because nobody asks for it. And at the other end of the table,
sounds 31, 32 and 33 all point to the same place.

## A lone `ret` that three places call

At 0x9EA2, inside the sound player, there is a single byte: a `ret`. Three
different places in the driver call it. Whatever used to be there was taken out
at some point and the calls stayed behind.

## A compressed block with its header missing

The compressed-drawing interpreter starts by reading two bytes with the VRAM
destination. The call menu's patterns do not carry them: 0x4B5B puts the
destination into DE by hand and enters the interpreter **three bytes further
in**, skipping precisely the two instructions that would read it.

And right behind it is the counterpart: instead of compressing the colours of
those 208 bytes as well, the same stretch of the colour table is filled with a
fixed byte, repeated 208 times. Same size, same place, one byte of data instead
of a block.
