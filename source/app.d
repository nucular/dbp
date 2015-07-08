
// cd .. && dub build
/*
DBP - BytePusher VM written in D using the Derelict SDL 2 bindings
by nucular

TODO:
- Better delay / frameskip calculation
- Circular audio buffer
*/

import std.stdio;
import std.file;
import std.array;
import std.conv;
import std.string;
import std.getopt;
import std.datetime;

import std.c.process;

import derelict.sdl2.sdl;

// Default configuration
int cycles = 0xA0000;
int zoom = 2;
bool audio = true;
bool debg = false;
int fps = 60;
ushort buffersize = 2048;
bool nohalt = false;

// Keymap
int k0 = SDL_SCANCODE_X;
int k1 = SDL_SCANCODE_1;
int k2 = SDL_SCANCODE_2;
int k3 = SDL_SCANCODE_3;
int k4 = SDL_SCANCODE_Q;
int k5 = SDL_SCANCODE_W;
int k6 = SDL_SCANCODE_E;
int k7 = SDL_SCANCODE_A;
int k8 = SDL_SCANCODE_S;
int k9 = SDL_SCANCODE_D;
int kA = SDL_SCANCODE_Y;
int kB = SDL_SCANCODE_C;
int kC = SDL_SCANCODE_4;
int kD = SDL_SCANCODE_R;
int kE = SDL_SCANCODE_F;
int kF = SDL_SCANCODE_V;

// Globals
SDL_Event event;
bool running = true;
bool verbose = false;
string cfgpath = "dbp.cfg";
string dbppath;

Core core;
Machine machine;
Screen scr;
Interface gui;

int[16] keymap;
bool[16] keystates;

__gshared Uint8[] audioBuffer;


// Our audio callback
extern(C) nothrow void audioCallback(void* userdata, Uint8* stream, int len)
{
    if (audioBuffer.length >= len)
    {
        for (int i = 0; audioBuffer.length > 0 && i < len; i++)
        {
            *stream++ = audioBuffer[0];
            audioBuffer.popFront();
        }
    }
    else
    {
        for (int i = 0; i < len; i++)
        {
            *stream++ = 0;
        }
    }
}


// Log something if the verbose flag is given
void log(lazy string s)
{
    if (verbose)
        writefln("[%s] %s", Clock.currTime().toString(), s());
}

// Transform a char as if SHIFT was pressed on a QWERTY keyboard
string toUpper(char c)
{
    switch (c)
    {
        case '7':
            return "/";
        case '.':
            return ":";
        case '-':
            return "_";
        default:
            return std.string.toUpper(cast(string)[c]);
    }
}

// Helper to get the path of a file beneath the DBP executable
string getPath(string file)
{
    return std.path.buildPath(dbppath, file);
}

// Helper to check if a string contains a specific char
bool contains(string s, char c)
{
    foreach (char i; s)
    {
        if (i == c)
            return true;
    }
    return false;
}

// Helper to get the name of a key from a scancode
string getKeyName(int scancode)
{
    return to!string(SDL_GetScancodeName(scancode));
}

// Helper to change a key bind
void changeKeyBind(int n, int scancode)
{
    switch (n)
    {
        case 0:
            k0 = scancode; break;
        case 1:
            k1 = scancode; break;
        case 2:
            k2 = scancode; break;
        case 3:
            k3 = scancode; break;
        case 4:
            k4 = scancode; break;
        case 5:
            k5 = scancode; break;
        case 6:
            k6 = scancode; break;
        case 7:
            k7 = scancode; break;
        case 8:
            k8 = scancode; break;
        case 9:
            k9 = scancode; break;
        case 0xA:
            kA = scancode; break;
        case 0xB:
            kB = scancode; break;
        case 0xC:
            kC = scancode; break;
        case 0xD:
            kD = scancode; break;
        case 0xE:
            kE = scancode; break;
        case 0xF:
            kF = scancode; break;
        default:
            break;
    }

    keymap = [kF,kE,kD,kC,kB,kA,k9,k8,k7,k6,k5,k4,k3,k2,k1,k0];
    keystates = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

    log(format("Bound key %X to %s", n, getKeyName(scancode)));
}

// A fast and dirty configuration format
void loadConfig()
{
    int[] cfg;

    if (cfgpath.exists())
    {
        log(format("Loading configuration from %s", cfgpath));
        cfg = cast(int[])read(cfgpath);

        audio = cast(bool)cfg[0];
        zoom = cfg[1];
        k0 = cfg[2];
        k1 = cfg[3];
        k2 = cfg[4];
        k3 = cfg[5];
        k4 = cfg[6];
        k5 = cfg[7];
        k6 = cfg[8];
        k7 = cfg[9];
        k8 = cfg[10];
        k9 = cfg[11];
        kA = cfg[12];
        kB = cfg[13];
        kC = cfg[14];
        kD = cfg[15];
        kE = cfg[16];
        kF = cfg[17];
        keymap = [kF,kE,kD,kC,kB,kA,k9,k8,k7,k6,k5,k4,k3,k2,k1,k0];
    }
    else
        log(format("Config file %s doesn't exist", cfgpath));
}

void saveConfig()
{
    int[] cfg = [
        cast(int)audio,
        zoom,
        k0,k1,k2,k3,k4,k5,k6,k7,k8,k9,kA,kB,kC,kD,kE,kF];
    std.file.write(cfgpath, cfg);
    log(format("Configuration written to %s", cfgpath));
}


// The 3-byte ByteByteJump core
class Core
{
    ubyte[] mem;
    bool paused;
    bool washalted;

    void initialize()
    {
        log("Allocating core memory");
        this.mem = new ubyte[](0x100000F);
    }

    void setKeys(bool[16] states)
    {
        ubyte a, b;

        for (int i = 0; i < 8; i++)
            a = cast(ubyte)(a << 1 | states[i]);

        for (int i = 8; i < 16; i++)
            b = cast(ubyte)(b << 1 | states[i]);

        this.mem[0] = a;
        this.mem[1] = b;
    }

    void pause()
    {
        this.paused = true;
        SDL_SetWindowTitle(scr.window, "DBP [PAUSED]");
        log("Emulation was paused");
    }

    void unpause()
    {
        if (this.washalted)
        {
            // Increase the PC by one instruction
            uint pc = (this.mem[2]<<16 | this.mem[3]<<8 | this.mem[4]) + 9;
            this.mem[2] = pc >> 16 & 0xFF;
            this.mem[3] = pc >> 8 & 0xFF;
            this.mem[4] = pc & 0xFF;
        }
        this.paused = false;
        this.washalted = false;
        SDL_SetWindowTitle(scr.window, "DBP");
        log("Emulation was unpaused");
    }

    void cycle()
    {
        // Fetch the program counter
        uint pc = this.mem[2]<<16 | this.mem[3]<<8 | this.mem[4];
        uint a, b, c;

        // Do some cycles
        int i = cycles;
        do
        {
            a = this.mem[pc]<<16 | this.mem[pc+1]<<8 | this.mem[pc+2];
            b = this.mem[pc+3]<<16 | this.mem[pc+4]<<8 | this.mem[pc+5];
            c = this.mem[pc+6]<<16 | this.mem[pc+7]<<8 | this.mem[pc+8];

            if (debg)
                writefln("0x%.6X:\t0x%.6X 0x%.6X 0x%.6X", pc, a, b, c);

            // Move
            this.mem[b] = this.mem[a];

            // Check if a HALT is reached
            if (!nohalt && c == pc &&
                (this.mem[2]<<16 | this.mem[3]<<8 | this.mem[4]) == c)
            {
                log("Halt instruction reached");
                this.washalted = true;
                this.pause();
                break;
            }

            // Jump
            pc = c;

            // That's all, incredible right?
        } while (i--);
    }
}

// Graphical output
class Screen
{
    ubyte[3][256] palette;
    ubyte[256][256] last;
    bool dirty;

    SDL_Window* window;
    SDL_Renderer* renderer;

    void initialize()
    {
        this.initPalette();
        this.initVideo();
    }

    void destroy()
    {
        log("Destroying window and renderer");
        SDL_DestroyRenderer(this.renderer);
        SDL_DestroyWindow(this.window);
    }

    // Initiate the video interface and open a window
    void initVideo()
    {
        log("Initializing SDL video");
        SDL_Init(SDL_INIT_VIDEO);

        this.window = SDL_CreateWindow(
            "DBP",
            SDL_WINDOWPOS_UNDEFINED,
            SDL_WINDOWPOS_UNDEFINED,
            256 * zoom,
            256 * zoom,
            SDL_WINDOW_OPENGL);

        if (this.window is null)
        {
            writefln("ERROR: Could not create window: %s", SDL_GetError());
            exit(1);
        }
        log("Created window");

        this.renderer = SDL_CreateRenderer(window, -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
        if (this.renderer is null)
        {
            writefln("ERROR: Could not create renderer: %s", SDL_GetError());
            exit(1);
        }
        log("Created renderer");

        SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, 255);
        SDL_RenderClear(this.renderer);
    }

    void initPalette()
    {
        // Initialize the 6*6*6 color cube
        int i = 0;
        int r, g, b;

        log("Initializing color palette");

        for (r = 0; r <= 0xFF; r += 0x33)
            for (g = 0; g <= 0xFF; g += 0x33)
                for (b = 0; b <= 0xFF; b += 0x33)
                    this.palette[i++] = cast(ubyte[])[r, g, b];

        // Fill the remaining spaces with black
        for (; i < 256; i++)
            this.palette[i] = [0, 0, 0];
    }

    // Put a single pixel
    void put(uint x, uint y, ubyte c)
    {
        if (this.last[x][y] != c)
        {
            ubyte[3] color = this.palette[c];
            SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], 255);
            SDL_Rect* rect = new SDL_Rect(x * zoom, y * zoom, zoom, zoom);
            SDL_RenderFillRect(renderer, rect);
            this.dirty = true;
            this.last[x][y] = c;
        }
    }

    // Redraw the entire VM graphics e.g after window resizes
    void redraw()
    {
        ubyte c;

        log("Full redraw requested");

        for (int x = 0; x < 256; x++)
        {
            for (int y = 0; y < 256; y++)
            {
                c = this.last[x][y];
                this.last[x][y] = 0xFF;
                this.put(x, y, c);
            }
        }

        this.dirty = true;
    }

    void render()
    {
        if (this.dirty)
            SDL_RenderPresent(renderer);
    }
}

// The BytePusher VM
class Machine
{
    ubyte[3][256] palette;
    ubyte[256][256] lastScreen; // basic dirty pixel thingy

    bool initiatedAudio;

    // Initialize the core and the graphics
    void initialize()
    {
        if (audio)
            this.initAudio();
    }

    void destroy()
    {
        log("Closing audio device");
        SDL_CloseAudio();
    }

    void initAudio()
    {
        log("Initializing SDL audio");
        SDL_Init(SDL_INIT_AUDIO);

        audioBuffer = new Uint8[](buffersize * 2);

        SDL_AudioSpec desired;

        desired.freq = 15360;
        desired.format = AUDIO_S8;
        desired.channels = 1;
        desired.samples = buffersize;
        desired.callback = &audioCallback;
        desired.userdata = null;

        log("Opening audio device");
        if (SDL_OpenAudio(&desired, null) < 0)
        {
            writefln("ERROR: Could not open audio device: %s", SDL_GetError());
            exit(1);
        }

        SDL_PauseAudio(0);
        initiatedAudio = true;
    }

    void draw()
    {
        int adress = core.mem[5] << 16;
        int i = 0xFFFF;

        // Should be faster than two for-loops
        do
        {
            scr.put(i % 256, i / 256, core.mem[adress | i]);
        } while (i--);
    }

    void play()
    {
        int adress = core.mem[6]<<8 | core.mem[7];

        for (int i = 0; i < 256; i++)
        {
            audioBuffer ~= core.mem[adress<<8 | i];
        }
    }

    void load(string path)
    {
        log(format("Loading memory from %s", path));

        ubyte[] data = cast(ubyte[])read(path);
        log(format("Size: %s bytes", data.length));

        if (data.length > core.mem.length)
            throw new Exception("File too big");

        int i = 0;

        log("Copying data into memory");
        for (; i < data.length; i++)
            core.mem[i] = data[i];

        for (; i < core.mem.length; i++)
            core.mem[i] = 0x00;
    }

    void save(string path)
    {
        log(format("Dumping memory to %s", path));
        ubyte[] data = core.mem;

        log("Stripping trailing zeros");
        while (data[$-1] == 0)
            data.popBack();

        std.file.write(path, data);
    }
}

// The GUI and text drawing
class Interface
{
    SDL_Texture* font;

    bool shown = false;
    bool dirty = false;
    bool shift = false;

    string input = "";

    int selected = 0;
    int page = 0;

    int keyedit = -1;

    void initialize()
    {
        this.initFont();
    }

    void initFont()
    {
        log("Loading font bitmap");
        SDL_Surface* bmp = SDL_LoadBMP(getPath("font.bmp").toStringz());
        if (bmp is null)
        {
            writeln("ERROR: Could not load bitmap: " ~ to!string(SDL_GetError()));
            exit(1);
        }

        this.font = SDL_CreateTextureFromSurface(scr.renderer, bmp);
        SDL_FreeSurface(bmp);
        if (this.font is null)
        {
            writeln("ERROR: Could not create texture: " ~ to!string(SDL_GetError()));
            exit(1);
        }
    }

    void show()
    {
        this.shown = true;
        this.dirty = true;
        core.pause();
        this.page = 0;
        log("GUI shown");
    }

    void hide()
    {
        this.shown = false;
        core.unpause();
        scr.redraw();
        log("GUI hidden");
    }

    void drawChar(int x, int y, char chr)
    {
        SDL_Rect pick;

        pick.x = (chr % 32) * 8;
        pick.y = (chr / 32) * 16;
        pick.w = 8;
        pick.h = 16;

        SDL_Rect tmp = pick;
        tmp.x = x;
        tmp.y = y;

        SDL_RenderCopy(scr.renderer, this.font, &pick, &tmp);
    }

    void drawString(int x, int y, string text)
    {
        foreach (char c; text)
        {
            this.drawChar(x, y, c);
            x += 9;
        }
    }

    void drawRect(int x, int y, int w, int h, ubyte[3] color)
    {
        SDL_SetRenderDrawColor(scr.renderer, color[0], color[1], color[2], 255);
        SDL_Rect* rect = new SDL_Rect(x, y, w, h);
        SDL_RenderFillRect(scr.renderer, rect);
    }

    void drawList(int x, int y, string[] texts)
    {
        if (this.selected >= texts.length)
            this.selected = 0;
        else if (this.selected < 0)
            this.selected = texts.length - 1;

        int id = this.selected;
        while (texts.length > 4)
        {
            if (id == texts.length - 1)
            {
                texts.popFront();
                id--;
            }
            else
            {
                texts.popBack();
            }
        }

        foreach (int i, string s; texts)
        {
            this.drawString(x+9, y, s);
            if (i == id)
                this.drawRect(x, y+6, 4, 4, [255, 255, 0]);

            y += 16;
        }
    }

    void drawInput(int x, int y)
    {
        this.drawString(x, y, this.input);
        x += this.input.length * 9;
        this.drawRect(x+3, y+10, 7, 3, [255, 255, 0]);
    }

    void changePage(int p)
    {
        this.page = p;
        this.dirty = true;
        this.selected = 0;
        this.shift = false;
        this.input = "";
        log(format("GUI page changed to %s", p));
    }

    void keydown(int scancode, int keycode)
    {
        if (scancode == SDL_SCANCODE_ESCAPE)
        {
            if (this.page == 6)
                this.changePage(5);
            else if (this.page == 7)
                this.page = 6;
            else if (this.page != 0)
                this.changePage(0);
            else
                this.hide();
            this.selected = 0;
        }

        // Key edit page
        else if (this.page == 7)
        {
            if (keyedit != -1)
                changeKeyBind(this.keyedit, scancode);

            this.keyedit = -1;
            this.page = 6;
        }

        else if (scancode == SDL_SCANCODE_UP)
            this.selected--;
        else if (scancode == SDL_SCANCODE_DOWN)
            this.selected++;
        else if (scancode == SDL_SCANCODE_LEFT)
        {
            if (this.page == 5 && this.selected == 1 && zoom > 1)
            {
                zoom--;
                SDL_SetWindowSize(scr.window, 256 * zoom, 256 * zoom);
                log(format("Pixel size lowered to %s", zoom));
                scr.redraw();
            }
        }
        else if (scancode == SDL_SCANCODE_RIGHT)
        {
            if (this.page == 5 && this.selected == 1 && zoom < 4)
            {
                zoom++;
                SDL_SetWindowSize(scr.window, 256 * zoom, 256 * zoom);
                log(format("Pixel size raised to %s", zoom));
                scr.redraw();
            }
        }

        else if (scancode == SDL_SCANCODE_RETURN)
        {
            if (this.page == 0)
            {
                if (this.selected == 0)
                    this.changePage(1);
                else if (this.selected == 1)
                    this.changePage(2);
                else if (this.selected == 2)
                    this.changePage(5);
                else if (this.selected == 3)
                    running = false;
            }
            else if (this.page == 1)
            {
                try
                {
                    machine.load(this.input);
                    this.hide();
                }
                catch
                {
                    this.changePage(3);
                }
            }
            else if (this.page == 2)
            {
                try
                {
                    machine.save(this.input);
                    this.changePage(0);
                }
                catch
                {
                    this.changePage(4);
                }
            }
            else if (this.page == 5)
            {
                if (this.selected == 0)
                {
                    audio = !audio;

                    log("Audio requested by user");

                    if (!machine.initiatedAudio)
                        machine.initAudio();
                }
                else if (this.selected == 2)
                    this.changePage(6);
            }
            else if (this.page == 6)
            {
                this.keyedit = this.selected;
                this.changePage(7);
            }
        }

        // Input pages
        else if (this.page == 1 || this.page == 2)
        {
            if (contains("abcdefghijklmnopqrstuvwxyz1234567890 .-_,", cast(char)keycode))
            {
                if (this.shift)
                    this.input ~= toUpper(cast(char)keycode);
                else
                    this.input ~= cast(char)keycode;
            }

            if (scancode == SDL_SCANCODE_LSHIFT || scancode == SDL_SCANCODE_RSHIFT)
                this.shift = true;
            else if (scancode == SDL_SCANCODE_BACKSPACE && this.input.length > 0)
                this.input.popBack();
        }

        // Redraw because why not?
        this.dirty = true;
    }

    void keyup(int scancode, int keycode)
    {
        if (scancode == SDL_SCANCODE_LSHIFT || scancode == SDL_SCANCODE_RSHIFT)
            this.shift = false;

        this.dirty = true;
    }

    void draw()
    {
        if (this.shown && this.dirty)
        {
            this.drawRect(0, 0, 256, 128, [20, 20, 20]);

            if (this.page == 0)
            {
                this.drawString(10, 10, "Main Menu");
                this.drawList(10, 30, [
                        "Load",
                        "Save",
                        "Configuration",
                        "Exit"
                    ]);
                this.drawString(10, 108, "ESC: Close  U/D: Select");
            }
            else if (this.page == 1)
            {
                this.drawString(10, 10, "Enter the name of the");
                this.drawString(10, 26, "memory file to load:");
                this.drawInput(10, 56);
                this.drawString(10, 108, "ESC: Back  Enter: Load");
            }
            else if (this.page == 2)
            {
                this.drawString(10, 10, "Enter the name to dump");
                this.drawString(10, 26, "the memory under:");
                this.drawInput(10, 56);
                this.drawString(10, 108, "ESC: Back  Enter: Save");
            }
            else if (this.page == 3)
            {
                this.drawString(10, 10, "ERROR");
                this.drawString(10, 26, "Could not load file!");
                this.drawString(10, 108, "ESC: Back");
            }
            else if (this.page == 4)
            {
                this.drawString(10, 10, "ERROR");
                this.drawString(10, 26, "Could not save file!");
                this.drawString(10, 108, "ESC: Back");
            }
            else if (this.page == 5)
            {
                this.drawString(10, 10, "Configuration");
                this.drawList(10, 30, [
                    "Toggle audio " ~ (audio ? "off" : "on"),
                    "Change zoom: " ~ to!string(zoom) ~ "px",
                    "Change keybinds"
                    ]);
                if (this.selected == 0)
                    this.drawString(10, 108, "ESC: Back  Enter: Toggle");
                else if (this.selected == 1)
                    this.drawString(10, 108, "ESC: Back  L/R: Change");
                else
                    this.drawString(10, 108, "ESC: Back  U/D: Select");
            }
            else if (this.page == 6)
            {
                this.drawString(10, 10, "Change keybinds");
                this.drawList(10, 30, [
                    "Key 0: " ~ getKeyName(k0),
                    "Key 1: " ~ getKeyName(k1),
                    "Key 2: " ~ getKeyName(k2),
                    "Key 3: " ~ getKeyName(k3),
                    "Key 4: " ~ getKeyName(k4),
                    "Key 5: " ~ getKeyName(k5),
                    "Key 6: " ~ getKeyName(k6),
                    "Key 7: " ~ getKeyName(k7),
                    "Key 8: " ~ getKeyName(k8),
                    "Key 9: " ~ getKeyName(k9),
                    "Key A: " ~ getKeyName(kA),
                    "Key B: " ~ getKeyName(kB),
                    "Key C: " ~ getKeyName(kC),
                    "Key D: " ~ getKeyName(kD),
                    "Key E: " ~ getKeyName(kE),
                    "Key F: " ~ getKeyName(kF)
                    ]);
                this.drawString(10, 108, "ESC: Back  Enter: Edit");

                // Draw a fancy keyboard because why not
                int[] board = [
                    0x1, 0x2, 0x3, 0xC, 
                    0x4, 0x5, 0x6, 0xD,
                    0x7, 0x8, 0x9, 0xE,
                    0xA, 0x0, 0xB, 0xF];
                int[] map = [k0,k1,k2,k3,k4,k5,k6,k7,k8,k9,kA,kB,kC,kD,kE,kF];

                int x, y;
                ubyte c;

                for (int i = 0; i < board.length; i++)
                {
                    x = 185 + (i % 4)*15;
                    y = 32 + (i / 4)*15;
                    c = 55;

                    if (map[this.selected] == map[board[i]])
                        c += 100;

                    if (keystates[0xF - board[i]])
                        c += 100;

                    this.drawRect(x, y, 13, 13, [c, c, c]);
                }
            }
            else if (this.page == 7)
            {
                if (this.keyedit == -1)
                    this.changePage(6);
                else
                {
                    this.drawString(10, 10, "Press the key to bind");
                    this.drawString(10, 26, format("key %X to:", this.keyedit));
                    this.drawString(10, 108, "ESC: Back  Other: Set key");
                }
            }

            this.dirty = false;
        }
    }
}


int main(string[] args)
{
    keymap = [kF,kE,kD,kC,kB,kA,k9,k8,k7,k6,k5,k4,k3,k2,k1,k0];
    core = new Core();
    machine = new Machine();
    scr = new Screen();
    gui = new Interface();
    bool wasMinimized;

    bool noaudio;
    bool help;
    int fzoom = -1;

    dbppath = std.path.dirName(args[0]);
    cfgpath = getPath(cfgpath);

    string[] oldargs = args.dup;
    getopt(
        args,
        std.getopt.config.passThrough,
        "noaudio|n", &noaudio,
        "help|h", &help,
        "zoom|z", &fzoom,
        "cfg|c", &cfgpath,
        "verbose|v", &verbose,
        "debug", &debg,
        "nohalt", &nohalt);

    log("Here we go!");
    log(format("Arguments: %s", oldargs));

    if (help)
    {
        writefln(
"DBP (D Byte Pusher) 0.1
by nucular, Licensed under the GNU GPL 3

Usage:
%s [flags] ... [PATH]

Optional arguments:
PATH                 The path to a BytePusher memory dump
--help, -h           Show this help
--noaudio, -n        Turn off audio output
--zoom=#, -z=#       Set the size of one pixel
--cfg=\"\", -c=\"\"      Load an alternative config file
--verbose, -v        Log important actions to stdout
--debug              Log every instruction (SLOOOOOOW)
--nohalt             Turn off pausing the emulator if a HALT is reached",
            oldargs[0]);
        return 0;
    }

    loadConfig();

    // Overwrite loaded configuration with arguments
    if (noaudio)
        audio = false;
    if (fzoom > 0 && fzoom <= 4)
        zoom = fzoom;


    log(format("Config: audio=%s, zoom=%s, keymap=%s", audio, zoom, keymap));
    core.initialize();

    // Eventually load a passed memory dump
    bool welcome = false;
    if (args.length >= 2)
    {
        string path = args[1..$].join(" ");
        try
        {
            machine.load(path);
            scr.dirty = true;
        }
        catch (Exception e)
        {
            writefln("ERROR: %s", e.msg);
            return 1;
        }
    }
    else
    {
        // Or load a welcome graphic
        welcome = true;
    }

    // Time to start SDL
    log("Loading Derelict and libSDL2");
    try
    {
        DerelictSDL2.load();

        scr.initialize();
        machine.initialize();
        gui.initialize();
    }
    catch (Exception e)
    {
        writefln("ERROR: %s", e.msg);
        return 1;
    }

    // Load the welcome graphic after initializing!
    if (welcome)
    {
        machine.load(getPath("start.bp"));
        gui.show();
        scr.dirty = true;
    }

    int time = SDL_GetTicks();
    long frames;
    int temp;
    int skip = 1;
    int freq = 1000/fps;
    int lastrefresh = 0;

    log("Entering main loop");
    while (running)
    {
        // Run the machine
        if (!core.paused)
        {
            for (int i = 0; i < skip; i++)
            {
                core.cycle();
            }

            if (audio)
                machine.play();
        }

        // Draw like everything
        machine.draw();
        gui.draw();

        scr.render();

        // Frame counter
        time = SDL_GetTicks();
        if (time - frames >= freq)
        {
            temp = cast(int)(time - frames) / freq;
            frames += temp * freq;
            skip = temp;
        }
        else
        {
            SDL_Delay(freq - cast(int)(time - frames));
            frames += freq;
            skip = 1;
        }

        // Refresh window title
        if (time - lastrefresh >= 1000 && !core.paused)
        {
            float mhz = (skip * cycles * fps) / 10000000.0;
            uint pc = (core.mem[2]<<16 | core.mem[3]<<8 | core.mem[4]);

            SDL_SetWindowTitle(scr.window,
                format("DBP [%s MIPS] [PC at 0x%.6X]", mhz, pc).toStringz());
            lastrefresh = time;
        }
        
        while (SDL_PollEvent(&event))
        {
            switch (event.type)
            {
                case SDL_QUIT:
                    running = false;
                    break;

                // Workaround for the Derelict bug where the window size changes
                // after restoring.
                case SDL_WINDOWEVENT:
                    if (event.window.event == SDL_WINDOWEVENT_MINIMIZED)
                    {
                        wasMinimized = true;
                        log("Window minimized");
                    }
                    if (event.window.event == SDL_WINDOWEVENT_RESTORED && wasMinimized)
                    {
                        wasMinimized = false;
                        SDL_SetWindowSize(scr.window, 256 * zoom, 256 * zoom);
                        log("Window restored");
                        scr.redraw();
                    }
                    break;

                // Input
                case SDL_KEYDOWN:
                    if (gui.shown)
                    {
                        gui.keydown(event.key.keysym.scancode,
                            event.key.keysym.sym);
                    }
                    else if (event.key.keysym.scancode == SDL_SCANCODE_ESCAPE)
                        gui.show();

                    else if (event.key.keysym.scancode == SDL_SCANCODE_SPACE)
                    {
                        if (core.paused)
                            core.unpause();
                        else
                            core.pause();
                    }

                    for (int i = 0; i < keymap.length; i++)
                    {
                        if (event.key.keysym.scancode == keymap[i])
                        {
                            keystates[i] = true;
                            core.setKeys(keystates);
                        }
                    }

                    break;

                case SDL_KEYUP:
                    if (gui.shown)
                        gui.keyup(event.key.keysym.scancode,
                            event.key.keysym.sym);

                    for (int i = 0; i < keymap.length; i++)
                    {
                        if (event.key.keysym.scancode == keymap[i])
                        {
                            keystates[i] = false;
                            core.setKeys(keystates);
                        }
                    }

                    break;

                default:
                    break;
            }
        }
    }
    log("Leaving main loop");

    // Clean up the mess
    scr.destroy();
    machine.destroy();
    SDL_Quit();
    saveConfig();
    
    log("Done!");
    return 0;
}
