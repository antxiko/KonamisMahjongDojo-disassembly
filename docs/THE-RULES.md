# The rules

This cartridge plays a recognisable mahjong: Japanese riichi, with its calls,
its yaku, its fu and its payment table. But it is a **two-player** game, and
that forces decisions a four-seat table takes for granted. Every rule here
carries the address of the routine that makes it.

## The tiles

A tile is one byte: the suit in the high nibble and the number in the low one.
That gives 34 codes with gaps —0x01 to 0x09, 0x11 to 0x19, 0x21 to 0x29 and
0x31 to 0x37—, four copies of each, that is the 136 of a full set. The list is
at 0x4FBF and the inverse table, the one that returns an index from 0 to 33 with
no gaps, at 0x59B3.

| suit | what it is |
| ---: | --- |
| 0 | the **characters**, 一萬 to 九萬 |
| 1 | the **circles** |
| 2 | the **bamboos** |
| 3 | the seven **honours**, 東南西北白發中 in that order |

The bamboos identify themselves: the 緑一色 detector at 0x8118 only accepts
0x22, 0x23, 0x24, 0x26, 0x28 and the 0x36 dragon, which are exactly the green
bamboos. The other two show up on screen. The demo's freshly dealt hand —the one
in the picture on [The game](THE-GAME.html#the-table)— is
`02 06 08 08 09 · 11 13 15 17 · 22 22 · 31 31 33`, and what gets drawn is five
characters, four circles, two bamboos and three honours, in that order.

Putting the number in the low nibble is not a coding whim: it makes "the next
one in the run" a subtraction, and it means the honours, from 0x31 up, cannot
fit into any run by arithmetic alone. The hand engine leans on that constantly.

## There is no wall

The tiles of a game do not come from a shuffled run. **They are drawn one at a
time as they are needed**, and what stops a fifth copy coming out is a table of
thirty-four counters at 0xE186, one per type: if the draw picks a type with all
four copies spent, it is put back and drawn again (0x4F64, 0x4F2B). That is
rejection sampling without replacement, not a shuffle.

So there is no dead wall and no draw order either, and the end of a hand is
decided some other way: **the dealer gets 20 discards and the other 18** (0xE1C0
and 0xE1C1, set at 0x50DD). As soon as one of them runs past, the hand is
exhausted with no winner. From discard 18 on, riichi can no longer be declared.

## The calls

| call | what it needs | where |
| --- | --- | ---: |
| pon | two copies in hand and the opponent's last discard; not in riichi | 0x680B |
| chi | a run with the opponent's last discard, no honours | 0x692F |
| kan | three forms: with the opponent's discard, with four in hand, or adding the drawn tile to your own pon | 0x6C12 |

With two or three possible ways to chi, the player picks with left and right and
confirms with space. The closed kan is drawn with the two outer tiles face down,
and it ships with the rule most often forgotten: **in riichi, the closed kan is
only allowed if it does not change the waits**. 0x6E87 recomputes them, compares,
and undoes the kan if they do not match.

After a kan the next tile is the replacement, and it is flagged for 嶺上開花.
Every call bumps 0xE2B6, the call count: the hand stops being closed, and that
is what takes away the riichi, the pinfu and one han from several yaku.

## The riichi

It can be declared with a closed hand, right after drawing, not being in riichi
already and without having reached discard 18 (0x6653). It costs **1,000
points**, which go onto the table (0xE04A) as a stick. Declared on the first
discard it is a double riichi, and if the hand closes on the next discard there
is ippatsu.

And here there is a clear divergence: **only a winner who was in riichi takes
the stick from the table**. If the winner never declared it, the sticks stay on
the table for the next hand (0x5E70-0x5EA8). The one exception is player 1
winning the hand that ends the game, who takes them declared or not.

## Winning

A complete hand is four sets and a pair (0x6042), seven pairs (0x64F8) or
thirteen orphans (0x651D). Calling with an incomplete hand is refused with no
penalty. Calling **with no yaku** is a penalty: 12,000 points if the player is
dealing and 8,000 if not.

Furiten —waiting on a tile you have already discarded— is worked out by crossing
your waits with your own river and with whatever the opponent took from it. And
it is not treated the same across the three difficulties: on the first, a furiten
ron is simply refused; on the second and the third it is **punished** with those
same 12,000 or 8,000.

## The yaku

The detector at 0x7B3F runs through twenty-seven checks, and each one that fits
records the yaku with its han. The names live at 0x747B, in katakana, and the
pointer table that indexes them at 0x7642: **thirty-eight named yaku**, of which
the first eleven are yakuman. As soon as a yakuman turns up the list is cut and
the other yaku are not written.

The last tile of each name is the han of the **open** version, and 0x70BF
overwrites it with the closed value when the hand has no calls: one table serves
both cases.

Nearly everything matches four-player riichi, han included, with the open-hand
reductions —chinitsu 6 and 5, honitsu and junchan 3 and 2, ittsu, sanshoku and
chanta 2 and 1— and open tanyao allowed. What is **not** there: shousuushii,
chankan, nagashi mangan, aka-dora, kan-dora or double yakuman.

And what diverges, read from the code:

| yaku | what this cartridge does | where |
| --- | --- | ---: |
| pinfu | **only counts with ron**, never with tsumo | 0x7C99 |
| sanshoku doukou | worth **3 han**, not 2 | 0x7E1C |
| chuuren poutou | **only detected in suit 0** | 0x7F1A |
| chinroutou | **lets 東 through** as if it were a one | 0x8197 |
| renhou | recorded under the chiihou name, that is, as a yakuman | 0x82E3 |
| haitei with tsumo | worth 2 han **with the tsumo inside**, so it is not counted twice | 0x7C71 |
| seven pairs | worth its 2 han, but **without its 25 fu** | 0x7176 |

The seat wind is 東 for the dealer and 南 for the other player, and yakuhai gives
one han per triplet, two if the wind is a double one.

## The fu

They are counted as in four-player riichi: base 20, or 30 with a closed hand and
ron; a triplet 2 or 4 for simples and 4 or 8 for terminals and honours, open or
closed; a quad 8 and 16, or 16 and 32; a pair 2 if it is dragons or a wind that
counts and 4 if it is both winds; a wait 2 for kanchan, penchan or tanki; 2 more
for tsumo; and the total rounded up to the next ten. All of it in BCD, with
`daa`.

The exception is seven pairs, which instead of its fixed 25 fu is counted like
any other hand. And there is a detail in the pair: the non-dealer is credited
with 東 instead of their own 南, that is, the dealer's wind and not their own.

## The payment

Under 5 han the payment comes out of two tables of nine rows by four words each,
in BCD: the dealer's at 0x5CBB and the other player's at 0x5D03. The fu give the
row and the han the column, and the figures match the standard Japanese mahjong
table exactly: 30 fu and 2 han are 2,900 if the dealer wins and 2,000 if not.

From 5 han up there is no fu row any more, only limits: mangan 12,000 and 8,000,
haneman 18,000 and 12,000, baiman 24,000 and 16,000, sanbaiman 36,000 and
24,000, and 13 han is the ceiling —there is no kazoe yakuman—. A yakuman is
48,000 and 32,000, and they stack up to five. On top of all that go 300 points
per honba on a ron and 100 on a tsumo.

Two oddities in those tables:

- **20 fu with 1 han pays zero.** The first row of both tables is 0000, and since
  the 30 fu minimum for an open hand does not exist here, there is a hand —open,
  made of runs, ryanmen wait, won by ron— that is called and collects nothing
  beyond the honba.
- **From 100 fu up it pays as 8 han**, that is, baiman. Which is why the ninth
  row of the tables, which exists and is written out, is never read.

### The scores do not add up to 60,000, and that is by design

With tsumo, the cartridge takes the payment from other tables, the "on the draw"
ones, which are what **a single player** would pay at a four-seat table. But
0x5B85 loads the same word into both pending amounts and then only reduces the
one for the payer (0xE1B1), not the one for the collector (0xE1E4). The result:
the loser pays one player's share and the winner collects the full ron figure.

Points are created out of nothing, and the scoring screen shows it without
flinching: ハライ is what was paid and トクテン what was collected, and with
tsumo they differ. In the demo —7 han, 30 fu, tsumo by the dealer— 6,000 are
paid and 18,000 collected, and the scores end at 48,000 and 23,000.

## The game

The deal passes to the other player when the non-dealer wins; it stays if the
dealer wins or is tenpai in a hand with no winner. Every hand with no winner and
every hand the dealer wins bump the honba counter, which goes back to zero when
the deal changes.

From **5 honba** on it gets harder: 2 han of yaku, not counting dora, are needed
to win at all (*ryanhan shibari*), and to collect the tenpai payment of a hand
with no winner every wait has to be worth 3 han. Tenpai pays 1,500 from whoever
is not to whoever is; with both or with neither, nothing.

The scores can go below zero. The sign does not live inside the number, which is
unsigned BCD, but apart, in 0xE100, and it shows on screen: when drawing, 0x44E7
picks one tile or another according to that bit.
