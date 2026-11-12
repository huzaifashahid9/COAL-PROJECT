# Treasure Hunt Adventure

A text-based maze game for the Windows console, written in **MASM x86 (32-bit) assembly** using the **Irvine32** library.

**COAL Project. Group members:**
- Kinza Detho (24K-3097), Group Leader
- Huzaifa (24K-3069)
- Mohak (25K-3002)

---

## Files

| File | Purpose |
|---|---|
| `TreasureHunt.asm` | The complete game (single source file) |
| `level1.txt`, `level2.txt`, `level3.txt` | Level maps (one row of the maze per line) |
| `savegame.txt` | Created when you save: XOR-encrypted game state |
| `leaderboard.txt` | Created after a game ends: `name,level,score` per line |
| `custom.txt` | Created by the Map Editor |

## How to build and run (Visual Studio 2022)

1. Open your existing Irvine32 / MASM project (the one your class uses for labs), or the Irvine `Project32` template.
2. Remove the old `.asm` file from the project and add **`TreasureHunt.asm`** (Solution Explorer → right-click *Source Files* → *Add → Existing Item*).
3. Copy **`level1.txt`, `level2.txt`, `level3.txt`** into the **same folder as the `.asm` file** (the project folder). Visual Studio runs the program from that folder, so that's where the game looks for the maps.
4. Make sure the platform is **x86** (not x64), then press **Ctrl+F5** (or F5).
5. The console window should be at least **100 columns wide and 30 rows tall** (the default Windows console is 120 × 30).

If the game says it cannot load a map, the level `.txt` files are not in the project folder.

## Controls

| Key | Action |
|---|---|
| `W` `A` `S` `D` or arrow keys | Move |
| `R` | Treasure Radar (3 uses per level) |
| `G` | Save game |
| `F` | Fog of war on/off (demo view) |
| `Q` or `Esc` | Quit to main menu (asks to save first) |

## Tiles

| Tile | Meaning |
|---|---|
| `@` | Player (green) |
| `#` | Wall (gray, blocks movement) |
| `.` | Empty floor (safe room) |
| `T` | Treasure: +10 score |
| `X` | Trap: −20 health, −5 score (fires once) |
| `H` | Health potion: +20 health, max 100 |
| `P` | Portal: teleports you to the other `P` |
| `K` | Key: opens one door |
| `D` | Locked door: needs a key (bonus treasure rooms are behind doors) |
| `A` | Shield: blocks the next trap |
| `E` | Exit: go to the next level |
| `?` | Not discovered yet (fog of war) |
| `S` | Start position (only in the map files) |

## Features

### Core gameplay
- The maze is a 2D grid (`grid` array, `row * MAX_COLS + col` indexing) loaded from a text file.
- The screen updates after every move without flicker, because the cursor is moved with `Gotoxy` instead of clearing the screen.
- Score, health, steps and level are tracked. The game ends when health reaches 0.
- Three levels of increasing difficulty: bigger maps, more traps, fewer treasures. Health carries over between levels.
- **Random generation**: each level adds extra treasures and traps to random empty cells (`RandomRange`).

### File handling
- **Level maps** are read from `level1.txt` to `level3.txt` and parsed character by character, so they handle CR/LF, spaces and lowercase.
- **Save/Load**: the whole game state is written to `savegame.txt`, including the map with collected items and the fog of war, so a loaded game resumes exactly.
- **Encrypted save**: the save data is XOR-encrypted with a repeating key, and a checksum detects any editing. Running the same XOR again decrypts it.
- **Leaderboard**: `leaderboard.txt` stores name, level reached and final score. Entries are bubble-sorted by score and the top 10 are kept.

### Enhanced gameplay
- **Fog of war**: only the 3×3 area around the player and previously seen cells are visible (`seen` array).
- **Treasure Radar**: nearest treasure by Manhattan distance `|dx| + |dy|`. HOT ≤ 3, WARM ≤ 7, otherwise COLD.
- **Health potions**, **portals**, **keys and doors** (inventory) and **shields**.
- **Star rating**: 1 to 3 stars per level based on steps compared with par, with +10 score per star.
- **Sound effects** through the Windows `Beep` API: high beeps for treasure, low beeps for traps, plus jingles for level complete, game over and victory.

### Console GUI
- Colour-coded map: player green, treasure yellow, trap red, exit cyan, walls gray.
- HUD side panel with player, mode, level, score, health, steps, moves, treasure left, radar, keys and shield.
- Health bar made of block characters, one block per 10 health, coloured green, yellow or red.
- Boxed main menu, notices and result screens drawn with box-drawing characters.

### Extra add-ons
- **Map Editor**: type a map row by row. It is validated (exactly one `S`, at least one `E`), saved to `custom.txt`, and can then be played.
- **Time Challenge mode**: every level has a move limit that counts down with each move.
- **Inventory**: keys (open doors to bonus rooms) and a shield (blocks one trap).

## Assembly topics demonstrated

| Topic | Where |
|---|---|
| Arrays | `grid`, `seen`, `tileChars`/`tileColors` (parallel arrays), `levelFiles` (pointer table), leaderboard arrays |
| Strings | messages, player name, file names, `repne scasb` tile lookup, `Str_copy`, `Str_length` |
| Procedures | 55 procedures (`TryMove`, `ApplyCell`, `ParseMap`, `SaveGame`, `SortLeaderboard`, …) with `USES` and `INVOKE` parameters |
| Macros | `mPrint`, `mColor`, `mGoto`, `mHud`, `mBeep` |
| Loops and nested loops | map drawing, radar scan, fog reveal, bubble sort |
| Conditional logic | tile effects, input handling, star rating |
| File I/O | `OpenInputFile`, `ReadFromFile`, `CreateOutputFile`, `WriteToFile`, `CloseFile` |
| String parsing | map text to grid, leaderboard `name,level,score` lines (`ParseNumber`, `AppendNumber`) |
| Bitwise operations | XOR encryption, `rol` checksum, branch-free `abs` (`cdq / xor / sub`), `xor` toggle for fog |
| Windows API | `Beep`, plus `SetTextColor` and `Gotoxy` from Irvine32 |

## Map file format

Plain text with one maze row per line, up to **30 columns × 20 rows**. Use the tile letters above. There must be exactly one `S`, at least one `E`, and portals in pairs. Surround the map with `#`. Rows shorter than the widest row are padded with walls.
