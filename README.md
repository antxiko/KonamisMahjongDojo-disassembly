# Konami's Mahjong Dojo (Konami, MSX1) — commented disassembly

Konami's RC-707 cartridge, taken apart byte by byte. All 32,768 bytes are
accounted for and explained: no unjustified gaps, no "graphics blob", no guessed
table.

🌐 **[Read it as a website](https://antxiko.github.io/KonamisMahjongDojo-disassembly/)**

[README en español](README.es.md)

---

## What this is

麻雀道場 (*Mahjong Dōjō*) is a two-player mahjong: you against the computer,
30,000 points each, two rounds. This is its code, commented, with the tools to
rebuild it and check that what comes out is the original.

The cartridge maps 32 KB across pages 1 and 2 (0x4000-0xBFFF). The boot code
writes a `jp` into the `H.KEYI` hook and then gets out of the way: the main
program is an `ei / jr $` at 0x404F that does nothing at all for the rest of the
session.

## What is special about it

**The whole game runs inside the interrupt.** Not part of it — all of it. The
deal, the AI, the scoring, the screens: a fifteen-state machine (0xE000) with
its sub-mode (0xE001), dispatched every frame from the keyboard hook. The main
program never gets the machine back.

**The computer does not play mahjong.** Its thirteen tiles are fixed —0x78CE
writes them into the cartridge one tile away from completion— and it never discards
from its hand: the tile it throws is **drawn from the wall** (0x583C) and then
filtered so it looks like a human discard. On difficulties 2 and 3 the first
four are honours, the next four terminals, never one of its own waits, and never
its suit once it has a suit plan. Every rejected candidate goes back to the pile.
The empty slot you see in its face-down hand is theatre too (0x553C).

**The table's text lives in the gap inside the tiles.** Each tile is six
characters, two wide by three tall, and the rows straddle two thirds of the
screen — so the middle row of every tile is never drawn in the centre third.
The cartridge writes its labels in exactly those unused slots: of the 97
characters the status bar uses, 56 are the middle pair of some tile.

## Why you can believe this

`make` traces the flow, builds the listing and demands that assembling it give
back exactly the original:

```
  ensamblado : 32768 bytes  24cb5bda...188b9b40
  original   : 32768 bytes  24cb5bda...188b9b40
OK: reproducible byte a byte
```

A listing can reassemble perfectly and still be wrong —if artwork is read as
instructions the bytes do not change— so two more checks run: no range declared
as data may come out as code, and no entry point may fall inside one.

## The cartridge in numbers

| | |
|---|---|
| bytes of code | 15,432 (47.09 %) |
| bytes of data | 17,336 (52.91 %) |
| bytes unidentified | **0** |
| named labels | 1,091 |
| anchored comments | 2,320 (30.7 % of the lines) |
| routines under 10 % commented | **0 of 1,001** |
| explained data ranges | 89 |

## Some of what turned up

- **The same 8 is a state and a difficulty.** 0x418C writes 8 into 0xE000, and
  the `rra` two instructions later turns that same 8 into the 4 that goes into
  0xE040. State 8 never gets dispatched: the `jp` that follows lands on the
  routine that does `inc`, so it lives for a few instructions and becomes 9.
- **The dispatcher reads its own return address.** 0x408F starts with `pop hl`,
  which means the jump table sits **embedded right behind the `call`**. That is
  why no sixteenth state can be added: the table is glued to the state 0 code.
- **The riichi stick only goes to a winner who was in riichi**, one thousand at
  a time, and otherwise stays on the table for the next hand — which is not how
  four-player mahjong works. The single exception is player 1 winning the hand
  that closes the game (south, player 2 dealing). **Measured** by calling
  0x5E70 with the RAM set by hand and reading 0xE04A and both scores.
- **With a tsumo the loser pays one player's share but the winner collects the
  full ron figure** (0xE1B1 against 0xE1E4). That is why the two scores do not
  add up to 60,000, and it explains a reading that looked like a bug.
- **From 5 honba on, being tenpai needs each wait to be worth 3 han** (0x7B3B:
  `cp 3 / ccf`), counted from scratch and without dora. That diverges from
  everything documented about the variant.
- **A cartridge bug at 0x595C**: the branch that keeps the computer from
  throwing terminals returns on the `jr nz` after `cp 1` and never gets to look
  at the 9, so it rejects nothing.
- **The opponent's demo hand is written into the cartridge**, not dealt.
- **Sound number 0 cannot be asked for**: the table pointer is set two bytes
  early (0x9CA1) so that sound 1 lands on the first real entry.
- **The sound driver is not Athletic Land's.** Same house, same year, and the
  only thing the two share is the twelve-semitone table.
- **The demo does not play the same hand twice.** Two cold starts give identical
  traces, but two consecutive laps of the same power-on do not: dumping
  0xE000-0xE3FF at the scoring screen of both laps gives 72 differing bytes of
  1,024.
- **This cartridge does not carry Konami's hidden mark.** Other cartridges from
  the same house hide their catalogue number and title in katakana at the end of
  the ROM, a detail documented by Manuel Pazos; here the last 8,219 bytes are
  0xFF and nothing else.

## The loose end nobody can close from the binary

The cartridge ends with **8,219 bytes of 0xFF** (0x9FE5-0xBFFF) and no
instruction in it ever touches 0xA000-0xBFFF. Two explanations fit the same
file: a 32 KB chip with 8 KB never programmed, or a 24 KB chip whose dump read
past the end. Nothing in the code decides between them, so it is published as a
32 KB ROM —which is how it is played on an emulator and on a flashcart— and the
question is left open.

## Getting started

You need `pasmo`, `z80dasm` and Python 3. The cartridge image is **not**
distributed here: put your own in the root as `mahjong.rom`, 32768 bytes,
sha256 `24cb5bda5f55dcd5ab1343fb61ebac67e8c292f9714ee7a492431e33188b9b40`.

```sh
make          # trace, build the listing and check everything
make verify   # assemble and compare with the cartridge
make sanity   # what reassembly cannot catch
make test     # the tests on the listing
make densidad # how much of the listing is commented
```

## Licence and attribution

The game is not ours: *Konami's Mahjong Dojo* belongs to Konami, and all rights
remain with their holders. What is ours —the tools, the comments and the
documentation— is released under the licence in `LICENSE`. The cartridge image
is not distributed. See [LEGAL-NOTICE.md](LEGAL-NOTICE.md).
