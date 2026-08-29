# Legal notice and attribution

*(También disponible [en castellano](AVISO-LEGAL.md).)*

## Who owns what

**The game is not ours.** *Konami's Mahjong Dojo* was published by **Konami** as the
RC-707 cartridge for the MSX; the cartridge itself signs «© Konami 1984». All rights over the game remain with their
holders.

**What is ours** are this repository's tools, the comments in the listing, the
analysis and the documentation. That is published under the licence in
`LICENSE`.

## What is in this repository

The file `src/mahjong.asm` is the commented disassembly of the cartridge. It
is published for the **preservation, study and documentation** of a title
that is part of MSX software history.

The cartridge image (`.rom`) is **not** distributed here. Anyone who wants to
rebuild the listing has to supply their own, and the `Makefile` checks its
sha256 before doing anything.

The screenshots in this repository are not stray photographs: `make capturas`
boots the cartridge in openMSX with `renderer none`, dumps video memory at fixed
instants and builds the PNG from the dump, without pressing a single key. That
is why they always come out the same and anyone can reproduce them.

## What it rests on

Nobody else's work. Everything stated here comes from reading this binary, and
each claim carries its evidence next to it: the instruction that reads a datum,
the table that ends exactly where it has to end, or the arithmetic that works
out. What is not settled is said not to be.

## If you are one of the authors

If you worked on *Konami's Mahjong Dojo* or hold rights over the game, and you would
rather this material were not published, **say so and it comes down, no
argument**. The intent of this work is the opposite of harming you: it is to
put on record how it was made.
