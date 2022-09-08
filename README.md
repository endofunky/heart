# <3

A 1014 byte polyglot binary.

This file is a:

- Linux ELF64 executable
- MS-DOS .COM executable
- Nintentdo GameBoy ROM
- SEGA MegaDrive/Genesis ROM
- PDF Document
- ARJ Archive
- PKZIP Archive
- 7zip Archive

View the Assembly source code in full Technicolor™ here: [https://xoreaxeax.com/b/heart/](https://xoreaxeax.com/b/heart/)

## Build

The binary can be built with [NASM](https://www.nasm.us/):

    $ nasm -f bin -o heart heart.asm
    $ chmod +x heart

Or with the included `Makefile`:

    $ make

## SHA256

```
$ sha256sum ./heart

5ba765b83602e00c9abed097a4a542860b6ca0b234808f19e0524ac3235e8437  ./heart
```
