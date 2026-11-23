# 🗺️ Treasure Hunt Adventure: Poori Guide (Roman Urdu)

> Ye guide is liye hai ke **tum khud game khel sako**, **poora code samajh sako**, aur phir **teammates ko explain kar sako** (viva / presentation ke liye bhi).
> Har function ka **kaam kya hai**, **code kaise chalta hai**, aur **kis case mein kya hota hai**, sab "Bhai kam aese hoga k..." style mein likha hai.

---

## 📑 Fehrist (Table of Contents)

1. [Project ek line mein](#1-project-ek-line-mein)
2. [Game chalana kaise hai (Setup)](#2-game-chalana-kaise-hai-setup)
3. [Game khelna kaise hai (How to Play)](#3-game-khelna-kaise-hai-how-to-play)
4. [Level 1 ka ready-made raasta (practice ke liye)](#4-level-1-ka-ready-made-raasta)
5. [Code ka overall structure (Big Picture)](#5-code-ka-overall-structure)
6. [Constants, Macros aur Data, ek ek kar ke](#6-constants-macros-aur-data)
7. [Har function ki explanation (55 procedures)](#7-har-function-ki-explanation)
   - 7.1 main
   - 7.2 Screen Helpers
   - 7.3 Menus
   - 7.4 Game Flow
   - 7.5 Movement aur Tile Effects
   - 7.6 Level Loading
   - 7.7 Drawing (Screen par cheezein banana)
   - 7.8 Level Complete / Game Over / Victory
   - 7.9 Save / Load (XOR Encryption)
   - 7.10 Leaderboard
   - 7.11 Map Editor
8. [Poora flow ek example se (key dabane se screen tak)](#8-poora-flow-ek-example-se)
9. [Saare use cases / edge cases ki list](#9-saare-use-cases--edge-cases)
10. [Viva mein pooche jane wale sawal + jawab](#10-viva-sawal-jawab)
11. [Teammates mein kaam kaise baantein (presentation)](#11-teammates-mein-presentation-kaise-baantein)

---

## 1. Project ek line mein

Bhai kam aese hoga k ye ek **maze (bhool bhulaiyan) game** hai jo **MASM x86 Assembly** mein **Irvine32 library** ke saath likha gaya hai. Player `@` ek maze mein ghoomta hai, **treasure (T)** uthata hai, **traps (X)** se bachta hai, aur **Exit (E)** tak pohanch kar agle level mein jata hai. 3 levels hain. Saath mein save/load (encrypted), leaderboard, fog of war, radar, portals, keys/doors, shield, map editor, aur time challenge mode bhi hai.

**Files:**

| File | Kya hai |
|---|---|
| `TreasureHunt.asm` | Poora game, ek hi file mein (2847 lines, 55 procedures) |
| `level1.txt` / `level2.txt` / `level3.txt` | Teeno levels ke maps (plain text) |
| `savegame.txt` | Jab tum `G` dabao ge tab banegi (encrypted) |
| `leaderboard.txt` | Game khatam hone par banegi (`naam,level,score`) |
| `custom.txt` | Map Editor se banai hui map |

---

## 2. Game chalana kaise hai (Setup)

Bhai kam aese hoga k:

1. **Visual Studio 2022** mein apna Irvine32 wala project kholo (jo labs mein use karte ho), ya Irvine ka `Project32` template.
2. Purani `.asm` file project se **Remove** karo, aur `TreasureHunt.asm` **Add → Existing Item** se daalo.
3. `level1.txt`, `level2.txt`, `level3.txt` ko **usi folder mein copy karo jahan `.asm` file hai** (project folder). Program wahin se maps dhoondta hai.
4. Upar platform **x86** hona chahiye (x64 nahi!).
5. **Ctrl + F5** dabao.
6. Console window kam az kam **100 columns × 30 rows** ki honi chahiye (default 120×30 theek hai).

**Agar error aaye "could not load the map file"** → matlab level `.txt` files ghalat folder mein hain. Unhe `.asm` wale folder mein daalo.

---

## 3. Game khelna kaise hai (How to Play)

### 3.1 Main Menu

Game start hote hi ye menu aata hai:

```
[1] New Game       → naya game shuru
[2] Load Game      → save kiya hua game wapas chalao
[3] Leaderboard    → top 10 scores dekho
[4] Map Editor     → apna khud ka map banao / khelo
[5] How to Play    → instructions
[6] Exit           → band karo
```

Bas number key dabao (Enter ki zaroorat nahi).

### 3.2 New Game

1. Apna **naam** likho (max 16 characters) aur Enter dabao. Khali chhoda to naam `Player` ho jayega.
2. Mode choose karo:
   - **[1] Classic** → jitni marzi moves karo, koi limit nahi.
   - **[2] Time Challenge** → har level mein limited moves (Level 1: 150, Level 2: 200, Level 3: 200). Moves khatam = Game Over.

### 3.3 Controls

| Key | Kaam |
|---|---|
| `W` / ↑ | Upar |
| `S` / ↓ | Neeche |
| `A` / ← | Baayen (left) |
| `D` / → | Daayen (right) |
| `R` | **Radar**: batata hai treasure kitna qareeb hai (har level mein 3 baar) |
| `G` | Game **save** karo |
| `F` | Fog of war on/off (poora map dekhne ke liye, demo/testing ke liye) |
| `Q` / `Esc` | Quit (pehle poochega "save karna hai? Y/N") |

Capital ya small, dono chalte hain.

### 3.4 Screen par kya kya dikhta hai

```
TREASURE HUNT ADVENTURE   -   Level 1: The Old Cellar

▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       ╔══════════════════════════════╗
▓▓@ · · ? ? ? ? ? ?        ║ PLAYER : Ali                 ║
▓▓· ▓▓? ? ? ? ? ? ?        ║ MODE   : CLASSIC             ║
? ? ? ? ? ? ? ? ? ?        ║ LEVEL  : 1 / 3               ║
                           ║ SCORE  : 0                   ║
                           ║ HEALTH : 100 / 100           ║
                           ║ [██████████]                 ║
                           ║ STEPS  : 0                   ║
                           ║ MOVES  : no limit            ║
                           ║ GOLD   : 5 left              ║
                           ║ RADAR  : 3 left              ║
                           ║ KEYS   : 0                   ║
                           ║ SHIELD : OFF                 ║
                           ╟──────────────────────────────╢
                           ║ ...controls + legend...      ║
                           ╚══════════════════════════════╝
Explore the maze, collect treasure (T) and find the EXIT (E). Good luck!
```

- **Left side** = maze. `?` matlab abhi wo jagah dekhi nahi (fog).
- **Right side** = HUD (score, health, waghera).
- **Neeche** = message line (har move ke baad kya hua).

### 3.5 Tiles ka matlab (yaad kar lo!)

| Tile | Rang | Kya hota hai |
|---|---|---|
| `@` | Green | Tum (player) |
| `▓▓` (`#`) | Gray | Deewar. Aar paar nahi ja sakte |
| `·` (`.`) | Dark gray | Khali farsh, safe |
| `T` | Yellow | **Treasure** → +10 score |
| `X` | Red | **Trap** → −20 health, −5 score (sirf ek baar lagta hai, phir gayab) |
| `H` | Magenta | **Health Potion** → +20 health (max 100) |
| `P` | Blue | **Portal** → doosre `P` par teleport |
| `K` | Brown | **Key** → ek darwaza khol sakti hai |
| `D` | White on brown | **Locked Door** → key chahiye. Peeche aksar bonus treasure hota hai |
| `A` | Cyan | **Shield** → agla trap block kar dega |
| `E` | Light cyan | **Exit** → level complete |
| `?` | Gray | Fog: abhi nahi dekha |

### 3.6 Rules jo dimagh mein rakhne hain

- **Health 100 se start**, aur **agle level mein bhi wahi health jaati hai** (refill nahi hoti!). 5 traps = maut (5 × 20 = 100).
- **Score kabhi negative nahi hota**. 0 se neeche nahi jayega.
- **Deewar se takrana step count nahi karta**, na hi time-mode mein move khata hai.
- **Stars (har level ke end par):**
  - Steps ≤ par → ⭐⭐⭐ (+30 score)
  - Steps ≤ 1.5 × par → ⭐⭐ (+20)
  - Warna → ⭐ (+10)
  - Par: Level 1 = **80**, Level 2 = **110**, Level 3 = **100**
- **Radar:** HOT = treasure 3 steps ya kam door, WARM = 4 se 7, COLD = 7 se zyada. (Distance deewaron ko ignore karke seedha `|row farq| + |col farq|` hai.)
- **Keys har level par 0 ho jaati hain**, lekin **shield agle level mein bhi saath jaata hai** (agar use nahi hua).
- Har level par game **random** extra treasures aur traps bhi daal deta hai, is liye har baar map thora alag hoga:
  - Level 1: +2 treasure, +1 trap
  - Level 2: +1 treasure, +3 traps
  - Level 3: +1 treasure, +4 traps

### 3.7 Game kab khatam hota hai

| Situation | Kya hota hai |
|---|---|
| Teeno levels ka Exit mil gaya | 🎉 Victory screen → leaderboard mein naam |
| Health 0 | 💀 Game Over → leaderboard mein naam |
| Time mode mein moves 0 | ⏰ Game Over → leaderboard mein naam |
| Q dabaya | Main menu par wapas, **leaderboard mein entry nahi** |
| Custom map khela | Victory/Game Over dikhega, lekin **leaderboard mein entry nahi** |

### 3.8 Winning Tips

1. Pehle `F` daba kar fog band karo aur map dekh lo (practice ke liye). Asli game mein fog on rakho.
2. Radar ko tab use karo jab `GOLD: x left` mein treasure baqi ho aur samajh na aa raha ho kidhar jayen.
3. Health 40 se kam ho to `H` potion dhoondo.
4. Shield (`A`) pehle utha lo, phir trap wale area mein jao.
5. Exit ki taraf seedha jao agar stars chahiye, kyun ke kam steps = zyada stars.

---

## 4. Level 1 ka ready-made raasta

Level 1 ka map (`level1.txt`), rows 0 se aur columns 0 se gino:

```
     col: 01234567890123456789
row 0:    ####################
row 1:    #S..#....T....#...T#
row 2:    #.#.#.###.###.#.##.#
row 3:    #.#...#.....#...#..#
row 4:    #.###.#.#X#.###.#.##
row 5:    #T..X.#.#T#...#....#
row 6:    ###.###.#.###.#.##.#
row 7:    #H..#...#...X.#..#.#
row 8:    #..T#.T...#...#..#E#
row 9:    ####################
```

**Seedha raasta Exit tak (1 treasure ke saath, sirf 28 steps → 3 stars pakke):**

```
D D        → (1,3)  right
S S        → (3,3)  neeche
D D        → (3,5)  right
W W        → (1,5)  upar
D D D D D D D D   → (1,13)  right (raste mein (1,9) wala T mil jayega, +10)
S S        → (3,13) neeche
D D        → (3,15) right
S S        → (5,15) neeche
D D D      → (5,18) right
S S S      → (8,18) EXIT! 🎉
```

⚠️ Note: game random trap bhi daalta hai, to agar raste mein laal `X` nazar aaye to ghoom ke jao.

**Bonus:** (5,17) par pohanch kar `W W D W W` karo to (1,18) wala T bhi mil jayega, phir `S S A S S D S S S` se wapas exit.

---

## 5. Code ka overall structure

Bhai kam aese hoga k poori file in hisson mein bati hui hai (upar se neeche):

```
1. INCLUDE Irvine32.inc + Beep PROTO     → library + Windows sound function
2. CONSTANTS (MAX_ROWS, TILE_WALL...)    → fixed numbers / characters
3. MACROS (mPrint, mColor, mGoto...)     → chhote shortcuts
4. .data                                 → saare variables, arrays, messages
5. .code
   ├── main                              → menu loop
   ├── Screen helpers                    → box, colour, cursor
   ├── Menus                             → main menu, how to play, new game
   ├── Game flow                         → PlayGame, PlayLevel (game loop)
   ├── Movement + tile effects           → TryMove, ApplyCell, Radar
   ├── Level loading                     → file padhna, parse karna, random items
   ├── Drawing                           → map, HUD, health bar, message
   ├── End screens                       → level complete, game over, victory
   ├── Save / Load                       → XOR encryption + checksum
   ├── Leaderboard                       → file, parse, bubble sort
   └── Map editor                        → apna map banao
6. END main
```

### Call Tree (kaun kisko bulata hai)

```
main
 ├─ ShowMainMenu
 ├─ [1] NewGame ─ SetPlayerName
 │        └─ PlayGame
 │             ├─ LoadLevel ─ ParseMap ─ FindFirstOpenCell
 │             │            ├─ ResetLevelState
 │             │            ├─ PlaceRandomItems ─ PlaceRandomTiles ─ AbsEax
 │             │            └─ ComputeLayout
 │             ├─ PlayLevel
 │             │    ├─ DrawLevelScreen ─ DrawBox, HudSeparator, LegendItem ─ DrawCell
 │             │    ├─ RevealAround
 │             │    ├─ RefreshScreen ─ DrawMap ─ DrawCell
 │             │    │                ├─ DrawHudValues ─ HealthColor, DrawHealthBar
 │             │    │                └─ DrawMessage
 │             │    ├─ GetCommand
 │             │    ├─ TryMove ─ RevealAround, ApplyCell ─ FindOtherPortal
 │             │    ├─ UseRadar ─ AbsEax
 │             │    ├─ SaveGame ─ ComputeChecksum, XorCrypt
 │             │    └─ ConfirmQuit ─ SaveGame
 │             ├─ ShowLevelComplete
 │             ├─ ShowGameOver ─ AddToLeaderboard, ShowLeaderboard
 │             └─ ShowVictory  ─ AddToLeaderboard, ShowLeaderboard
 ├─ [2] LoadGame ─ XorCrypt, ComputeChecksum ─ PlayGame
 ├─ [3] LoadLeaderboard ─ ParseNumber, SortLeaderboard ─ SwapLbEntries
 │      ShowLeaderboard
 ├─ [4] MapEditorMenu ─ CreateCustomMap / NewGame (isCustom=1)
 ├─ [5] ShowHowToPlay
 └─ [6] exit
```

### Sab se zaroori concept: 2D grid ko 1D array mein rakhna

Assembly mein 2D array hota nahi. Bhai kam aese hoga k `grid` ek **seedha 600 bytes ka array** hai (`20 rows × 30 cols`). Kisi bhi cell (row, col) ka index:

```
index = row * MAX_COLS + col      ; MAX_COLS = 30
```

**Example:** row 2, col 5 → `2 × 30 + 5 = 65` → `grid[65]`.

Code mein ye pattern bar bar aata hai:
```asm
mov  esi, ecx          ; esi = row
imul esi, MAX_COLS     ; esi = row * 30
add  esi, edx          ; esi = row * 30 + col
mov  al, grid[esi]     ; al = us cell ka tile
```

Ulta (index se row/col nikalna) `div` se hota hai: `index ÷ 30` → quotient = row, remainder = col (portal mein use hua hai).

`seen` array bhi bilkul aisa hi 600 bytes ka hai. `seen[index] = 1` matlab wo cell dekha ja chuka hai (fog hat gaya).

---

## 6. Constants, Macros aur Data

### 6.1 Constants (lines 30–93)

`=` se bane constants memory nahi lete; assembler unhe directly number se replace kar deta hai.

| Constant | Value | Matlab |
|---|---|---|
| `MAX_ROWS`, `MAX_COLS` | 20, 30 | Sab se bara map |
| `MAP_SIZE` | 600 | grid ka total size |
| `MAX_NAME` | 16 | Naam ki max length |
| `NUM_LEVELS` | 3 | Kitne levels |
| `FILE_BUF_SIZE` | 4096 | File padhne ka buffer |
| `MAX_HEALTH` | 100 | |
| `TREASURE_POINTS` | 10 | Treasure ka score |
| `TRAP_PENALTY` / `TRAP_DAMAGE` | 5 / 20 | Trap ka score/health nuksan |
| `POTION_HEAL` | 20 | |
| `RADAR_USES` | 3 | Har level |
| `STAR_BONUS` | 10 | Har star ka score |
| `LOW_MOVES` | 10 | Is se kam moves par warning |
| `CUSTOM_PAR` / `CUSTOM_MOVES` | 60 / 150 | Custom map ke liye |
| `MAP_X`, `MAP_Y` | 2, 2 | Map screen par kahan se shuru |
| `HUD_WIDTH`, `HUD_LINES` | 30, 20 | HUD box ka size |
| `TILE_*` | `'#'`, `'T'`... | Har tile ka character |
| `CH_WALL` = 178, `CH_FLOOR` = 250, `CH_FULL` = 219, `CH_LIGHT` = 176 | | Console (CP437) ke special characters: ▓ · █ ░ |
| `ST_PLAYING`=0, `ST_EXIT`=1, `ST_DEAD`=2, `ST_QUIT`=3, `ST_TIMEOUT`=4 | | Level ka status code |
| `MODE_CLASSIC`=0, `MODE_TIMED`=1 | | Game mode |
| `MAX_LB` | 10 | Leaderboard top 10 |
| `SAVE_MAGIC` | `31304854h` | Memory mein bytes `54 48 30 31` = **"TH01"**. Save file ki pehchaan |

### 6.2 Macros (lines 100–146)

Macro ek "copy-paste shortcut" hai. Jahan likho, assembler wahan poora code paste kar deta hai.

**`mPrint "text"`**: Bhai kam aese hoga k ye text ko `.data` mein ek naye label (`LOCAL theStr`, har baar unique naam) ke saath rakh deta hai, phir `.code` mein wapas aakar `edx` mein address daal kar `WriteString` call karta hai. `push/pop edx` is liye ke edx kharab na ho.
→ Fayda: har message ke liye alag `BYTE` variable banane ki zaroorat nahi.

**`mColor colour`**: `eax` mein colour daal kar `SetColor` call. eax save/restore hota hai.

**`mGoto col, row`**: `dl = col`, `dh = row`, phir Irvine ka `Gotoxy` → cursor us jagah chala jata hai.

**`mHud line, col`**: HUD box ke **andar** ki position par cursor le jata hai (`HudGoto` ko call karke). Line 0 = HUD ki pehli line.

**`mBeep freq, duration`**: Windows API `Beep` ko `INVOKE` karta hai. Kyun ke Windows functions `eax, ecx, edx` kharab kar dete hain, is liye pehle push, baad mein pop.

### 6.3 Data Section (lines 151–313)

**File names + pointer table:**
```asm
levelFiles DWORD OFFSET level1File, OFFSET level2File, OFFSET level3File
```
Ye **pointers ka array** hai. `levelFiles[(level-1)*4]` se sahi file ka naam mil jata hai. (`*4` kyun ke DWORD = 4 bytes.) `levelNames` bhi aisa hi hai.

**Difficulty table (har level ka ek element):**
```asm
levelPar      DWORD 80, 110, 100    ; 3 stars ke liye steps
levelMoves    DWORD 150, 200, 200   ; time mode ki moves
randTreasures DWORD 2, 1, 1         ; random extra treasure
randTraps     DWORD 1, 3, 4         ; random extra traps
```

**Parallel arrays (tile → colour):**
```asm
tileChars  BYTE '@', '#', '.', 'T', 'X', 'E', 'H', 'P', 'K', 'D', 'A', '?'
tileColors BYTE lightGreen, lightGray, gray, yellow, lightRed, ...
```
Dono arrays ka index same hai. Agar `'T'` index 3 par hai, to uska colour `tileColors[3]` = yellow. `NUM_TILE_TYPES = ($ - tileChars)` = 12 (`$` matlab "abhi ka address", minus start = size).

**XOR key:** `"COAL-TREASURE-HUNT-2026"` (23 bytes). Encryption ke liye.

**🔑 Save block (bohat important):**
```asm
saveStart LABEL BYTE        ; ← yahan se
  saveMagic, playerName, gameMode, isCustom, level, score, health,
  steps, movesLeft, radarLeft, keysHeld, shieldOn, treasuresLeft,
  totalStars, playerRow, playerCol, mapRows, mapCols,
  grid (600 bytes), seen (600 bytes)
saveEnd LABEL BYTE          ; ← yahan tak
saveChecksum DWORD 0        ; bilkul baad mein
```
Bhai kam aese hoga k saari game state **memory mein ek saath, lagatar** rakhi gayi hai. Is liye save karna simple hai: `saveStart` se `saveChecksum` tak saare bytes uthao aur file mein likh do. Load par wapas usi jagah copy kar do. Game bilkul wahin se chalega. `LABEL BYTE` memory nahi leta, sirf ek naam (address) deta hai.

**Doosre variables:** `resumeFlag` (load kiya hua game?), `fogEnabled`, `hudX`/`msgRow` (layout), `msgPtr`/`msgColor` (neeche wala message), `lastColor` (abhi konsa colour set hai), `fileHandle`, `fileBuffer`, waghera.

**Leaderboard arrays (11 slots, 10 nahi!):**
```asm
lbNames  BYTE  11 * 17 DUP(0)   ; har naam 17 bytes (16 + null)
lbLevels DWORD 11 DUP(0)
lbScores DWORD 11 DUP(0)
```
Ek extra slot is liye ke naya player add karke sort karein, phir sab se kam wala (11th) nikal dein.

---

## 7. Har function ki explanation

> Format: **Kaam** (kya karta hai) → **Input/Output** → **Code logic step by step** → **Use cases**

---

### 7.1 `main` (line 321)

**Kaam:** Program yahan se shuru hota hai. Main menu baar baar dikhata hai jab tak Exit na dabao.

**Logic:**
1. `call Randomize`: random number generator ko seed karta hai (time se), taa ke har baar random items alag jagah aayen.
2. `menu_loop:` → `ShowMainMenu` call, jo `AL` mein `'1'`–`'6'` wapas deta hai.
3. `cmp al,'1' / jne opt2` style ki **if-else chain**:
   - `'1'` → `isCustom = 0`, `NewGame`
   - `'2'` → `LoadGame`
   - `'3'` → `LoadLeaderboard` + `ShowLeaderboard`
   - `'4'` → `MapEditorMenu`
   - `'5'` → `ShowHowToPlay`
   - `'6'` → screen clear, "Goodbye" print, `exit`
4. Har option ke baad `jmp menu_loop`, yani wapas menu.

---

### 7.2 Screen Helper Procedures

#### `SetColor` (line 369)
**Kaam:** Text ka colour badalta hai aur yaad rakhta hai.
**Input:** `EAX` = colour (foreground + background×16).
**Logic:** `lastColor = eax`, phir Irvine ka `SetTextColor`. `lastColor` ko `DrawCell` use karta hai taa ke same colour baar baar set na ho (speed ke liye).

#### `DrawBox` (line 379)
**Kaam:** Double-line wala box banata hai (`╔═╗ ║ ║ ╚═╝`) aur andar se khali (spaces) kar deta hai.
**Input (INVOKE parameters):** `pLeft, pTop, pWidth, pHeight`.
**Logic:**
1. `Gotoxy(pLeft, pTop)` → `201` (╔) likho → `pWidth` baar `205` (═) → `187` (╗).
2. `pHeight` baar (outer loop): ek line neeche jao, `186` (║) likho, `pWidth` spaces (inner **nested loop**, is liye `push ecx/pop ecx`), phir `186`.
3. Aakhri line: `200` (╚), `205` × width, `188` (╝).
**Use:** Main menu, notices, HUD, game over, leaderboard, har box isi se banta hai.

#### `HudGoto` (line 430)
**Kaam:** HUD ke andar ki relative position ko screen ki asal position mein badal kar cursor le jata hai.
**Input:** `DH` = HUD line, `DL` = HUD column.
**Logic:** `dl += hudX + 1` (box ki left deewar ke baad), `dh += MAP_Y + 1` (box ki top line ke baad). Phir `Gotoxy`.
**Fayda:** Map chhota/bara ho, HUD khud adjust ho jata hai, code mein bas "line 3" likhna parta hai.

#### `HudSeparator` (line 442)
**Kaam:** HUD ke andar ek horizontal line `╟──────╢` banata hai.
**Input:** `DH` = HUD line. Characters 199, 196 (×30), 182.

#### `WritePad` (line 462)
**Kaam:** 4 spaces likhta hai.
**Kyun?** Agar score `100` tha aur ab `95` hai, to screen par `950` dikhega (purana `0` reh jayega). Number ke baad spaces likhne se purane digits mit jaate hain. Ye **flicker-free** drawing ka hissa hai (screen clear nahi karte).

#### `ShowNotice` (line 470)
**Kaam:** Screen clear karke ek box mein message dikhata hai aur key ka wait karta hai.
**Input:** `EDX` = message.
**Logic:** `pushad` (saare registers save) → Clrscr → DrawBox → message → `WaitMsg` ("Press any key...") → `popad`.
**Use:** "No saved game found", "Save file damaged", "Map saved", waghera.

#### `AbsEax` (line 490): ⭐ Bitwise trick
**Kaam:** `EAX` ki absolute value (|x|) **bina jump ke**.
```asm
cdq             ; EDX = 0 agar EAX positive, FFFFFFFFh (-1) agar negative
xor  eax, edx   ; positive: kuch nahi badla | negative: saare bits ulte (= -x-1)
sub  eax, edx   ; positive: -0 | negative: -(-1) = +1  →  -x-1+1 = -x = |x|
```
**Example:** EAX = -5 → cdq: EDX = -1 → xor: EAX = 4 → sub -1: EAX = 5 ✅
**Use:** Radar ka distance, random items ko start se door rakhna.

---

### 7.3 Menus

#### `ShowMainMenu` (line 505)
**Kaam:** Yellow box mein title + 6 options + group members ke naam.
**Output:** `AL` = `'1'`–`'6'`.
**Logic:** Sab `mGoto` + `mColor` + `mPrint` se draw hota hai. Phir `read_choice:` loop:
```asm
call ReadChar
cmp al,'1' / jb read_choice    ; '1' se chhota → dobara
cmp al,'6' / ja read_choice    ; '6' se bara → dobara
```
**Use case:** Ghalat key (jaise `x` ya `9`) dabao → kuch nahi hoga, wo phir se key ka intezar karega. Sahi key par echo + chhoti beep.

#### `ShowHowToPlay` (line 575)
**Kaam:** `howText` (ek lamba string jisme `0Dh,0Ah` = new line hain) print karta hai aur key ka wait.

#### `SetPlayerName` (line 597)
**Kaam:** User ka typed naam (`nameInput`) ko `playerName` mein copy karta hai, safe bana kar.
**Logic:**
1. `esi` = source, `edi` = destination, `ecx` = counter.
2. Har character: agar `0` (end) → ruko. Agar 16 characters ho gaye → ruko.
3. **Agar `,` hai to `_` bana do.** Kyun? Leaderboard file `naam,level,score` format mein hai. Naam mein comma aaya to file kharab ho jayegi.
4. End par null (0) lagao.
5. Agar kuch nahi likha tha (`ecx = 0`) → `Str_copy` se `"Player"` daal do.
**Use cases:** `"Ali,Khan"` → `"Ali_Khan"`. Khali → `"Player"`. 20 characters → pehle 16.

#### `NewGame` (line 629)
**Kaam:** Naam aur mode poochta hai, saare values reset karta hai, game shuru.
**Logic:**
1. Box draw, "Enter your name:" → `ReadString` (max `SIZEOF nameInput`) → `SetPlayerName`.
2. Mode: `ReadChar` loop jab tak `'1'` ya `'2'` na aaye. `gameMode = MODE_CLASSIC / MODE_TIMED`.
3. Reset: `score=0, health=100, level=1, totalStars=0, shieldOn=0, resumeFlag=0`.
4. `totalLevels = 3`, lekin agar `isCustom = 1` to `totalLevels = 1` (custom map ek hi level hai).
5. `call PlayGame`.
**Note:** `isCustom` caller set karta hai: main menu se 0, map editor se 1.

---

### 7.4 Game Flow

#### `PlayGame` (line 697): Levels ka manager
**Kaam:** Ek ke baad ek level chalata hai jab tak jeeto, maro, ya quit karo.
**Logic:**
```
game_loop:
  agar resumeFlag == 1 (load kiya hua game):
       resumeFlag = 0, sirf ComputeLayout (map pehle se memory mein hai)
  warna:
       LoadLevel (file se map) → agar CF=1 (error) → game_end
  PlayLevel → EAX = status
  status == ST_EXIT  → ShowLevelComplete, level++,
                       agar level <= totalLevels → game_loop
                       warna → ShowVictory
  status == ST_QUIT  → game_end (chup chaap wapas menu)
  baqi (DEAD/TIMEOUT)→ ShowGameOver
```
**Use cases:**
- Level 1 complete → level = 2 → `2 <= 3` → loop → level2.txt load.
- Level 3 complete → level = 4 → `4 > 3` → Victory.
- Custom map complete → level = 2 → `2 > 1` → Victory.
- Load kiya hua game → file se dobara load NAHI karta (warna collected treasures wapas aa jate).

#### `PlayLevel` (line 732): ⭐ Game Loop (dil)
**Kaam:** Ek level ka asal game loop: draw → key padho → action → repeat.
**Output:** `EAX` = `ST_EXIT / ST_DEAD / ST_TIMEOUT / ST_QUIT`.
**Logic:**
1. `DrawLevelScreen` (static cheezein ek baar), `RevealAround` (start ke aas paas fog hatao).
2. `key_loop:`
   - `RefreshScreen` (map + HUD + message dobara)
   - `ReadChar` → `GetCommand` (arrow/caps/Esc ko w/a/s/d/q mein badlo)
   - Purana message clear: `msgPtr = emptyStr`
   - **Direction set karna** (`EAX` = row change, `EBX` = col change):

     | Key | EAX (row) | EBX (col) |
     |---|---|---|
     | w | -1 | 0 |
     | s | +1 | 0 |
     | a | 0 | -1 |
     | d | 0 | +1 |
     → `jmp do_move`
   - `r` → `UseRadar`
   - `f` → `xor fogEnabled, 1` (**XOR toggle**: 1→0, 0→1) + message
   - `g` → `SaveGame`
   - `q` → `ConfirmQuit`, `return ST_QUIT`
   - Koi aur key → ignore, wapas loop.
3. `do_move:` → `TryMove`. Agar status abhi bhi `ST_PLAYING` → loop. Warna last position dikhao, 700ms `Delay` (taa ke player dekh sake kya hua), phir status return.

#### `GetCommand` (line 808)
**Kaam:** Raw key ko ek simple command letter mein badalta hai.
**Input:** Irvine ka `ReadChar` → `AL` = ASCII, `AH` = scan code.
**Logic:**
- **Arrow keys** ka ASCII `0` ya `0E0h` hota hai aur asal pehchaan `AH` (scan code) mein:
  `48h` = ↑ → `'w'`, `50h` = ↓ → `'s'`, `4Bh` = ← → `'a'`, `4Dh` = → → `'d'`. Koi aur special key → `0`.
- `27` (Esc) → `'q'`.
- `'A'`–`'Z'` → `add al, 32` → lowercase (ASCII mein capital aur small mein 32 ka farq hai).
**Fayda:** Baqi code ko sirf `w a s d r f g q` check karna parta hai.

#### `ConfirmQuit` (line 855)
**Kaam:** Quit se pehle poochta hai "Save your progress? (Y/N)".
**Logic:** Message line par sawal → `ReadChar` → `or al, 20h` (bit 5 on = lowercase, `Y`→`y`) → agar `'y'` to `SaveGame` + "saved" message + 900ms delay. Koi aur key = save nahi.

---

### 7.5 Movement aur Tile Effects

#### `TryMove` (line 880): ⭐ Move ka check
**Kaam:** Player ko ek cell hilane ki koshish. Deewar/band darwaza ho to rok do.
**Input:** `EAX` = row change, `EBX` = col change. **Output:** `EAX` = status.
**Logic step by step:**
1. `ECX = playerRow + EAX` (naya row), `EDX = playerCol + EBX` (naya col).
2. **Boundary check (smart trick):**
   ```asm
   cmp ecx, mapRows
   jae hit_wall        ; UNSIGNED compare
   ```
   Agar naya row `-1` ho gaya, to unsigned mein `-1` = `FFFFFFFFh` = bohat bara number, `jae` pakar lega. Ek hi compare se **dono** (neeche se bahar aur upar se bahar) check ho gaye. 👍
3. Index nikalo (`row*30+col`), tile padho.
4. **Wall (`#`)** → message "Ouch! A solid wall...", status PLAYING. **Step count nahi hota.**
5. **Door (`D`):**
   - `keysHeld == 0` → "The door is locked" + low beep, player wahin.
   - Warna `keysHeld--`, darwaza ko `'.'` (floor) bana do (hamesha ke liye khul gaya), "unlocked" message + beep, aur aage `move_ok`.
6. **`move_ok`:** `playerRow/Col` update, `steps++`, `RevealAround` (fog hatao), `ApplyCell` (us tile ka asar).
7. **Time Challenge:** Agar mode TIMED aur status abhi PLAYING:
   - `movesLeft--`. Agar 0 → `ST_TIMEOUT`.
   - Agar ≤ 10 aur koi aur message nahi hai → "Hurry! Only a few moves left!" (red).
**Use cases:**
- Exit wala move time mode mein move nahi khata (kyun ke status EXIT hai, timer check skip).
- Trap se mar gaye to bhi timer check skip.
- Deewar / locked door par na step badhta hai na move kam hota hai.

#### `ApplyCell` (line 956): ⭐ Har tile ka asar
**Kaam:** Player jis cell par khara hai uska effect lagata hai.
**Output:** `EAX` = status.
**Logic:** Tile padho aur `cmp/je` se sahi label par jao:

| Tile | Label | Kya hota hai |
|---|---|---|
| `T` | `got_treasure` | Cell = `'.'`, `score += 10`, `treasuresLeft--` (0 ho to nahi), yellow message, 2 high beeps (1200/1600 Hz) |
| `X` | `hit_trap` | Cell = `'.'` (**trap sirf ek baar**). Agar `shieldOn` → shield khatam, koi nuksan nahi. Warna score −5, health −20 (dono **0 se neeche nahi**), low beeps. Health 0 → `ST_DEAD` |
| `H` | `got_potion` | Cell = `'.'`, health +20, **100 se zyada ho to 100** |
| `P` | `use_portal` | `FindOtherPortal` → index. `div 30` se row/col, player wahan, fog reveal, 3 rising beeps. Doosra portal na ho → "no partner" |
| `K` | `got_key` | Cell = `'.'`, `keysHeld++` |
| `A` | `got_shield` | Cell = `'.'`, `shieldOn = 1` |
| `E` | `reach_exit` | `ST_EXIT` return |
| baqi (`.`) | | Kuch nahi, `ST_PLAYING` |

**Score/health 0 se neeche na jaye, ye trick:**
```asm
mov  eax, score
sub  eax, 5
jnc  score_ok     ; Carry nahi aaya = result positive, theek hai
xor  eax, eax     ; Carry aaya (borrow) = negative hota, 0 kar do
score_ok:
```
Unsigned subtraction mein agar bara number chhote se minus karo to **Carry Flag** set hota hai. Example: score 3 − 5 → carry → score = 0.

**Portal use case:** Portal par pohanchne ke baad player doosre P par khara hai. Wahan se hato aur phir wapas P par aao, to phir teleport ho jaoge (aage peeche aa ja sakte ho). Teleport ke baad doosre P par `ApplyCell` dobara nahi chalta (warna infinite loop).

#### `FindOtherPortal` (line 1097)
**Kaam:** Moujooda portal ke baad wala agla `P` dhoondta hai.
**Input:** `ESI` = current portal ka index. **Output:** `EAX` = doosre portal ka index, ya `-1`.
**Logic:** `eax = esi` se shuru, `eax++`, agar 600 tak pohancha to 0 par wapas (**wrap around**). Max 599 cells check. `P` mila → return. Nahi mila → -1.
**Use case:** 2 portals → hamesha ek doosre se jure. Agar 3 hon to cycle (1→2→3→1). Level 3 mein 2 portals hain (row 9 aur row 12), Level 2 mein bhi 2.

#### `RevealAround` (line 1120): Fog of War
**Kaam:** Player ke aas paas ka **3×3** area `seen = 1` kar deta hai.
**Logic:** **Nested loop**: rows `playerRow-1` se 3 rows, har row mein cols `playerCol-1` se 3 cols. Har cell: agar map ke andar (`jae` unsigned trick phir se, -1 bhi pakra jata hai) → `seen[index] = 1`.
```
 ?  ?  ?  ?  ?
 ?  ✓  ✓  ✓  ?
 ?  ✓  @  ✓  ?      ← ✓ = seen ho gaye
 ?  ✓  ✓  ✓  ?
```
Ek baar dekha cell hamesha dikhta rahega.

#### `UseRadar` (line 1151): Manhattan Distance
**Kaam:** Sab se qareeb treasure ka faasla nikal kar HOT/WARM/COLD batata hai.
**Logic:**
1. `radarLeft == 0` → "no charges left" + low beep, return (charge kam nahi hota).
2. `treasuresLeft == 0` → "no treasure left - head for EXIT" (**charge waste nahi hota**).
3. `radarLeft--`, `edi = FFFFFFFFh` (abhi tak ka "best" = infinity).
4. **Nested loop** poore map par: har `T` ke liye `|row - playerRow| + |col - playerCol|` (`AbsEax` do baar). Agar ye `edi` se chhota → `edi` = ye.
5. Result: `≤ 3` HOT (red, 3 beeps), `≤ 7` WARM (yellow), warna COLD (blue).
**Note:** Distance deewaron ko ignore karta hai (seedhi line ka grid faasla), asal raasta lamba ho sakta hai. Radar fog ke peeche wale treasures bhi dhoond leta hai.

---

### 7.6 Level Loading

#### `LoadLevel` (line 1229)
**Kaam:** Current level ki map file padh kar `grid` mein bharta hai.
**Output:** `CF = 0` success, `CF = 1` error (Carry Flag ko return value ki tarah use kiya).
**Logic:**
1. File naam: `isCustom` → `custom.txt`, warna `levelFiles[(level-1)*4]` (pointer table).
2. `OpenInputFile` → `INVALID_HANDLE_VALUE` = file nahi mili → error.
3. `ReadFromFile` (max 4096 bytes) → `fileLen` = kitne bytes aaye → `CloseFile`.
4. `ParseMap` → agar `mapRows` ya `mapCols` 0 → khali file → error.
5. `ResetLevelState`, (custom nahi hai to) `PlaceRandomItems`, `ComputeLayout`.
6. `clc` (CF=0) return.
**Error case:** Red box mein "could not load the map file: level2.txt" + kahan rakhni hai + `stc` (CF=1). PlayGame phir game khatam kar ke menu par aa jata hai.

#### `ParseMap` (line 1300): ⭐ String Parsing
**Kaam:** `fileBuffer` ka text → `grid` 2D array.
**Logic:**
1. **Poora grid `#` se bhar do:** `rep stosb` (AL ko EDI par ECX baar likho). Is se chhoti rows khud ba khud deewar se pad ho jaati hain.
2. `ebx` = row, `edx` = col, `esi` = text pointer, `ecx` = baqi bytes.
3. Har character:
   - `0Ah` (Line Feed) → row khatam. Agar is row mein kuch tha (`edx != 0`) → `row++`, `col=0`. **Khali lines skip.**
   - `0Dh` (Carriage Return) → ignore (Windows `\r\n` handle).
   - `≥ 80h` → ignore (UTF-8 BOM jo Notepad kabhi kabhi lagata hai).
   - `< ' '` → koi aur control character, ignore.
   - Row ≥ 20 ya col ≥ 30 → extra, ignore.
   - `' '` (space) → `'.'` floor.
   - `'a'–'z'` → `sub al, 32` uppercase (`t` bhi treasure).
   - `'S'` → `playerRow/Col` yahan set, `startFound=1`, cell ko `'.'` bana do.
   - `'T'` → `treasuresLeft++`.
   - `grid[row*30+col] = al`, `col++`. Agar `col > mapCols` → `mapCols = col` (**sab se lambi row = width**).
4. End: aakhri line mein `\n` nahi tha to bhi wo row count karo.
5. `S` nahi mila → `FindFirstOpenCell`.

#### `FindFirstOpenCell` (line 1394)
**Kaam:** Map mein `S` na ho to pehla `'.'` cell dhoond kar player wahan rakh do.
**Logic:** Nested loop row×col, pehla `TILE_FLOOR` milte hi `jmp open_done`.

#### `ResetLevelState` (line 1426)
**Kaam:** Har naye level par per-level cheezein reset.
**Logic:** `steps=0`, `radarLeft=3`, `keysHeld=0`, `seen` array ko 0 se bhar do (`rep stosb`, **poori fog wapas**), `movesLeft` = custom ho to 150 warna `levelMoves[level-1]`, welcome message.
**Note:** `health`, `score`, `shieldOn`, `totalStars` yahan reset **nahi** hote (wo poore game ke hain).

#### `PlaceRandomItems` (line 1454)
**Kaam:** Level ke hisaab se random treasure aur traps daalta hai.
**Logic:** `ecx = randTreasures[level-1]`, `bl = 'T'` → `PlaceRandomTiles`. Phir `randTraps` aur `'X'` ke saath.

#### `PlaceRandomTiles` (line 1472)
**Kaam:** `ECX` tiles (`BL` character) random khali cells par.
**Logic (har tile ke liye):**
1. Max 500 koshishen (`edi` counter). Infinite loop se bachne ke liye. Jagah na mile to chhor do.
2. `RandomRange(mapRows)` → row, `RandomRange(mapCols)` → col.
3. **Start se door:** Manhattan distance ≤ 2 → dobara try. (Taa ke shuru mein hi trap par na khare ho.)
4. Cell `'.'` nahi hai → dobara try. (Deewar ya kisi item par nahi rakhte.)
5. Tile rakho. Agar treasure hai to `treasuresLeft++`.
**Note:** `placeTile` variable mein BL save karte hain kyun ke beech mein `ebx` distance ke liye use hota hai.

#### `ComputeLayout` (line 1520)
**Kaam:** Map ke size ke hisaab se HUD aur message line ki position.
**Logic:**
- `hudX = mapCols × 2 + MAP_X + 2` (har cell screen par **2 characters** chaura hai, `shl eax,1` = ×2).
- `msgRow = max(mapRows, 22) + MAP_Y + 1` (map ya HUD, jo lamba ho, uske neeche).

#### `GetLevelName` (line 1539)
**Output:** `EDX` = "The Old Cellar" / "Crystal Caves" / "Dragon's Vault" / "Custom Map".

---

### 7.7 Drawing (Screen par cheezein banana)

**Flicker-free idea:** Bhai kam aese hoga k har move par `Clrscr` nahi karte (screen chamakti hai). Sirf ek baar `DrawLevelScreen` mein clear hoti hai, phir har move par `Gotoxy` se cursor ko sahi jagah le ja kar **upar se overwrite** karte hain.

#### `DrawLevelScreen` (line 1558)
**Kaam:** Level ke shuru mein wo cheezein jo badalti nahi: title bar, HUD box, labels (`PLAYER :`, `SCORE :`...), controls, separators, aur **legend** (har tile apne colour mein + naam).

#### `LegendItem` (line 1662)
**Kaam:** Legend ki ek entry: `AL` tile ko `DrawCell` se uske colour mein, phir `EDX` label light gray mein.

#### `RefreshScreen` (line 1674)
**Kaam:** `DrawMap` + `DrawHudValues` + `DrawMessage`. Har key ke baad yahi chalta hai.

#### `DrawMap` (line 1685)
**Kaam:** Poora maze draw.
**Logic:** Nested loop. Har row ke shuru mein `Gotoxy(MAP_X, MAP_Y + row)`. Har cell:
- Player ki position → `'@'`.
- Warna `grid[i]`. Agar `fogEnabled` aur `seen[i] == 0` → `'?'`.
- `DrawCell`.

#### `DrawCell` (line 1730): ⭐ String instruction
**Kaam:** Ek cell (2 characters) uske colour mein.
**Input:** `AL` = tile.
**Logic:**
1. **Colour dhoondna `repne scasb` se:**
   ```asm
   mov edi, OFFSET tileChars
   mov ecx, 12
   repne scasb          ; jab tak [edi] != al, edi++ aur ecx--
   ```
   Mil gaya to ZF=1. `EDI` ab match ke **ek aage** hai, is liye `edi - (OFFSET tileChars + 1)` = index. `tileColors[index]` = colour.
   Nahi mila → default lightGray. (`mov eax, lightGray` flags ko nahi chhedta, is liye `jne` sahi kaam karta hai.)
2. Agar colour `lastColor` jaisa hai → `SetColor` skip (**optimization**: Windows call slow hoti hai).
3. Character likhna:
   - `#` → `▓▓` (178 do baar), deewar thos lagti hai.
   - `.` → `· ` (250 + space).
   - Baqi → `T ` (character + space).

#### `HealthColor` (line 1769)
**Output:** `EAX` = health > 50 → lightGreen, > 20 → yellow, warna lightRed.

#### `DrawHudValues` (line 1784)
**Kaam:** HUD mein har value ko `VAL_COL` (10) column par likhta hai: naam, mode (TIME CHALLENGE red mein), `level / totalLevels`, score, health (colour ke saath) + `DrawHealthBar`, steps, moves (time mode mein; ≤10 ho to red; classic mein "no limit"), gold left, radar left, keys, shield ON/OFF.
Har number ke baad `WritePad` taa ke purane digits mit jayen.

#### `DrawHealthBar` (line 1883)
**Kaam:** `[███████░░░]` jaisa bar.
**Logic:** `health ÷ 10` (`div`) = full blocks (█, 219). Baqi `10 - full` = light blocks (░, 176) gray mein. `jecxz` = agar ECX 0 hai to loop skip (warna `loop` 0 se 4 billion baar chalta!).
**Example:** health 70 → 7 full + 3 light. Health 15 → 1 full + 9 light, red.

#### `DrawMessage` (line 1923)
**Kaam:** Map ke neeche message line likhta hai.
**Logic:** `Gotoxy(MAP_X, msgRow)` → colour → `WriteString(msgPtr)` → `Str_length` → `78 - length` spaces (purana lamba message mitane ke liye) → cursor ko 2 line neeche park karo (taa ke blinking cursor map par na dikhe).

---

### 7.8 Level Complete / Game Over / Victory

#### `ShowLevelComplete` (line 1956): Star Rating
**Kaam:** Stars nikalna, bonus dena, result screen.
**Logic:**
1. `ebx` = par (custom 60, warna `levelPar[level-1]`).
2. ```
   steps <= par              → 3 stars
   steps <= par + par/2      → 2 stars     (shr edx,1 = ÷2, phir + par = 1.5×par)
   warna                     → 1 star
   ```
3. `totalStars += stars`, `score += stars × 10`.
4. Screen: steps, par, rating (yellow `*` kamaye hue + gray `*` baqi), bonus, total score, health. 3 notes ki jingle (C-E-G: 523, 659, 784 Hz).
**Example Level 1 (par 80):** 75 steps → ⭐⭐⭐ +30. 110 steps → ⭐⭐ +20 (110 ≤ 120). 130 → ⭐ +10.

#### `ShowGameOver` (line 2050)
**Input:** `EAX` = `ST_DEAD` ya `ST_TIMEOUT`.
**Logic:** `levelReached = level`. Red box: "GAME OVER" + wajah ("health zero" ya "ran out of moves") + naam, level, score. Neeche jaate hue sad beeps. Phir (custom nahi hai to) `AddToLeaderboard` + `ShowLeaderboard`.

#### `ShowVictory` (line 2103)
**Logic:** `levelReached = totalLevels`. "CONGRATULATIONS" + score, stars (`x / totalLevels×3`), health. Victory jingle. Phir leaderboard (custom nahi to).

---

### 7.9 Save / Load (XOR Encryption)

#### `XorCrypt` (line 2169): ⭐ Encryption
**Kaam:** Buffer ke har byte ko key ke byte se XOR karta hai.
**Input:** `ESI` = buffer, `ECX` = size.
**Logic:**
```asm
mov al, xorKey[edx]   ; key ka edx-wa byte
xor [esi], al         ; data ko encrypt
inc esi / inc edx
agar edx == 23 → edx = 0   ; key repeat (repeating-key XOR)
```
**Magic:** `A XOR K XOR K = A`. Yani **wahi function encrypt bhi karta hai aur decrypt bhi**.
**Example:** Data `'T'` (54h) XOR key `'C'` (43h) = `17h` (kachra). Phir `17h XOR 43h = 54h` = `'T'` wapas ✅.

#### `ComputeChecksum` (line 2192): Tamper detection
**Kaam:** Poore data ka ek 32-bit "fingerprint".
**Logic:** `eax = 5381`, har byte: `rol eax, 5` (bits 5 jagah left ghumao, jo bahar gire wo right se andar) phir `xor eax, byte`.
**Kyun?** Agar koi save file mein ek bhi byte badle (jaise score), to checksum match nahi karega → "Save file damaged".

#### `SaveGame` (line 2210)
**Logic (4 steps):**
1. `ComputeChecksum(saveStart, SAVE_SIZE)` → `saveChecksum` mein (jo save block ke **bilkul baad** hai).
2. `XorCrypt(saveStart, SAVE_FILE_SIZE)`: memory mein hi encrypt (data + checksum dono).
3. `CreateOutputFile("savegame.txt")` → `WriteToFile` → `CloseFile`.
4. **Dobara `XorCrypt`** → memory wapas normal (warna game kharab ho jata!).
**Error case:** File na bane → phir bhi decrypt karte hain (zaroori!), aur red error message.

#### `LoadGame` (line 2254)
**Logic:**
1. File kholo. Nahi mili → notice "No saved game found".
2. `loadBuffer` mein padho (live game state mein **nahi**, pehle check karna hai).
3. Size `SAVE_FILE_SIZE` ke barabar nahi → corrupt.
4. `XorCrypt` → decrypt.
5. **Pehla check:** pehle 4 bytes `"TH01"` (SAVE_MAGIC)? Nahi → corrupt.
6. **Doosra check:** checksum dobara calculate karo, file wale se match? Nahi → corrupt.
7. Sab theek → `rep movsb` se `loadBuffer` → `saveStart` (live state).
8. `totalLevels` set, `resumeFlag = 1`, "Welcome back!" → `PlayGame`.
**Use cases:**
- Save file Notepad mein khol kar edit ki → checksum fail → "damaged or was edited".
- File delete → "No saved game found".
- Custom map ka save bhi load hota hai (`isCustom` save block mein hai).
- Grid + seen dono save hain → uthaye hue treasures wapas nahi aate, fog bhi wahi rehti hai.

---

### 7.10 Leaderboard

File format (`leaderboard.txt`):
```
Ali,3,185
Sara,2,90
Player,1,15
```

#### `ParseNumber` (line 2321)
**Kaam:** Text se number (jaise `"185"` → 185).
**Input:** `ESI` = text, `EDI` = text ka end. **Output:** `EAX` = number, `ESI` = number ke baad.
**Logic:** `eax = 0`. Har digit: `eax = eax × 10 + (char - '0')`. Non-digit par ruko.
**Example:** `"185"` → 0×10+1 = 1 → 1×10+8 = 18 → 18×10+5 = 185.

#### `AppendNumber` (line 2345)
**Kaam:** Ulta: number → text (`185` → `"185"`).
**Logic:** Baar baar `÷10`, remainder + `'0'` = digit. Lekin digits **ulte** aate hain (5, 8, 1), is liye har digit **stack par push**, phir pop karke likho → seedha order (1, 8, 5). Stack ka LIFO kaam aaya!

#### `LoadLeaderboard` (line 2368)
**Kaam:** File padh kar teen arrays (`lbNames`, `lbLevels`, `lbScores`) bharta hai.
**Logic:**
1. `lbCount = 0`. File nahi → khali leaderboard (koi error nahi).
2. Har line: `\r` `\n` skip. Naam `,` tak copy (max 16). Agar comma se pehle line khatam → **tooti line, ignore**.
3. `ParseNumber` → level, comma skip, `ParseNumber` → score. `lbCount++`.
4. Line ka baqi hissa skip.
5. Max 10 entries. End mein `SortLeaderboard`.

#### `SwapLbEntries` (line 2458)
**Kaam:** Entry `i` aur `i+1` ko aapas mein badalna (teeno arrays mein).
**Logic:** Score aur level `xchg` se swap. Naam (17 bytes) ek ek byte loop se swap.

#### `SortLeaderboard` (line 2488): ⭐ Bubble Sort
**Kaam:** Score ke hisaab se bare se chhota.
**Logic:**
```
passes = count - 1
har pass mein:
   i = 0 se (passes - 1) tak:
      agar score[i] < score[i+1] → swap
```
Har pass ke baad sab se chhota score neeche "bubble" ho jata hai. Inner loop ka `ecx` har pass mein ek kam hota hai (outer `ecx` ko `push/pop` karke). Kyun ke aakhri elements pehle hi sahi jagah hain.
**Example:** `[50, 90, 70]` → pass 1: `[90, 50, 70]` → `[90, 70, 50]` → pass 2: no swap. ✅

#### `SaveLeaderboard` (line 2518)
**Kaam:** Arrays ko text mein badal kar file mein likhna.
**Logic:** `fileBuffer` mein har entry: naam copy + `,` + `AppendNumber(level)` + `,` + `AppendNumber(score)` + `\r\n`. Phir `CreateOutputFile` + `WriteToFile` (size = `edi - OFFSET fileBuffer`).

#### `AddToLeaderboard` (line 2571)
**Kaam:** Naya score add.
**Logic:** `LoadLeaderboard` (purane 0–10) → slot `lbCount` (11th tak ja sakta hai, is liye array 11 ka hai) par naam/level/score → `lbCount++` → Sort → agar 11 ho gaye to `lbCount = 10` (sab se chhota khud nikal gaya) → `SaveLeaderboard`.
**Use case:** Agar tumhara score top 10 se kam hai → tum list mein nahi aaoge.

#### `ShowLeaderboard` (line 2597)
**Kaam:** Table: RANK, NAME, LEVEL, SCORE. **Pehla number gold (yellow)** mein. Khali ho to "No scores yet - be the first."

---

### 7.11 Map Editor

#### `MapEditorMenu` (line 2671)
**Kaam:** `[1]` naya map banao, `[2]` apna map khelo, `[3]` wapas.
**Logic:** `[1]` → `CreateCustomMap` → wapas isi menu. `[2]` → `isCustom = 1`, `NewGame`, phir `isCustom = 0` (reset zaroori!) → main menu. `[3]` → wapas.

#### `CreateCustomMap` (line 2724)
**Kaam:** User row by row map type karta hai, check hota hai, `custom.txt` mein save.
**Logic:**
1. Instructions + tiles ki list dikhao.
2. Har row (max 20): `"Row  1: "` → `ReadString` → agar **khali Enter** → khatam.
3. Max 30 characters lo. Har character: lowercase → uppercase, `S` gino (`edCountS`), `E` gino (`edCountE`), `fileBuffer` mein copy. Row ke end par `\r\n`.
4. **Validation:**
   - Ek bhi row nahi → "Nothing was entered".
   - `S` exactly 1 nahi ya `E` 0 → "Map needs exactly one S and at least one E. Not saved."
5. Sahi → `custom.txt` likho → "Saved! Choose [2] to play your map."

**Custom map ka example (ye type karo):**
```
##########
#S..T...##
#.##.##..#
#..X..H.E#
##########
```
**Custom map ke rules:** Random items nahi aate, par 60, time mode moves 150, leaderboard mein nahi jata.

---

## 8. Poora flow ek example se

**Situation:** Tum Level 1 mein ho, (1,8) par, aur `D` (right) dabaya. Agle cell (1,9) par `T` hai.

```
1. PlayLevel: ReadChar → AL = 'D'
2. GetCommand: 'D' capital → +32 → 'd'
3. msgPtr = emptyStr (purana message saaf)
4. 'd' match → EAX = 0, EBX = +1 → jmp do_move
5. TryMove:
     ECX = 1 + 0 = 1 (row),  EDX = 8 + 1 = 9 (col)
     1 < mapRows ✓, 9 < mapCols ✓
     index = 1*30 + 9 = 39 → grid[39] = 'T'
     'T' na wall hai na door → move_ok
     playerRow = 1, playerCol = 9, steps++
     RevealAround → (0..2, 8..10) seen = 1
     ApplyCell:
        grid[39] = 'T' → got_treasure
        grid[39] = '.'   (treasure utha liya)
        score += 10
        treasuresLeft--
        msgPtr = "You found a treasure! +10 score", colour yellow
        Beep 1200Hz, Beep 1600Hz  🔊
        EAX = ST_PLAYING
     Classic mode → timer skip
     return ST_PLAYING
6. PlayLevel: ST_PLAYING → key_loop
7. RefreshScreen:
     DrawMap → '@' ab (1,9) par, T gayab
     DrawHudValues → SCORE 10, GOLD 1 kam
     DrawMessage → yellow "You found a treasure!"
8. ReadChar → agli key ka intezar...
```

---

## 9. Saare use cases / edge cases

| # | Situation | Kya hoga | Kahan handle hota hai |
|---|---|---|---|
| 1 | Deewar ki taraf move | "Ouch!" message, step nahi badhta | `TryMove → hit_wall` |
| 2 | Map ke bahar jaane ki koshish | Deewar jaisa treat | `TryMove` unsigned `jae` |
| 3 | Door, key nahi | "Door is locked", wahin khare | `TryMove → door_locked` |
| 4 | Door, key hai | Key −1, door hamesha ke liye floor | `TryMove` |
| 5 | Trap, shield on | Shield khatam, koi nuksan nahi, trap gayab | `ApplyCell → hit_trap` |
| 6 | Trap, shield off | −20 health, −5 score, trap gayab | `ApplyCell` |
| 7 | Score 3 par trap | Score 0 (negative nahi) | `jnc` carry check |
| 8 | Health 20 par trap | Health 0 → Game Over | `ST_DEAD` |
| 9 | Health 90 par potion | 100 (110 nahi) | `got_potion` cap |
| 10 | Portal, partner hai | Teleport | `FindOtherPortal` |
| 11 | Portal, akela (custom map) | "no partner - nothing happens" | `portal_alone` |
| 12 | Radar, charges 0 | "no charges left" | `UseRadar` |
| 13 | Radar, treasure 0 | "head for the EXIT", charge bacha | `UseRadar` |
| 14 | Time mode, moves 10 se kam | Red warning + HUD red | `TryMove check_low` |
| 15 | Time mode, moves 0 | Game Over "ran out of moves" | `ST_TIMEOUT` |
| 16 | Time mode, aakhri move exit par | Level complete (exit pehle check) | `TryMove` |
| 17 | Q → Y | Save + menu | `ConfirmQuit` |
| 18 | Q → koi aur key | Bina save menu | `ConfirmQuit` |
| 19 | Level file missing | Red error box, menu | `LoadLevel → load_error` |
| 20 | Map file mein small letters / spaces | Uppercase / floor ban jate | `ParseMap` |
| 21 | Map file mein `S` nahi | Pehle khali cell se start | `FindFirstOpenCell` |
| 22 | Map ki rows chhoti-bari | Chhoti rows deewar se pad | `ParseMap` `rep stosb` |
| 23 | Save file edit ki | "damaged or was edited" | `LoadGame` checksum |
| 24 | Save file nahi | "No saved game found" | `LoadGame` |
| 25 | Naam mein comma | `_` ban jata | `SetPlayerName` |
| 26 | Naam khali | "Player" | `SetPlayerName` |
| 27 | 11va leaderboard score | Sab se kam wala nikal jata | `AddToLeaderboard` |
| 28 | Leaderboard file nahi | "No scores yet" | `LoadLeaderboard` |
| 29 | Custom map mein 2 S ya 0 E | Save nahi hota | `CreateCustomMap` |
| 30 | Custom map khatam | Leaderboard mein nahi | `ShowGameOver/ShowVictory` |
| 31 | Level change | Health/score/shield saath, keys/radar/fog reset | `ResetLevelState` |
| 32 | Random item ki jagah nahi mil rahi | 500 tries ke baad chhor do | `PlaceRandomTiles` |
| 33 | Menu mein ghalat key | Ignore, dobara wait | `ShowMainMenu` |
| 34 | Arrow keys | w/a/s/d ban jaati hain | `GetCommand` |

---

## 10. Viva sawal-jawab

**Q1. 2D array assembly mein kaise banaya?**
Ek 1D array (`grid`, 600 bytes), index = `row × MAX_COLS + col`. `imul` se multiply.

**Q2. Macros aur Procedures mein farq?**
Macro har jagah copy-paste hota hai (code bara, lekin call/ret ka overhead nahi). Procedure ek jagah hota hai, `call` se jump karta hai. Humare 5 macros: `mPrint, mColor, mGoto, mHud, mBeep`.

**Q3. `USES` aur `pushad` kya karte hain?**
`USES eax ebx` → assembler khud procedure ke shuru mein push aur `ret` se pehle pop daal deta hai. `pushad/popad` saare 8 general registers ek saath save/restore.

**Q4. XOR encryption kaise kaam karti hai?**
`data XOR key = encrypted`, `encrypted XOR key = data`. Same function dono kaam karta hai. Key repeat hoti hai (23 bytes).

**Q5. Checksum kyun lagaya?**
Taa ke koi save file edit kare to pata chal jaye. `rol eax,5` + `xor`. Ek byte bhi badle to poora checksum badal jata hai.

**Q6. Absolute value bina jump ke kaise?**
`cdq` → `xor eax,edx` → `sub eax,edx`. (Section 7.2 dekho.)

**Q7. `repne scasb` kya karta hai?**
AL ko `[EDI]` se compare, `EDI++`, `ECX--`, jab tak match na mile ya ECX 0 na ho. Humne tile ka colour dhoondne mein use kiya.

**Q8. `rep stosb` aur `rep movsb`?**
`stosb` = AL ko `[EDI]` par likho (ECX baar), array ko fill karne ke liye (grid ko `#` se, seen ko 0 se). `movsb` = `[ESI]` se `[EDI]` copy (load game mein).

**Q9. Screen flicker kyun nahi karti?**
Har move par `Clrscr` nahi, sirf `Gotoxy` se cursor le ja kar overwrite. Aur `lastColor` se colour change kam.

**Q10. Unsigned compare se negative check kaise hua?**
-1 unsigned mein `FFFFFFFFh` (4 billion), jo `mapRows` se bara hai, `jae` pakar leta hai.

**Q11. Sorting konsi aur kaise?**
Bubble sort, descending. Har pass mein adjacent compare + swap. Parallel arrays (naam, level, score) teeno ek saath swap.

**Q12. Number ko text mein kaise likha?**
`AppendNumber`: baar baar `div 10`, remainder + '0', stack par push (ulta order theek karne ke liye), phir pop.

**Q13. Windows API kaunsi use ki?**
`Beep` (`PROTO` se declare, `INVOKE` se call). Saath mein Irvine ke `SetTextColor`, `Gotoxy`, file functions.

**Q14. Fog toggle mein XOR kyun?**
`xor fogEnabled, 1` → 1 ho to 0, 0 ho to 1. Ek instruction mein toggle.

**Q15. Carry Flag ka use?**
(a) `LoadLevel` CF se success/fail batata hai (`clc/stc`, `jc`). (b) `sub` ke baad `jnc` se pata chalta hai result negative to nahi hua.

**Q16. Save mein poori state ek saath kaise likh di?**
Saare game variables memory mein `saveStart` aur `saveEnd` labels ke beech lagatar rakhe. `SAVE_SIZE = saveEnd - saveStart`. Ek hi `WriteToFile` call.

**Q17. Manhattan distance kya hai?**
`|x1-x2| + |y1-y2|`. Grid mein sirf up/down/left/right chal sakte hain, is liye ye sahi measure hai (deewarein ignore).

**Q18. Random generation kaise?**
`Randomize` (seed, ek baar main mein), `RandomRange(n)` → 0 se n-1. Start ke qareeb aur non-floor cells skip.

---

## 11. Teammates mein presentation kaise baantein

Suggestion (3 log, ~ barabar hissa):

| Member | Topic | Functions |
|---|---|---|
| **Kinza (Leader)** | Intro + demo + game flow + menus | `main`, `ShowMainMenu`, `NewGame`, `SetPlayerName`, `PlayGame`, `PlayLevel`, `GetCommand`, `ConfirmQuit`, macros |
| **Huzaifa** | Gameplay logic + drawing | `TryMove`, `ApplyCell`, `FindOtherPortal`, `RevealAround`, `UseRadar`, `AbsEax`, `DrawMap`, `DrawCell`, `DrawHudValues`, `DrawHealthBar`, star rating |
| **Mohak** | File handling + encryption + sorting + editor | `LoadLevel`, `ParseMap`, `PlaceRandomTiles`, `SaveGame`, `LoadGame`, `XorCrypt`, `ComputeChecksum`, leaderboard (bubble sort, Parse/AppendNumber), `CreateCustomMap` |

**Demo order (5 minute):**
1. Main menu dikhao → New Game → naam → Classic.
2. Level 1 khelo (Section 4 wala raasta), raste mein `R` (radar) aur `F` (fog off/on) dikhao.
3. `G` se save → `Q` → main menu → `[2] Load Game` → wahin se shuru (save/load proof).
4. `savegame.txt` Notepad mein khol kar dikhao: kachra hai = encrypted. Ek character badlo, save karo → Load → "damaged" message (checksum proof).
5. Trap par jao, health bar ka rang badalta dikhao.
6. Leaderboard dikhao.
7. Map Editor mein chhota map bana kar khelo.

---

**Bas bhai! Pehle khud 2-3 baar khelo, phir Section 7 code ke saath khol kar parho (line numbers diye hain). Section 10 ke sawal yaad kar lo, viva mein yahi aate hain. All the best! 🚀**
