SMS/GG rom header reader
====================

by Maxim

This program was originally designed as a reader for SDSC homebrew rom headers
in Sega 8-bit roms. However, it quickly grew the ability to also read the Sega
header and the Codemasters header.

To install:
---

Extract anywhere.


To uninstall:
---

Delete it, and its INI file.


To use:
---

1. Run the program.

2. Drag and drop a rom file onto the window.

Alternatively, you can drop a rom file onto the program file (or a shortcut to
it), but Windows may pass the short filename and that's what'll be displayed.


Some notes:
---

In random order and of varying usefulness.

It will read *any* file, so be careful. It will just report junk data if given
a non-rom, and I've added a 32KB size check.

512 byte headers (added before the rom data by the Super Magic Drive dumping
hardware) will cause incorrect data to be reported. You should use SMS Checker
to fix your roms.

The date is the "modified" date. I've found it often comes out as 1/1/80 though.

Dates are in your system's short date format, so you American types can have
m/d/y if you really must.

SDSC data is only read when "SDSC" is found at $7fe0.

http://www.smspower.org/dev/sdsc/ should have the SDSC header specification.

SDSC string offsets of $ffff are taken as meaning the string isn't there; any
other value and it'll try and read it. This is according to the specification,
but offsets outside the file and non-terminated strings will cause errors. The
exception is the author name, which will also ignore an offset of $0000, since
that's what pre-1.01 tags should use in that offset.

You can put line breaks in your SDSC release notes by putting in LF ($0A) or
CR ($0C) bytes. I've only tested it with LFs only, though; let me know if CRs
don't work!

Long strings cause nasty errors in the underlying common control treeview,
which is why I've made the release notes appear in a scrolling box. If you give
your program a very long title (more than 100 chars, say) in the SDSC header
then you'll cause this error.

SDSC release notes will appear in a scrolling box at the bottom of the window.
When you resize a window with this visible it is a bit counter-intuitive, as
the treeview resizes when you resize the window and the text box resizes when
you move the splitter bar. I tried to fix that but it was too buggy.

There's such variation in what's given in the Sega header, the whole thing is
shown in ASCII and hex so you can see what's there. The ASCII line substitutes
"." for values less than $20.

It used to support extracting zipped roms but I decided I don't like that; so
now it doesn't any more. (It was less work to remove it than to update it.)
Modern zip tools allow you to drag-and-drop files from their windows onto this
program, and they will extract to a temporary directory for you.


How the Sega header works
---

The Sega header is stored at offset $7ff0 in all known roms, although BIOSes
look for it at $3ff0 and $1ff0 too.

Let's look at Wonder Boy III:

```
Offset $7ff0:           54 4D 52 20 53 45 47 41 20 20 E2 16 26 70 00 40
                        || || || || || || || || || || || || || || || ||
1. "TMR SEGA" ----------''-''-''-''-''-''-''-'' || || || || || || || ||
2. Unknown word --------------------------------''-'' || || || || || ||
3. Checksum ($16E2) ----------------------------------''-'' || || || ||
4. Product code (7062) -------------------------------------''-''-'| ||
5. Version (0) ----------------------------------------------------' ||
6. Region (4) -------------------------------------------------------'|
7. Checksum range (0) ------------------------------------------------'
```
1. TMR SEGA

   8 byte string @ $7ff0

   The export SMS BIOS requires this string. Japanese systems and the GG don't.

2. Unknown word

   2 bytes @ $7ff8

   Looks like it was reserved but never used. It's often $0000, $2020 or $FFFF, all
   of which are "nothing" values, $20 being ASCII space.

   There might be a pattern in GG games - there seems to be a sequence counting up
   from 0000 to 0141, without much repetition (except at low values) or large gaps.
   
3. Checksum

   Word @ $7ffa

   Checksumming is done by summing the bytes in the given range (see 7. Checksum
   range), starting with 0 or the previous value when checksumming over more than
   one range. The result is held in a word (two byte variable), so $FFFF+$01=$0000.
   It's stored in Intel byte order, as the Z80 is little-endian, so $16E2 is stored
   as E2 16.

   The export SMS BIOS requires a valid checksum.

   The Game Gear BIOS does not check the checksum; nor does the Japanese SMS BIOS.
   Games only expected to play on these systems tend not to have valid checksums in
   their headers.

   1. Sega checksum for Codemasters games

      The checksumming in a real SMS depends on the use of the Sega mapper. Since the
      Codemasters games don't use that mapper, the checksum routine thinks it is
      checking every byte of the rom when it's really only checking the first 32KB.

      This paragraph is just for your entertainment, and isn't particularly important.
I spent many hours trying to figure out exactly which pages of Codemasters
cartridges are checksummed when the BIOS tries and fails to page in the whole
ROM. After trying 10 or so combinations I decided to use a brute-force method.
After running that for about an hour I calculated that it would take about 60
years to complete, so I gave up on that. I spent another few hours trying to
speed up this brute-force approach by filtering out unlikely and identical
values (identical values because being a summation, the order in which pages
are checksummed is irrelevant). However, it wasn't getting any faster. Then I
built a program which would let me interactively try different page
combinations. The default value for each section was page 0, and it wouldn't
update until I changed one setting. So I changed the first one to page 1... and
that was the correct answer. Yes, all that hard work and it happened to be the
first value I tried.

      So, the pages which are actually checksummed when the BIOS tries to checksum a
256KB-checksum-range Codemasters cartridge are:

      - Page 0 ($0000 to $3FFF) x 15
      - Page 1 (minus Sega header - $4000 to $7FEF) x 1

      In other words, the Codemasters mapper (which uses writes to $0000, $4000 and
$8000 instead of $fffd, $fffe and $ffff for much the same effect, except without
maintaining the first 1024 bytes) returns page 0 when bank 2 is read, before any
valid paging is done; and the BIOS uses bank 2 for paging when trying to read
above 32KB when calculating the checksum.

4. Product code

   2.5 bytes @ $7ffc

   It's a BCD big-endian word stored at $7ffc, plus the high nibble of $7ffe
which is not BCD. So, a product word stored as 12 34 5 decodes to 53412, and 78
90 A to 109078.

   1. Master System

      For SMS games, the last four digits are in these ranges:
      
      |Range |Meaning |
      |------|--------|
      |0500-0599  |Japanese C-5xx |
      |1300-1399  |Japanese G-13xx
      |3901       |Parker Borthers - their game codes are actually 43x0 but two have this number internally and the third has 0000.
      |4001-4084  |The Sega Card
      |4501-4584  |The Sega Cartridge
      |5051-5123  |The Mega Cartridge
      |5500-5501  |The Mega Plus Cartridge
      |6001-6003  (and 5044) |The Combo Cartridge
      |7001-7124  |The Two-Mega Cartridge
      |7500-7506  |The Two-Mega Plus Cartridge
      |8001-8008  |The 3-Dimensional Mega Cartridge - some of which are two-mega carts :)
      |9001-9035  |The Four-Mega Cartridge
      |9500-9501  |The Four-Mega Plus Cartridge

      3rd-party releases have a five-digit product number starting with 2, with the
last four digits following the above pattern. They have 2 stored in the high
nibble of the version byte. Note that there is overlap between the numbers - for
example, Populous = 27014 and California Games = 7014, both have 7014 in their
product word fields.

      A lot of games don't bother to store this code at all, 0000 being most common
value to put there instead.

      It is important not to take the rom's product code as absolutely correct - there
are a lot of games where it's just plain wrong (although often, it's only
slightly different to the correct one). Some store it backwards, some store it 
in hex instead of BCD, some (eg. GG Jeopardy!) have completely wrong values and 
some defy any explanation.

   2. Game Gear

      All but the last three digits are used to signify the licensee, ie. the company
credited with the copyright in the game and which was licensed by Sega to
develop for the Game Gear.

      For 03 Sega games, the final three digits follow this pattern:
   
      |Value | Size
      |------|-----
      |1xx      |32KB
      |2xx      |128KB
      |3xx, 4xx |256KB+

      03 Sega games get a prefix of G- (apparently following the scheme used for SG
and SMS cartridge games). Non-Sega games get a T- prefix (perhaps signifying
"Third-party"?).

      3rd party games seem to have either 7 or 8 as the final digit. Games with a
Japan country code always have 7; games with an International country code
always have 8; Export games have either. There are a few exceptions, none of
which comply with the normal patterns.

      The remaining two digits generally seem to count up from 01, in BCD. Not many
companies got past 01 or 02 though.

5. Version

   Low nibble of $7ffe

   Generally 0, for a few games where an alternate version exists this is generally
incremented by 1 for the newer version.

6. Country code

   High nibble of $7fff

   I lifted the country code definitions from Bock's checksummer, since it's based
on official Sega information... :)

   |Value | System/region
   |------|--------------
   |   $3 |   SMS Japan
   |   $4 |   SMS Export
   |   $5 |   GG Japan
   |   $6 |   GG Export
   |   $7 |   GG International

   As usual, some games don't have it (eg. GG Madden '96), or have the wrong value
(eg. GG Tesserae). If it's a GG code then the program won't check the checksum.

   The export SMS BIOS requires a value of $4. All other BIOSes do not check the
region.

7. Checksum range

   Low nibble of $7fff

   This specifies what ranges of the rom to include in the checksum. The following
values are recognised by the US SMS BIOS version 1.3:

   |Value | Rom size | Range 1 | Range 2        | Comment
   |------|----------|---------|----------------|------
   |$a |       8KB | 0-$1ff0 | -             | Unused
   |$b |      16KB | 0-$3ff0 | -             | Unused
   |$c |      32KB | 0-$7ff0 | - |
   |$d |      48KB | 0-$bff0 | -             | Unused
   |$e |      64KB | 0-$7ff0 | $8000-$10000  | Rarely used
   |$f |     128KB | 0-$7ff0 | $8000-$20000 |
   |$0 |     256KB | 0-$7ff0 | $8000-$40000 |
   |$1 |     512KB | 0-$7ff0 | $8000-$80000  | Rarely used
   |$2 |       1MB | 0-$7ff0 | $8000-$100000 | Unused

   The unused ranges may not be acceptable to later BIOS revisions. Since the 48KB
range will include the header, care must be taken to cancel the effect of adding
the correct checksum to the header, since this will affect the resultant
checksum.

   I've never seen any nibbles other than 0, 1, C, E and F (except in japanese SMS
roms with bad headers (eg. SMS Rygar), and in GG The Pro Yakyuu '91). In Bock's
checksummer, he has a whole range of values, notably with E = 64KB, but the one
E SMS rom I know (Great Ice Hockey) wants a 128KB range, and the only E GG rom
(Battleship) is 64KB... As far as I know, range 1 is only used in the European
release of  Chuck Rock II.

   The range nibble is reported as "Checksummed rom size".


How the Codemasters header works
---

Offset | Type | Meaning
-------|------|-----
$7FE0 |  Byte | Number of rom pages over which to calculate the checksum
$7FE1 |  Byte | Day
$7FE2 |  Byte | Month
$7FE3 |  Byte | Year
$7FE4 |  Byte | Hour (24 hour clock)
$7FE5 |  Byte | Minute
$7FE6 |  Word | Checksum
$7FE8 |  Word | $10000 - checksum

$7FEA-$7FEF are all zero.

$7FE0 is $10 for a 256KB rom and $20 for a 512KB rom.

The date and time bytes are BCD. For Cosmic Spacehead they are
31 08 93 10 59
for 31st August, 1993, 10:59 am.

The checksum is found by summing words over the entire file to a 16-bit
accumulator, except for the Sega header at $7ff0 to $7fff. The checksum word and
the word after it sum to zero, allowing the checksum to be added to the file
without changing the value that will be calculated.


More stuff
---

The source is for Delphi 7. It's a bit messy but I've tried
to comment it up.

I modified it for batch processing, for my personal use (it was a terrible
kludge). The results are available on my website.


Dedication
---

For Michelle.

