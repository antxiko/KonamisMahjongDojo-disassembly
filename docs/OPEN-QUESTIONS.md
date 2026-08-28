# Open questions

The binary is 100 % explained: there is not a byte left unassigned nor a routine
left unnamed. What is left are **why** questions, and those the binary does not
answer on its own.

## Whether the machine's late riichi makes it harder or softer

The discard on which the machine declares riichi comes from a random draw plus 3,
5 or 7 depending on the difficulty, and that same number is what opens the door
for it to call at all. What it does is read, and that the three keys give three
different amounts is measured. Which way it pulls is not clear: declaring riichi
later means playing more turns without showing your hand, but it also means
letting go of hands it could have closed earlier. Settling that means playing
many games and counting them, not reading more code.

## What really separates the hand plans

Before every hand the machine picks a plan and keeps it in one byte. Which gates
each bit opens is read —go for a suit, allow the pon, allow the chi, do not
defend— and who decides it is read too, with its score and its honba. What is
not there is what each plan means in terms of difficulty: whether the one that
comes up when the machine is losing is more aggressive or just different.

## Whether the hand that pays zero can actually happen

The first row of both payment tables is 0000, and the 30 fu minimum that in
four-player riichi keeps you off it does not exist here. On paper, an open hand
made of runs, with a ryanmen wait, won by ron and with a single yaku, collects
zero plus the honba. It is **read and checked by hand, but not measured**: it has
not been seen happening in the emulator.

## How big the chip was

The cartridge ends at 0x9FE4 and behind it there are 8,219 bytes of 0xFF. That is
compatible with a 32 KB memory whose last bank was never programmed and with a
24 KB one the dumper read eight too many from, and from the dump the two are
identical. Only looking at a real cartridge settles it.

## Two decisions that look like oversights

In the south round, a hand with no winner **does not move the deal** even when
the dealer is not tenpai, which is the opposite of what it does in the east
round. And if the player wins with fewer than ten discards, a randomly drawn tile
overwrites the second-to-last slot of the machine's hand before it is turned
over. Both are read from the code; whether they are intent or oversight, it does
not say.

There is a third case like it: with four identical tiles in the sorted hand the
ron-tile flag is cleared, which changes the fu of that set. The what is clear,
the why is not.
