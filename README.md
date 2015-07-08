D Byte Pusher
=============

An implementation of the [BytePusher](https://esolangs.org/wiki/BytePusher)
virtual machine, written in the D language and using the Derelict SDL 2 bindings.

Building
--------

```
dub build
```
On Windows you will need a 2.0.2 or 2.0.3 SDL2.dll inside bin/.

Usage
-----

You can start DBP from the command line, passing the path of a memory dump
(.BytePusher), but you can also run it directly by double-clicking it.

You can always access the main menu by pressing ESC. SPACE pauses and resumes
the execution.

DBP has a feature to automatically pause the execution once a HALT instruction
is reached (a JUMP to, and the PC pointing at the current adress). If you try
to resume the execution by pressing SPACE then the PC will be increased by one
instruction. It's useful for debugging, but may result in unexpected behaviour
too!

Command line flags
------------------

```
Usage:
dbp [flags] ... [PATH]

Optional arguments:
PATH                 The path to a BytePusher memory dump
--help, -h           Show this help
--noaudio, -n        Turn off audio output
--zoom=#, -z=#       Set the size of one pixel
--cfg="", -c=""      Load an alternative config file
--verbose, -v        Log important actions to stdout
--debug              Log every instruction (SLOOOOOOW)
--nohalt             Turn off pausing the emulator if a HALT is reached
```
