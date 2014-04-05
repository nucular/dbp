D Byte Pusher
=============

A little implementation of the BytePusher virtual machine, written in the D
language and using the Derelict SDL 2 bindings.

Building
--------

The build.bat script compiles DBP for Windows using the DMD compiler. You have
to pass the root folder of Derelict as the only argument.
Example: build.bat C:\D\dmd2\src\ext\derelict

It should also give you an idea on how to build DBP for other operating systems
and/or using other compilers.

Oh, and here's my setup:
- Derelict 3 <http://github.com/aldacron/Derelict3>
- DMD v2.061 (Phobos) <http://dlang.org/download.html>
- SDL 2.0.0 <http://libsdl.org/download-2.0.php>

Usage
-----

You can start DBP from the command line, passing the path of a memory dump
(.BytePusher), but you can also run it directly by double-clicking it.

You can always access the main menu by pressing ESC. SPACE pauses and resumes
the execution.

DBP has a feature to automatically pause the execution once a HALT instruction
is reached (a JUMP to, and the PC pointing at the current adress). If you try
to resume the execution by pressing SPACE then, the PC will be increased by one
instruction. It's useful for debugging, but may result in unexpected behaviour
too!

Command line flags
------------------

--help           Show the help text and exit

--noaudio, -n    Turn off audio, overriding that setting

--zoom=#, -z=#   Set the width and height of one pixel, overriding that setting,
                 must be >= 1 and <= 4

--cfg="", -c=""  Load an alternative config file

--verbose, -v    Log important actions to stdout, like pausing/unpausing,
                 full redrawing etc.

--debug          Log every single instruction to stdout, you should only use
                 this when debugging a small program ending with a HALT.

--nohalt         Disable pausing the execution when a HALT is reached, better
                 don't use this together with --debug

The Future
----------

I probably won't develop on this emulator that much since I'm planning to create
a full-fledged development/debugging environment for BytePusher with memory
introspection and more awesome things using wxWidgets.

Assets
------

These are some of the assets provided within this repo:

bg.xcf/bg.png:
    The default image that is shown when DBP is started without a passed
    program path. You need the Freeware Green Screen font from
    <http://fontspace.com/james-shield/green-screen>.

font.bmp:
    The pixel font that is used to draw the GUI. I consider it Public Domain
    since it's based on the well-known system font.

SDL2.dll:
    A Derelict-compatible DLL of SDL 2. It's under the zlib license.

License
-------

Unless otherwise noted inside the files or the "Assets" section above, the
following license applies for the provided files:

Copyright (C) 2014 nucular

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
