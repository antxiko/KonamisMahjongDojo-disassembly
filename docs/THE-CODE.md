# The code

Of the cartridge's 32768 bytes, **15,432 are code and 17,336 are data**. Not one
is left unassigned.

## The whole game runs inside the interrupt

When INIT has finished setting the machine up, it does not call any main loop:
it reaches 0x404F, which is a `jr` to itself, and stays there forever. Everything
else hangs off the `H.KEYI` hook it has just installed.

    404F:  jr 404Fh

The interrupt routine does three things in order. It acknowledges the VDP, it
moves the sound —always, whatever happens—, and then it looks at the semaphore at
0xE005: if the previous frame is still inside, it leaves without more ado; if
not, it raises it, reopens interrupts, reads the controls and gives the state
machine one beat. That semaphore is the only thing keeping a long frame from
overlapping the next one.

So a frame of this game is a call, not a turn of a loop, and all the state has to
live outside the stack. Hence the kilobyte from 0xE000 to 0xE3FF full of
counters, cursors and flags.

## The dispatcher that reads itself

The fifteen states and their steps are dispatched by this routine, and it is not
the usual one:

    408F:  add a,a          ; each entry is two bytes
    4090:  pop hl           ; the RETURN address is the table
    4091:  call 4063h       ; HL += A
    4094:  ld e,(hl)
    4095:  inc hl
    4096:  ld d,(hl)
    4097:  ex de,hl
    4098:  jp (hl)          ; and jump: there is no coming back here

The `pop hl` keeps the return address and uses it as the base of the table, which
means **the table sits right behind the `call`** that invokes the dispatcher. It
saves the `ld hl,table` on every call, and in exchange whichever handler comes
out inherits as its return address whatever lay under the table.

There are five tables written that way, and between them they are the whole
skeleton of the game: fifteen words for the states at 0x40ED, and two, two, nine
and four for the steps of states 7, 10, 11 and 12.

For a disassembly this is a problem twice over: the `jp (hl)` cuts the trace, and
the bytes behind each `call` are data in the middle of the code. The thirty-two
destinations are declared by hand in the `.entries` and the five ranges in the
`.nocode`, each with its justification written alongside.

## One set of variables for both players

The call menu, the hand engine and the yaku detector do not know whose turn it
is. They always work on the same addresses, and what happens before and after is
a copy: 0x517A brings into those shared variables the ones belonging to whoever
is playing —cursor, drawn-tile slot, last slot, tsumo flag, riichi and waits—
and 0x51BC puts them back.

It is the reason the machine can call pon or chi going **through the very same
menu dispatcher** a person does: its variables are loaded, the call bit is set,
and in it goes the way a player would.

## The hand engine

Deciding whether a hand is complete is the largest thing in the cartridge
(0x5F3E-0x656D), and it is not a table nor a generic search: it is a **hand-written
tree of cases** over the already sorted hand. At each step it looks at the tile
under the cursor and the three or four after it, and off what it finds —equal,
consecutive, loose— hangs a different branch. What it finds it records in four
lists: runs, triplets, quads and the pair, each set with a flag saying whether it
is open.

When a branch does not work out there is backtracking, but **it is not
recursive**: a copy of the hand and of the sets is saved into one of two slots,
with one byte saying how many copies there are and another which branch to try on
restoring. Two levels and not one more. If they run out, the hand is declared
undecomposable.

On top of that engine runs the yaku detector at 0x7B3F: **twenty-seven checks**
that read what the four lists left behind and record every yaku that fits with
its han.

And all of it leans on how a tile is encoded. The number goes in the low nibble,
so "the next one in the run" is a subtraction giving 0xFF, and the honours,
starting at 0x31, cannot fit into any run without anyone having to check.

## How it was done, and why you can trust it

The listing is not written by hand. `tools/z80trace.py` follows the real flow
from the declared entry points, `tools/mkasm.py` builds the `.asm` with the
address-anchored annotations, and the numbers come out of that.

`make verify` reassembles and compares against the original ROM: it has to come
out **identical byte for byte**, and it does. But that alone is not enough,
because data read as code gives the same binary —the bytes do not change, what
changes is what is said about them—, so `make sanity` also checks that no range
declared as data shows up as an instruction, that no entry point falls inside a
data area, and that not one of the 32768 bytes is left unassigned.

On top of that there are two more measures. `make notas` catches the two
mistakes that get lost in silence when annotating: a comment anchored to an
address that is not an instruction, and two comments for the same one. And
`tools/densidad.py` measures, routine by routine, how many instructions carry a
comment:

| | |
| --- | ---: |
| labelled code blocks | 1,001 |
| of those, with a name of their own | 340 |
| data blocks, with their name and row width | 89 |
| instructions | 7,548 |
| instructions with a comment | 2,320 (**30.7 %**) |
| routines under 10 % commented | **0** |

That last row is the one that matters: a routine with a name but not a single
comment is christened, not explained, and there is none of those left here.
