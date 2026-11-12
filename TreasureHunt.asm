;=======================================================================
;   TREASURE HUNT ADVENTURE  -  Text-Based Console Game
;   COAL Project  |  MASM x86 (32-bit)  |  Irvine32 Library
;
;   Group Members:
;       Kinza Detho  (24K-3097)  - Group Leader
;       Huzaifa      (24K-3069)
;       Mohak        (25K-3002)
;
;   Features:
;     - Maze levels loaded from text files (level1.txt .. level3.txt)
;     - Treasure (T), Trap (X), Exit (E), Potion (H), Portal (P),
;       Key (K), Door (D), Shield (A)
;     - Fog of war, Treasure Radar, Star rating, Sound effects
;     - Save / Load game (savegame.txt) encrypted with XOR + checksum
;     - Sorted leaderboard (leaderboard.txt)
;     - Coloured console GUI (HUD panel, health bar, boxed menus)
;     - Map editor (custom.txt), Time Challenge mode, Inventory
;=======================================================================

INCLUDE Irvine32.inc
INCLUDELIB kernel32.lib

; Windows API: plays a tone (frequency in Hz, duration in ms)
Beep PROTO, dwFreq:DWORD, dwDuration:DWORD

;=======================================================================
;                              CONSTANTS
;=======================================================================
MAX_ROWS        = 20                    ; biggest map the game supports
MAX_COLS        = 30
MAP_SIZE        = MAX_ROWS * MAX_COLS
MAX_NAME        = 16                    ; longest player name
NUM_LEVELS      = 3
FILE_BUF_SIZE   = 4096

MAX_HEALTH      = 100
TREASURE_POINTS = 10
TRAP_PENALTY    = 5
TRAP_DAMAGE     = 20
POTION_HEAL     = 20
RADAR_USES      = 3
STAR_BONUS      = 10                    ; score bonus for every star
LOW_MOVES       = 10                    ; warn when this few moves are left

CUSTOM_PAR      = 60                    ; par steps for a custom map
CUSTOM_MOVES    = 150                   ; time-challenge moves for custom

; ----- screen layout -----
MAP_X           = 2                     ; screen column of the map
MAP_Y           = 2                     ; screen row of the map
HUD_WIDTH       = 30                    ; inner width of the HUD box
HUD_LINES       = 20                    ; inner height of the HUD box
VAL_COL         = 10                    ; column of the values in the HUD
MSG_WIDTH       = 78                    ; width of the message line

; ----- map tiles -----
TILE_WALL       = '#'
TILE_FLOOR      = '.'
TILE_START      = 'S'
TILE_TREASURE   = 'T'
TILE_TRAP       = 'X'
TILE_EXIT       = 'E'
TILE_POTION     = 'H'
TILE_PORTAL     = 'P'
TILE_KEY        = 'K'
TILE_DOOR       = 'D'
TILE_SHIELD     = 'A'
TILE_PLAYER     = '@'
TILE_FOG        = '?'

; ----- characters from the console code page (CP437) -----
CH_WALL         = 178                   ; dark shaded block
CH_FLOOR        = 250                   ; small middle dot
CH_FULL         = 219                   ; full block   (health bar)
CH_LIGHT        = 176                   ; light shade  (health bar)

; ----- level status codes -----
ST_PLAYING      = 0
ST_EXIT         = 1
ST_DEAD         = 2
ST_QUIT         = 3
ST_TIMEOUT      = 4

; ----- game modes -----
MODE_CLASSIC    = 0
MODE_TIMED      = 1

; ----- leaderboard -----
MAX_LB          = 10
LB_NAME_SIZE    = MAX_NAME + 1

SAVE_MAGIC      = 31304854h             ; "TH01" - marks a valid save

;=======================================================================
;                               MACROS
;=======================================================================

; Print a literal string (string is placed in the data segment)
mPrint MACRO pText
    LOCAL theStr
    .data
    theStr BYTE pText, 0
    .code
    push edx
    mov  edx, OFFSET theStr
    call WriteString
    pop  edx
ENDM

; Change the text colour (keeps every register)
mColor MACRO cAttr
    push eax
    mov  eax, cAttr
    call SetColor
    pop  eax
ENDM

; Move the cursor to (column, row)
mGoto MACRO gCol, gRow
    push edx
    mov  dl, gCol
    mov  dh, gRow
    call Gotoxy
    pop  edx
ENDM

; Move the cursor to a line/column inside the HUD box
mHud MACRO hLine, hCol
    push edx
    mov  dh, hLine
    mov  dl, hCol
    call HudGoto
    pop  edx
ENDM

; Play a sound with the Windows Beep function (keeps registers)
mBeep MACRO bFreq, bDur
    push eax
    push ecx
    push edx
    INVOKE Beep, bFreq, bDur
    pop  edx
    pop  ecx
    pop  eax
ENDM

;=======================================================================
;                                DATA
;=======================================================================
.data

; ---------------------------- files -----------------------------------
level1File   BYTE "level1.txt",0
level2File   BYTE "level2.txt",0
level3File   BYTE "level3.txt",0
customFile   BYTE "custom.txt",0
saveFile     BYTE "savegame.txt",0
boardFile    BYTE "leaderboard.txt",0
levelFiles   DWORD OFFSET level1File, OFFSET level2File, OFFSET level3File

levelName1   BYTE "The Old Cellar",0
levelName2   BYTE "Crystal Caves",0
levelName3   BYTE "Dragon's Vault",0
customName   BYTE "Custom Map",0
levelNames   DWORD OFFSET levelName1, OFFSET levelName2, OFFSET levelName3

; ------------------- difficulty table (per level) ---------------------
levelPar      DWORD 80, 110, 100        ; steps for a 3-star rating
levelMoves    DWORD 150, 200, 200       ; moves allowed in Time Challenge
randTreasures DWORD 2, 1, 1             ; extra random treasures
randTraps     DWORD 1, 3, 4             ; extra random traps

; --------------- tile colour table (parallel arrays) ------------------
tileChars  BYTE TILE_PLAYER, TILE_WALL, TILE_FLOOR, TILE_TREASURE
           BYTE TILE_TRAP, TILE_EXIT, TILE_POTION, TILE_PORTAL
           BYTE TILE_KEY, TILE_DOOR, TILE_SHIELD, TILE_FOG
NUM_TILE_TYPES = ($ - tileChars)
tileColors BYTE lightGreen, lightGray, gray, yellow
           BYTE lightRed, lightCyan, lightMagenta, lightBlue
           BYTE brown, (white + (brown * 16)), cyan, gray

; --------------------------- XOR key ----------------------------------
xorKey      BYTE "COAL-TREASURE-HUNT-2026"
XOR_KEY_LEN = ($ - xorKey)

; ======================================================================
;   GAME STATE  -  everything between saveStart and saveEnd is written
;   to savegame.txt (encrypted), so a saved game resumes exactly.
; ======================================================================
saveStart     LABEL BYTE
saveMagic     DWORD SAVE_MAGIC
playerName    BYTE  MAX_NAME + 1 DUP(0)
gameMode      DWORD MODE_CLASSIC
isCustom      DWORD 0
level         DWORD 1
score         DWORD 0
health        DWORD MAX_HEALTH
steps         DWORD 0
movesLeft     DWORD 0
radarLeft     DWORD RADAR_USES
keysHeld      DWORD 0
shieldOn      DWORD 0
treasuresLeft DWORD 0
totalStars    DWORD 0
playerRow     DWORD 0
playerCol     DWORD 0
mapRows       DWORD 0
mapCols       DWORD 0
grid          BYTE  MAP_SIZE DUP(TILE_WALL)     ; the maze (2D array)
seen          BYTE  MAP_SIZE DUP(0)             ; fog of war (visited)
saveEnd       LABEL BYTE
saveChecksum  DWORD 0                           ; written right after block

SAVE_SIZE      = (saveEnd - saveStart)
SAVE_FILE_SIZE = SAVE_SIZE + 4

; ------------------------- other variables ----------------------------
totalLevels   DWORD NUM_LEVELS
resumeFlag    DWORD 0           ; 1 = continue a loaded game
fogEnabled    DWORD 1
levelReached  DWORD 0
startFound    DWORD 0
placeTile     BYTE  0
hudX          BYTE  0           ; screen column of the HUD box
msgRow        BYTE  0           ; screen row of the message line
emptyStr      BYTE  0
msgPtr        DWORD OFFSET emptyStr
msgColor      DWORD lightGray
lastColor     DWORD -1
fileHandle    DWORD 0
fileLen       DWORD 0
curFilePtr    DWORD 0
edCountS      DWORD 0
edCountE      DWORD 0

fileBuffer    BYTE  FILE_BUF_SIZE DUP(0)
loadBuffer    BYTE  SAVE_FILE_SIZE DUP(0)
nameInput     BYTE  MAX_NAME + 2 DUP(0)
lineBuf       BYTE  MAX_COLS + 2 DUP(0)
defaultName   BYTE  "Player",0

; --------------------------- leaderboard ------------------------------
lbCount       DWORD 0
lbNames       BYTE  (MAX_LB + 1) * LB_NAME_SIZE DUP(0)
lbLevels      DWORD MAX_LB + 1 DUP(0)
lbScores      DWORD MAX_LB + 1 DUP(0)

; ---------------------------- messages --------------------------------
msgWelcome     BYTE "Explore the maze, collect treasure (T) and find the EXIT (E). Good luck!",0
msgWall        BYTE "Ouch! A solid wall blocks the way.",0
msgTreasure    BYTE "You found a treasure!  +10 score",0
msgTrap        BYTE "It's a trap!  -20 health, -5 score",0
msgShieldBlock BYTE "Your shield absorbed the trap! (shield used up)",0
msgPotion      BYTE "Health potion!  +20 health (max 100)",0
msgPortal      BYTE "Whoosh! The portal teleported you.",0
msgPortalDead  BYTE "This portal has no partner - nothing happens.",0
msgKey         BYTE "You picked up a key. Use it to open a door (D).",0
msgShield      BYTE "You found a shield! It will block the next trap.",0
msgDoorOpen    BYTE "You unlocked the door with your key!",0
msgDoorLocked  BYTE "The door is locked. Find a key (K) first.",0
msgExit        BYTE "You found the EXIT!",0
msgRadarHot    BYTE "RADAR: HOT! A treasure is very close (3 steps or less).",0
msgRadarWarm   BYTE "RADAR: WARM - a treasure is nearby (4 to 7 steps).",0
msgRadarCold   BYTE "RADAR: COLD - no treasure close by (more than 7 steps).",0
msgRadarEmpty  BYTE "RADAR: no charges left on this level.",0
msgRadarNone   BYTE "RADAR: no treasure left - head for the EXIT!",0
msgSaved       BYTE "Game saved to savegame.txt (encrypted with XOR).",0
msgSaveFail    BYTE "ERROR: could not write savegame.txt!",0
msgLoaded      BYTE "Saved game loaded. Welcome back!",0
msgFogOn       BYTE "Fog of war ON.",0
msgFogOff      BYTE "Fog of war OFF (demo view - whole map visible).",0
msgLowMoves    BYTE "Hurry! Only a few moves left!",0
msgQuitAsk     BYTE "Save your progress before quitting? (Y/N)",0

noticeNoSave   BYTE "No saved game found. Press G during a game to save.",0
noticeCorrupt  BYTE "Save file is damaged or was edited - cannot load it!",0
noticeNoMap    BYTE "Nothing was entered - the map was not saved.",0
noticeBadMap   BYTE "Map needs exactly one S and at least one E. Not saved.",0
noticeMapSaved BYTE "Saved to custom.txt! Choose [2] to play your map.",0
noticeMapFail  BYTE "ERROR: could not write custom.txt!",0

; ----------------------------- legend ---------------------------------
lgYou     BYTE "You  ",0
lgGold    BYTE "Gold  ",0
lgTrap    BYTE "Trap  ",0
lgExit    BYTE "Exit",0
lgPotion  BYTE "Potion  ",0
lgPortal  BYTE "Portal  ",0
lgKey     BYTE "Key",0
lgDoor    BYTE "Door  ",0
lgShield  BYTE "Shield  ",0
lgFog     BYTE "Fog",0

; --------------------------- how to play ------------------------------
howText BYTE "  GOAL",0Dh,0Ah
        BYTE "    Explore each maze, collect treasure and reach the EXIT (E).",0Dh,0Ah
        BYTE "    Finish all 3 levels to win and enter the leaderboard.",0Dh,0Ah,0Dh,0Ah
        BYTE "  CONTROLS",0Dh,0Ah
        BYTE "    W A S D / Arrow keys : move           R : treasure radar",0Dh,0Ah
        BYTE "    G : save game                         F : fog of war on/off",0Dh,0Ah
        BYTE "    Q / Esc : quit to the main menu",0Dh,0Ah,0Dh,0Ah
        BYTE "  TILES",0Dh,0Ah
        BYTE "    T  Treasure  +10 score               X  Trap  -20 health, -5 score",0Dh,0Ah
        BYTE "    H  Potion    +20 health (max 100)    P  Portal - jump to the other P",0Dh,0Ah
        BYTE "    K  Key       opens one door (D)      A  Shield - blocks the next trap",0Dh,0Ah
        BYTE "    E  Exit      go to the next level",0Dh,0Ah,0Dh,0Ah
        BYTE "  SPECIAL",0Dh,0Ah
        BYTE "    Fog of war : you only see the cells around you and places you visited.",0Dh,0Ah
        BYTE "    Radar      : HOT = 3 steps or less, WARM = 4 to 7, COLD = more (3 uses).",0Dh,0Ah
        BYTE "    Stars      : finish a level in few steps for up to 3 stars (+10 each).",0Dh,0Ah
        BYTE "    Time mode  : every level has a limited number of moves.",0Dh,0Ah
        BYTE "    Saves      : savegame.txt is XOR-encrypted, so it cannot be edited.",0Dh,0Ah,0

;=======================================================================
;                                CODE
;=======================================================================
.code

;-----------------------------------------------------------------------
main PROC
; Program entry: shows the main menu until the player chooses Exit.
;-----------------------------------------------------------------------
    call Randomize                  ; seed the random number generator

menu_loop:
    call ShowMainMenu               ; AL = '1'..'6'
    cmp  al, '1'
    jne  opt2
    mov  isCustom, 0
    call NewGame
    jmp  menu_loop
opt2:
    cmp  al, '2'
    jne  opt3
    call LoadGame
    jmp  menu_loop
opt3:
    cmp  al, '3'
    jne  opt4
    call LoadLeaderboard
    call ShowLeaderboard
    jmp  menu_loop
opt4:
    cmp  al, '4'
    jne  opt5
    call MapEditorMenu
    jmp  menu_loop
opt5:
    cmp  al, '5'
    jne  opt6
    call ShowHowToPlay
    jmp  menu_loop
opt6:
    mColor lightGray
    call Clrscr
    mColor yellow
    mPrint "Thanks for playing Treasure Hunt Adventure. Goodbye."
    call Crlf
    mColor lightGray
    exit
main ENDP

;=======================================================================
;                       SCREEN HELPER PROCEDURES
;=======================================================================

;-----------------------------------------------------------------------
SetColor PROC
; Sets the console text colour and remembers it.
; Receives: EAX = colour attribute (foreground + background*16)
;-----------------------------------------------------------------------
    mov  lastColor, eax
    call SetTextColor
    ret
SetColor ENDP

;-----------------------------------------------------------------------
DrawBox PROC USES eax ecx edx, pLeft:DWORD, pTop:DWORD, pWidth:DWORD, pHeight:DWORD
; Draws a double-line box (and clears its inside) in the current colour.
; Receives: top-left corner, inner width and inner height
;-----------------------------------------------------------------------
    mov  eax, pLeft
    mov  dl, al
    mov  eax, pTop
    mov  dh, al
    call Gotoxy
    mov  al, 201                    ; top-left corner
    call WriteChar
    mov  ecx, pWidth
    mov  al, 205                    ; horizontal double line
top_line:
    call WriteChar
    loop top_line
    mov  al, 187                    ; top-right corner
    call WriteChar

    mov  ecx, pHeight
side_lines:
    inc  dh
    call Gotoxy
    mov  al, 186                    ; vertical double line
    call WriteChar
    push ecx
    mov  ecx, pWidth
    mov  al, ' '
fill_inside:
    call WriteChar
    loop fill_inside
    pop  ecx
    mov  al, 186
    call WriteChar
    loop side_lines

    inc  dh
    call Gotoxy
    mov  al, 200                    ; bottom-left corner
    call WriteChar
    mov  ecx, pWidth
    mov  al, 205
bottom_line:
    call WriteChar
    loop bottom_line
    mov  al, 188                    ; bottom-right corner
    call WriteChar
    ret
DrawBox ENDP

;-----------------------------------------------------------------------
HudGoto PROC USES edx
; Moves the cursor inside the HUD box.
; Receives: DH = line inside the box (0 = first line), DL = column inside
;-----------------------------------------------------------------------
    add  dl, hudX
    inc  dl
    add  dh, MAP_Y + 1
    call Gotoxy
    ret
HudGoto ENDP

;-----------------------------------------------------------------------
HudSeparator PROC USES eax ecx edx
; Draws a horizontal divider across the HUD box.
; Receives: DH = line inside the box
;-----------------------------------------------------------------------
    add  dh, MAP_Y + 1
    mov  dl, hudX
    call Gotoxy
    mov  al, 199                    ; ||- junction
    call WriteChar
    mov  ecx, HUD_WIDTH
    mov  al, 196                    ; single horizontal line
sep_loop:
    call WriteChar
    loop sep_loop
    mov  al, 182                    ; -|| junction
    call WriteChar
    ret
HudSeparator ENDP

;-----------------------------------------------------------------------
WritePad PROC
; Writes a few spaces to erase old digits after a number.
;-----------------------------------------------------------------------
    mPrint "    "
    ret
WritePad ENDP

;-----------------------------------------------------------------------
ShowNotice PROC
; Shows a message in a box and waits for a key.
; Receives: EDX = message string (max 56 characters)
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr
    mColor lightCyan
    INVOKE DrawBox, 10, 7, 60, 5
    mColor white
    mGoto 13, 9
    call WriteString
    mColor gray
    mGoto 13, 11
    call WaitMsg
    popad
    ret
ShowNotice ENDP

;-----------------------------------------------------------------------
AbsEax PROC USES edx
; Absolute value using bitwise operations (no jumps).
; Receives: EAX = signed number    Returns: EAX = |EAX|
;-----------------------------------------------------------------------
    cdq                             ; EDX = 0 or FFFFFFFFh (sign of EAX)
    xor  eax, edx
    sub  eax, edx
    ret
AbsEax ENDP

;=======================================================================
;                              MENUS
;=======================================================================

;-----------------------------------------------------------------------
ShowMainMenu PROC
; Draws the main menu inside a box.
; Returns: AL = chosen option ('1'..'6')
;-----------------------------------------------------------------------
    mColor lightGray
    call Clrscr
    mColor yellow
    INVOKE DrawBox, 18, 1, 44, 19

    mGoto 28, 3
    mPrint "T R E A S U R E   H U N T"
    mColor lightCyan
    mGoto 32, 4
    mPrint "A D V E N T U R E"
    mColor gray
    mGoto 22, 6
    mPrint "------------------------------------"

    mColor yellow
    mGoto 30, 8
    mPrint "[1]"
    mColor white
    mPrint "  New Game"
    mColor yellow
    mGoto 30, 9
    mPrint "[2]"
    mColor white
    mPrint "  Load Game"
    mColor yellow
    mGoto 30, 10
    mPrint "[3]"
    mColor white
    mPrint "  Leaderboard"
    mColor yellow
    mGoto 30, 11
    mPrint "[4]"
    mColor white
    mPrint "  Map Editor"
    mColor yellow
    mGoto 30, 12
    mPrint "[5]"
    mColor white
    mPrint "  How to Play"
    mColor yellow
    mGoto 30, 13
    mPrint "[6]"
    mColor white
    mPrint "  Exit"

    mColor gray
    mGoto 24, 17
    mPrint "COAL Project - MASM x86 Assembly"
    mGoto 23, 18
    mPrint "Kinza Detho  *  Huzaifa  *  Mohak"

read_choice:
    mColor lightGreen
    mGoto 28, 15
    mPrint "Choose an option (1-6): "
    call ReadChar
    cmp  al, '1'
    jb   read_choice
    cmp  al, '6'
    ja   read_choice
    call WriteChar                  ; echo the choice
    mBeep 900, 40
    ret
ShowMainMenu ENDP

;-----------------------------------------------------------------------
ShowHowToPlay PROC
; Shows the instructions screen.
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr
    mColor yellow
    mGoto 2, 1
    mPrint "HOW TO PLAY - TREASURE HUNT ADVENTURE"
    mGoto 0, 3
    mColor white
    mov  edx, OFFSET howText
    call WriteString
    call Crlf
    mColor gray
    mPrint "  "
    call WaitMsg
    popad
    ret
ShowHowToPlay ENDP

;-----------------------------------------------------------------------
SetPlayerName PROC USES eax ecx esi edi
; Copies nameInput to playerName (max MAX_NAME chars). Commas are
; replaced so the leaderboard file stays valid. Empty name = "Player".
;-----------------------------------------------------------------------
    mov  esi, OFFSET nameInput
    mov  edi, OFFSET playerName
    xor  ecx, ecx
copy_char:
    mov  al, [esi]
    cmp  al, 0
    je   copy_done
    cmp  ecx, MAX_NAME
    jae  copy_done
    cmp  al, ','
    jne  store_char
    mov  al, '_'
store_char:
    mov  [edi], al
    inc  esi
    inc  edi
    inc  ecx
    jmp  copy_char
copy_done:
    mov  BYTE PTR [edi], 0
    cmp  ecx, 0
    jne  name_ok
    INVOKE Str_copy, ADDR defaultName, ADDR playerName
name_ok:
    ret
SetPlayerName ENDP

;-----------------------------------------------------------------------
NewGame PROC
; Asks for the player's name and game mode, then starts the game.
; (isCustom must be set by the caller: 0 = normal, 1 = custom map)
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr
    mColor lightCyan
    INVOKE DrawBox, 16, 3, 48, 12
    mColor yellow
    mGoto 33, 5
    mPrint "NEW ADVENTURE"
    mColor white
    mGoto 20, 7
    mPrint "Enter your name: "
    mColor lightGreen
    mov  edx, OFFSET nameInput
    mov  ecx, SIZEOF nameInput
    call ReadString
    call SetPlayerName

    mColor white
    mGoto 20, 9
    mPrint "Choose a game mode:"
    mColor yellow
    mGoto 20, 11
    mPrint "[1]"
    mColor white
    mPrint " Classic        - explore freely"
    mColor yellow
    mGoto 20, 12
    mPrint "[2]"
    mColor white
    mPrint " Time Challenge - limited moves"

choose_mode:
    call ReadChar
    cmp  al, '1'
    je   classic
    cmp  al, '2'
    jne  choose_mode
    mov  gameMode, MODE_TIMED
    jmp  init_game
classic:
    mov  gameMode, MODE_CLASSIC

init_game:
    mov  score, 0
    mov  health, MAX_HEALTH
    mov  level, 1
    mov  totalStars, 0
    mov  shieldOn, 0
    mov  resumeFlag, 0
    mov  totalLevels, NUM_LEVELS
    cmp  isCustom, 0
    je   start_game
    mov  totalLevels, 1
start_game:
    call PlayGame
    popad
    ret
NewGame ENDP

;=======================================================================
;                          GAME FLOW
;=======================================================================

;-----------------------------------------------------------------------
PlayGame PROC
; Runs the levels one after another until the player wins, dies or
; quits. If resumeFlag = 1 the current (loaded) level is continued.
;-----------------------------------------------------------------------
    pushad
game_loop:
    cmp  resumeFlag, 1
    je   resume_level
    call LoadLevel                  ; CF = 1 if the map could not load
    jc   game_end
    jmp  play_it
resume_level:
    mov  resumeFlag, 0
    call ComputeLayout
play_it:
    call PlayLevel                  ; EAX = level status
    cmp  eax, ST_EXIT
    je   level_done
    cmp  eax, ST_QUIT
    je   game_end
    call ShowGameOver               ; dead or out of moves
    jmp  game_end
level_done:
    call ShowLevelComplete
    inc  level
    mov  eax, level
    cmp  eax, totalLevels
    jbe  game_loop
    call ShowVictory
game_end:
    popad
    ret
PlayGame ENDP

;-----------------------------------------------------------------------
PlayLevel PROC USES ebx ecx edx esi edi
; The real-time game loop for one level: draw, read a key, act.
; Returns: EAX = ST_EXIT, ST_DEAD, ST_TIMEOUT or ST_QUIT
;-----------------------------------------------------------------------
    call DrawLevelScreen
    call RevealAround

key_loop:
    call RefreshScreen
    call ReadChar
    call GetCommand                 ; AL = command letter (or 0)
    mov  msgPtr, OFFSET emptyStr    ; clear the old message

    cmp  al, 'w'
    jne  key_s
    mov  eax, -1
    mov  ebx, 0
    jmp  do_move
key_s:
    cmp  al, 's'
    jne  key_a
    mov  eax, 1
    mov  ebx, 0
    jmp  do_move
key_a:
    cmp  al, 'a'
    jne  key_d
    mov  eax, 0
    mov  ebx, -1
    jmp  do_move
key_d:
    cmp  al, 'd'
    jne  key_r
    mov  eax, 0
    mov  ebx, 1
    jmp  do_move
key_r:
    cmp  al, 'r'
    jne  key_f
    call UseRadar
    jmp  key_loop
key_f:
    cmp  al, 'f'
    jne  key_g
    xor  fogEnabled, 1              ; toggle with XOR
    mov  msgPtr, OFFSET msgFogOn
    mov  msgColor, lightCyan
    cmp  fogEnabled, 0
    jne  key_loop
    mov  msgPtr, OFFSET msgFogOff
    jmp  key_loop
key_g:
    cmp  al, 'g'
    jne  key_q
    call SaveGame
    jmp  key_loop
key_q:
    cmp  al, 'q'
    jne  key_loop
    call ConfirmQuit
    mov  eax, ST_QUIT
    ret

do_move:
    call TryMove                    ; EAX = status after the move
    cmp  eax, ST_PLAYING
    je   key_loop
    push eax
    call RefreshScreen              ; show the final position
    mov  eax, 700
    call Delay
    pop  eax
    ret
PlayLevel ENDP

;-----------------------------------------------------------------------
GetCommand PROC
; Converts a key from ReadChar into a lowercase command letter.
; Arrow keys become w/a/s/d and Esc becomes q.
; Receives: AL = ASCII code, AH = scan code    Returns: AL = command
;-----------------------------------------------------------------------
    cmp  al, 0
    je   extended_key
    cmp  al, 0E0h
    je   extended_key
    cmp  al, 27                     ; Esc
    jne  check_upper
    mov  al, 'q'
    ret
check_upper:
    cmp  al, 'A'
    jb   cmd_done
    cmp  al, 'Z'
    ja   cmd_done
    add  al, 32                     ; to lowercase
cmd_done:
    ret
extended_key:
    cmp  ah, 48h                    ; up arrow
    jne  not_up
    mov  al, 'w'
    ret
not_up:
    cmp  ah, 50h                    ; down arrow
    jne  not_down
    mov  al, 's'
    ret
not_down:
    cmp  ah, 4Bh                    ; left arrow
    jne  not_left
    mov  al, 'a'
    ret
not_left:
    cmp  ah, 4Dh                    ; right arrow
    jne  not_right
    mov  al, 'd'
    ret
not_right:
    mov  al, 0
    ret
GetCommand ENDP

;-----------------------------------------------------------------------
ConfirmQuit PROC
; Asks whether to save before leaving the level.
;-----------------------------------------------------------------------
    pushad
    mov  msgPtr, OFFSET msgQuitAsk
    mov  msgColor, lightCyan
    call DrawMessage
    call ReadChar
    or   al, 20h                    ; to lowercase
    cmp  al, 'y'
    jne  no_save
    call SaveGame
    call DrawMessage
    mov  eax, 900
    call Delay
no_save:
    popad
    ret
ConfirmQuit ENDP

;=======================================================================
;                       MOVEMENT AND TILE EFFECTS
;=======================================================================

;-----------------------------------------------------------------------
TryMove PROC USES ebx ecx edx esi
; Moves the player one cell if the target is not a wall.
; Receives: EAX = row change (-1/0/1), EBX = column change (-1/0/1)
; Returns:  EAX = level status
;-----------------------------------------------------------------------
    mov  ecx, playerRow
    add  ecx, eax                   ; ECX = new row
    mov  edx, playerCol
    add  edx, ebx                   ; EDX = new column

    cmp  ecx, mapRows               ; unsigned compare also catches -1
    jae  hit_wall
    cmp  edx, mapCols
    jae  hit_wall

    mov  esi, ecx                   ; index = row * MAX_COLS + col
    imul esi, MAX_COLS
    add  esi, edx
    mov  al, grid[esi]
    cmp  al, TILE_WALL
    je   hit_wall
    cmp  al, TILE_DOOR
    jne  move_ok

    ; ----- a locked door: needs a key from the inventory -----
    cmp  keysHeld, 0
    je   door_locked
    dec  keysHeld
    mov  grid[esi], TILE_FLOOR
    mov  msgPtr, OFFSET msgDoorOpen
    mov  msgColor, lightGreen
    mBeep 700, 60
    mBeep 1000, 60

move_ok:
    mov  playerRow, ecx
    mov  playerCol, edx
    inc  steps
    call RevealAround
    call ApplyCell                  ; EAX = status
    cmp  eax, ST_PLAYING
    jne  move_done

    ; ----- Time Challenge: every move uses up time -----
    cmp  gameMode, MODE_TIMED
    jne  move_done
    dec  movesLeft
    cmp  movesLeft, 0
    jne  check_low
    mov  eax, ST_TIMEOUT
    jmp  move_done
check_low:
    cmp  movesLeft, LOW_MOVES
    ja   move_done
    cmp  msgPtr, OFFSET emptyStr
    jne  move_done
    mov  msgPtr, OFFSET msgLowMoves
    mov  msgColor, lightRed
move_done:
    ret

door_locked:
    mov  msgPtr, OFFSET msgDoorLocked
    mov  msgColor, brown
    mBeep 200, 80
    mov  eax, ST_PLAYING
    ret

hit_wall:
    mov  msgPtr, OFFSET msgWall
    mov  msgColor, gray
    mov  eax, ST_PLAYING
    ret
TryMove ENDP

;-----------------------------------------------------------------------
ApplyCell PROC USES ebx ecx edx esi
; Applies the effect of the tile the player is standing on.
; Returns: EAX = level status
;-----------------------------------------------------------------------
    mov  esi, playerRow
    imul esi, MAX_COLS
    add  esi, playerCol
    mov  al, grid[esi]

    cmp  al, TILE_TREASURE
    je   got_treasure
    cmp  al, TILE_TRAP
    je   hit_trap
    cmp  al, TILE_POTION
    je   got_potion
    cmp  al, TILE_PORTAL
    je   use_portal
    cmp  al, TILE_KEY
    je   got_key
    cmp  al, TILE_SHIELD
    je   got_shield
    cmp  al, TILE_EXIT
    je   reach_exit
    mov  eax, ST_PLAYING            ; empty floor: nothing happens
    ret

got_treasure:
    mov  grid[esi], TILE_FLOOR
    add  score, TREASURE_POINTS
    cmp  treasuresLeft, 0
    je   treasure_msg
    dec  treasuresLeft
treasure_msg:
    mov  msgPtr, OFFSET msgTreasure
    mov  msgColor, yellow
    mBeep 1200, 70                  ; high-pitched beep
    mBeep 1600, 90
    mov  eax, ST_PLAYING
    ret

hit_trap:
    mov  grid[esi], TILE_FLOOR      ; a trap only fires once
    cmp  shieldOn, 0
    je   no_shield
    mov  shieldOn, 0
    mov  msgPtr, OFFSET msgShieldBlock
    mov  msgColor, cyan
    mBeep 500, 120
    mov  eax, ST_PLAYING
    ret
no_shield:
    mov  eax, score                 ; score - 5 (never below 0)
    sub  eax, TRAP_PENALTY
    jnc  score_ok
    xor  eax, eax
score_ok:
    mov  score, eax
    mov  eax, health                ; health - 20 (never below 0)
    sub  eax, TRAP_DAMAGE
    jnc  health_ok
    xor  eax, eax
health_ok:
    mov  health, eax
    mov  msgPtr, OFFSET msgTrap
    mov  msgColor, lightRed
    mBeep 300, 150                  ; low-pitched beep
    mBeep 200, 200
    mov  eax, ST_PLAYING
    cmp  health, 0
    jne  trap_done
    mov  eax, ST_DEAD
trap_done:
    ret

got_potion:
    mov  grid[esi], TILE_FLOOR
    mov  eax, health
    add  eax, POTION_HEAL
    cmp  eax, MAX_HEALTH
    jbe  potion_ok
    mov  eax, MAX_HEALTH            ; cap at 100
potion_ok:
    mov  health, eax
    mov  msgPtr, OFFSET msgPotion
    mov  msgColor, lightMagenta
    mBeep 800, 60
    mBeep 1000, 60
    mov  eax, ST_PLAYING
    ret

use_portal:
    call FindOtherPortal            ; EAX = index of partner, -1 if none
    cmp  eax, -1
    je   portal_alone
    xor  edx, edx
    mov  ecx, MAX_COLS
    div  ecx                        ; EAX = row, EDX = column
    mov  playerRow, eax
    mov  playerCol, edx
    call RevealAround
    mov  msgPtr, OFFSET msgPortal
    mov  msgColor, lightBlue
    mBeep 600, 50
    mBeep 900, 50
    mBeep 1200, 50
    mov  eax, ST_PLAYING
    ret
portal_alone:
    mov  msgPtr, OFFSET msgPortalDead
    mov  msgColor, gray
    mov  eax, ST_PLAYING
    ret

got_key:
    mov  grid[esi], TILE_FLOOR
    inc  keysHeld
    mov  msgPtr, OFFSET msgKey
    mov  msgColor, brown
    mBeep 1000, 50
    mBeep 1300, 50
    mov  eax, ST_PLAYING
    ret

got_shield:
    mov  grid[esi], TILE_FLOOR
    mov  shieldOn, 1
    mov  msgPtr, OFFSET msgShield
    mov  msgColor, cyan
    mBeep 900, 60
    mBeep 1100, 60
    mov  eax, ST_PLAYING
    ret

reach_exit:
    mov  msgPtr, OFFSET msgExit
    mov  msgColor, lightCyan
    mov  eax, ST_EXIT
    ret
ApplyCell ENDP

;-----------------------------------------------------------------------
FindOtherPortal PROC USES ecx
; Searches the grid (wrapping around) for the next portal tile.
; Receives: ESI = index of the current portal
; Returns:  EAX = index of the other portal, or -1 if there is none
;-----------------------------------------------------------------------
    mov  ecx, MAP_SIZE - 1          ; look at every other cell once
    mov  eax, esi
search_next:
    inc  eax
    cmp  eax, MAP_SIZE
    jb   in_range
    xor  eax, eax                   ; wrap to the start of the grid
in_range:
    cmp  grid[eax], TILE_PORTAL
    je   portal_found
    dec  ecx
    jnz  search_next
    mov  eax, -1
portal_found:
    ret
FindOtherPortal ENDP

;-----------------------------------------------------------------------
RevealAround PROC USES eax ebx ecx edx
; Fog of war: marks the 3x3 block around the player as seen.
;-----------------------------------------------------------------------
    mov  ebx, playerRow
    dec  ebx                        ; start one row above
    mov  ecx, 3
reveal_row:
    cmp  ebx, mapRows               ; skips rows outside the map
    jae  next_reveal_row
    mov  edx, playerCol
    dec  edx
    push ecx
    mov  ecx, 3
reveal_col:
    cmp  edx, mapCols
    jae  next_reveal_col
    mov  eax, ebx
    imul eax, MAX_COLS
    add  eax, edx
    mov  seen[eax], 1
next_reveal_col:
    inc  edx
    loop reveal_col
    pop  ecx
next_reveal_row:
    inc  ebx
    loop reveal_row
    ret
RevealAround ENDP

;-----------------------------------------------------------------------
UseRadar PROC USES eax ebx ecx edx esi edi
; Treasure Radar: finds the nearest treasure with Manhattan distance
; |dx| + |dy| and reports HOT / WARM / COLD. 3 uses per level.
;-----------------------------------------------------------------------
    cmp  radarLeft, 0
    jne  has_charge
    mov  msgPtr, OFFSET msgRadarEmpty
    mov  msgColor, gray
    mBeep 200, 100
    ret
has_charge:
    cmp  treasuresLeft, 0
    jne  start_scan
    mov  msgPtr, OFFSET msgRadarNone
    mov  msgColor, lightCyan
    ret
start_scan:
    dec  radarLeft
    mov  edi, 0FFFFFFFFh            ; best distance so far
    xor  ebx, ebx                   ; row
scan_row:
    cmp  ebx, mapRows
    jae  scan_done
    xor  ecx, ecx                   ; column
scan_col:
    cmp  ecx, mapCols
    jae  scan_next_row
    mov  esi, ebx
    imul esi, MAX_COLS
    add  esi, ecx
    cmp  grid[esi], TILE_TREASURE
    jne  scan_next_col
    mov  eax, ebx
    sub  eax, playerRow
    call AbsEax                     ; |dy|
    mov  edx, eax
    mov  eax, ecx
    sub  eax, playerCol
    call AbsEax                     ; |dx|
    add  eax, edx                   ; Manhattan distance
    cmp  eax, edi
    jae  scan_next_col
    mov  edi, eax                   ; new nearest treasure
scan_next_col:
    inc  ecx
    jmp  scan_col
scan_next_row:
    inc  ebx
    jmp  scan_row

scan_done:
    cmp  edi, 3
    jbe  radar_hot
    cmp  edi, 7
    jbe  radar_warm
    mov  msgPtr, OFFSET msgRadarCold
    mov  msgColor, lightBlue
    mBeep 400, 150
    ret
radar_hot:
    mov  msgPtr, OFFSET msgRadarHot
    mov  msgColor, lightRed
    mBeep 1500, 60
    mBeep 1500, 60
    mBeep 1500, 60
    ret
radar_warm:
    mov  msgPtr, OFFSET msgRadarWarm
    mov  msgColor, yellow
    mBeep 1000, 100
    ret
UseRadar ENDP

;=======================================================================
;                          LEVEL LOADING
;=======================================================================

;-----------------------------------------------------------------------
LoadLevel PROC
; Reads the map file of the current level into the grid array.
; Returns: CF = 0 on success, CF = 1 on error (message already shown)
;-----------------------------------------------------------------------
    pushad
    cmp  isCustom, 0
    je   normal_level
    mov  edx, OFFSET customFile
    jmp  have_file
normal_level:
    mov  eax, level
    dec  eax
    mov  edx, levelFiles[eax*4]
have_file:
    mov  curFilePtr, edx
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   load_error
    mov  fileHandle, eax
    mov  edx, OFFSET fileBuffer
    mov  ecx, FILE_BUF_SIZE
    call ReadFromFile
    jnc  read_ok
    mov  eax, fileHandle
    call CloseFile
    jmp  load_error
read_ok:
    mov  fileLen, eax
    mov  eax, fileHandle
    call CloseFile

    call ParseMap
    cmp  mapRows, 0
    je   load_error
    cmp  mapCols, 0
    je   load_error

    call ResetLevelState
    cmp  isCustom, 0
    jne  no_random
    call PlaceRandomItems
no_random:
    call ComputeLayout
    popad
    clc
    ret

load_error:
    mColor lightGray
    call Clrscr
    mColor lightRed
    INVOKE DrawBox, 4, 4, 70, 7
    mGoto 7, 6
    mPrint "ERROR: could not load the map file: "
    mColor yellow
    mov  edx, curFilePtr
    call WriteString
    mColor white
    mGoto 7, 8
    mPrint "Put the level .txt files in the same folder as TreasureHunt.asm"
    mGoto 7, 9
    mPrint "(the Visual Studio project folder) and try again."
    mColor gray
    mGoto 7, 13
    call WaitMsg
    popad
    stc
    ret
LoadLevel ENDP

;-----------------------------------------------------------------------
ParseMap PROC
; String parsing: converts the text in fileBuffer into the 2D grid.
; Each line is one row. Handles CR/LF, spaces (= floor), lowercase
; letters and a UTF-8 BOM. Short rows are padded with walls.
;-----------------------------------------------------------------------
    pushad
    mov  edi, OFFSET grid           ; start with an all-wall grid
    mov  ecx, MAP_SIZE
    mov  al, TILE_WALL
    cld
    rep  stosb

    mov  mapRows, 0
    mov  mapCols, 0
    mov  treasuresLeft, 0
    mov  startFound, 0
    mov  esi, OFFSET fileBuffer
    mov  ecx, fileLen
    xor  ebx, ebx                   ; current row
    xor  edx, edx                   ; current column
    cmp  ecx, 0
    je   parse_end

parse_char:
    mov  al, [esi]
    inc  esi
    cmp  al, 0Ah                    ; line feed = end of row
    je   end_of_line
    cmp  al, 0Dh                    ; carriage return: ignore
    je   next_char
    cmp  al, 80h                    ; non-ASCII (BOM): ignore
    jae  next_char
    cmp  al, ' '
    jb   next_char                  ; other control chars: ignore
    cmp  ebx, MAX_ROWS
    jae  next_char
    cmp  edx, MAX_COLS
    jae  next_char

    cmp  al, ' '
    jne  not_space
    mov  al, TILE_FLOOR
not_space:
    cmp  al, 'a'
    jb   not_lower
    cmp  al, 'z'
    ja   not_lower
    sub  al, 32                     ; to uppercase
not_lower:
    cmp  al, TILE_START
    jne  not_start
    mov  playerRow, ebx
    mov  playerCol, edx
    mov  startFound, 1
    mov  al, TILE_FLOOR
not_start:
    cmp  al, TILE_TREASURE
    jne  store_tile
    inc  treasuresLeft
store_tile:
    mov  edi, ebx
    imul edi, MAX_COLS
    add  edi, edx
    mov  grid[edi], al
    inc  edx
    cmp  edx, mapCols
    jbe  next_char
    mov  mapCols, edx               ; widest row = map width
    jmp  next_char

end_of_line:
    cmp  edx, 0                     ; skip empty lines
    je   next_char
    inc  ebx
    xor  edx, edx
next_char:
    dec  ecx
    jnz  parse_char

parse_end:
    cmp  edx, 0                     ; last row had no line break
    je   rows_done
    inc  ebx
rows_done:
    mov  mapRows, ebx
    cmp  startFound, 0
    jne  parse_done
    call FindFirstOpenCell
parse_done:
    popad
    ret
ParseMap ENDP

;-----------------------------------------------------------------------
FindFirstOpenCell PROC USES eax ebx ecx
; Used when a map has no S: puts the player on the first open cell.
;-----------------------------------------------------------------------
    mov  playerRow, 0
    mov  playerCol, 0
    xor  ebx, ebx
open_row:
    cmp  ebx, mapRows
    jae  open_done
    xor  ecx, ecx
open_col:
    cmp  ecx, mapCols
    jae  open_next_row
    mov  eax, ebx
    imul eax, MAX_COLS
    add  eax, ecx
    cmp  grid[eax], TILE_FLOOR
    jne  open_next_col
    mov  playerRow, ebx
    mov  playerCol, ecx
    jmp  open_done
open_next_col:
    inc  ecx
    jmp  open_col
open_next_row:
    inc  ebx
    jmp  open_row
open_done:
    ret
FindFirstOpenCell ENDP

;-----------------------------------------------------------------------
ResetLevelState PROC USES eax ecx edi
; Resets the per-level values (steps, radar, keys, fog, moves).
;-----------------------------------------------------------------------
    mov  steps, 0
    mov  radarLeft, RADAR_USES
    mov  keysHeld, 0
    mov  edi, OFFSET seen           ; clear the fog-of-war array
    mov  ecx, MAP_SIZE
    xor  eax, eax
    cld
    rep  stosb

    cmp  isCustom, 0
    je   level_moves
    mov  movesLeft, CUSTOM_MOVES
    jmp  set_welcome
level_moves:
    mov  eax, level
    dec  eax
    mov  eax, levelMoves[eax*4]
    mov  movesLeft, eax
set_welcome:
    mov  msgPtr, OFFSET msgWelcome
    mov  msgColor, lightCyan
    ret
ResetLevelState ENDP

;-----------------------------------------------------------------------
PlaceRandomItems PROC USES eax ebx ecx
; Random generation: adds extra treasures and traps to empty cells.
; Later levels get more traps and fewer treasures.
;-----------------------------------------------------------------------
    mov  eax, level
    dec  eax
    mov  ecx, randTreasures[eax*4]
    mov  bl, TILE_TREASURE
    call PlaceRandomTiles
    mov  eax, level
    dec  eax
    mov  ecx, randTraps[eax*4]
    mov  bl, TILE_TRAP
    call PlaceRandomTiles
    ret
PlaceRandomItems ENDP

;-----------------------------------------------------------------------
PlaceRandomTiles PROC USES eax ebx ecx edx esi edi
; Places tiles on random floor cells that are not next to the start.
; Receives: ECX = how many, BL = tile character
;-----------------------------------------------------------------------
    mov  placeTile, bl
    cmp  ecx, 0
    je   place_done
place_one:
    mov  edi, 500                   ; attempts before giving up
try_cell:
    dec  edi
    jz   place_done
    mov  eax, mapRows
    call RandomRange                ; EAX = 0 .. rows-1
    mov  esi, eax
    mov  eax, mapCols
    call RandomRange                ; EAX = 0 .. cols-1
    mov  edx, eax

    mov  eax, esi                   ; keep the start area clear
    sub  eax, playerRow
    call AbsEax
    mov  ebx, eax
    mov  eax, edx
    sub  eax, playerCol
    call AbsEax
    add  eax, ebx
    cmp  eax, 2
    jbe  try_cell

    mov  eax, esi
    imul eax, MAX_COLS
    add  eax, edx
    cmp  grid[eax], TILE_FLOOR
    jne  try_cell
    mov  bl, placeTile
    mov  grid[eax], bl
    cmp  bl, TILE_TREASURE
    jne  placed
    inc  treasuresLeft
placed:
    dec  ecx
    jnz  place_one
place_done:
    ret
PlaceRandomTiles ENDP

;-----------------------------------------------------------------------
ComputeLayout PROC USES eax
; Works out where the HUD and the message line go for this map size.
;-----------------------------------------------------------------------
    mov  eax, mapCols
    shl  eax, 1                     ; every cell is 2 characters wide
    add  eax, MAP_X + 2
    mov  hudX, al

    mov  eax, mapRows
    cmp  eax, HUD_LINES + 2         ; HUD box height incl. borders
    jae  rows_bigger
    mov  eax, HUD_LINES + 2
rows_bigger:
    add  eax, MAP_Y + 1
    mov  msgRow, al
    ret
ComputeLayout ENDP

;-----------------------------------------------------------------------
GetLevelName PROC USES eax
; Returns: EDX = name of the current level
;-----------------------------------------------------------------------
    cmp  isCustom, 0
    je   normal_name
    mov  edx, OFFSET customName
    ret
normal_name:
    mov  eax, level
    dec  eax
    mov  edx, levelNames[eax*4]
    ret
GetLevelName ENDP

;=======================================================================
;                         DRAWING THE GAME
;=======================================================================

;-----------------------------------------------------------------------
DrawLevelScreen PROC
; Clears the screen and draws the parts that do not change during a
; level: title bar, HUD box, labels, controls and legend.
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr

    ; ----- title bar -----
    mGoto MAP_X, 0
    mColor yellow
    mPrint "TREASURE HUNT ADVENTURE"
    mColor gray
    mPrint "   -   "
    mColor lightCyan
    mPrint "Level "
    mov  eax, level
    call WriteDec
    mPrint ": "
    call GetLevelName
    call WriteString

    ; ----- HUD box -----
    mColor cyan
    movzx eax, hudX
    INVOKE DrawBox, eax, MAP_Y, HUD_WIDTH, HUD_LINES

    mColor lightGray
    mHud 0, 1
    mPrint "PLAYER :"
    mHud 1, 1
    mPrint "MODE   :"
    mHud 2, 1
    mPrint "LEVEL  :"
    mHud 3, 1
    mPrint "SCORE  :"
    mHud 4, 1
    mPrint "HEALTH :"
    mHud 6, 1
    mPrint "STEPS  :"
    mHud 7, 1
    mPrint "MOVES  :"
    mHud 8, 1
    mPrint "GOLD   :"
    mHud 9, 1
    mPrint "RADAR  :"
    mHud 10, 1
    mPrint "KEYS   :"
    mHud 11, 1
    mPrint "SHIELD :"

    mColor cyan
    mov  dh, 12
    call HudSeparator
    mColor white
    mHud 13, 1
    mPrint "WASD/Arrows : Move"
    mHud 14, 1
    mPrint "R : Radar     F : Fog"
    mHud 15, 1
    mPrint "G : Save      Q : Quit"
    mColor cyan
    mov  dh, 16
    call HudSeparator

    ; ----- legend (coloured like the map) -----
    mHud 17, 1
    mov  al, TILE_PLAYER
    mov  edx, OFFSET lgYou
    call LegendItem
    mov  al, TILE_TREASURE
    mov  edx, OFFSET lgGold
    call LegendItem
    mov  al, TILE_TRAP
    mov  edx, OFFSET lgTrap
    call LegendItem
    mov  al, TILE_EXIT
    mov  edx, OFFSET lgExit
    call LegendItem
    mHud 18, 1
    mov  al, TILE_POTION
    mov  edx, OFFSET lgPotion
    call LegendItem
    mov  al, TILE_PORTAL
    mov  edx, OFFSET lgPortal
    call LegendItem
    mov  al, TILE_KEY
    mov  edx, OFFSET lgKey
    call LegendItem
    mHud 19, 1
    mov  al, TILE_DOOR
    mov  edx, OFFSET lgDoor
    call LegendItem
    mov  al, TILE_SHIELD
    mov  edx, OFFSET lgShield
    call LegendItem
    mov  al, TILE_FOG
    mov  edx, OFFSET lgFog
    call LegendItem
    popad
    ret
DrawLevelScreen ENDP

;-----------------------------------------------------------------------
LegendItem PROC USES eax
; Draws one legend entry: the coloured tile followed by its label.
; Receives: AL = tile, EDX = label string
;-----------------------------------------------------------------------
    call DrawCell
    mov  eax, lightGray
    call SetColor
    call WriteString
    ret
LegendItem ENDP

;-----------------------------------------------------------------------
RefreshScreen PROC
; Redraws the changing parts without clearing the screen
; (flicker-free: the cursor is moved instead of using Clrscr).
;-----------------------------------------------------------------------
    call DrawMap
    call DrawHudValues
    call DrawMessage
    ret
RefreshScreen ENDP

;-----------------------------------------------------------------------
DrawMap PROC
; Draws the maze with colours. Hidden cells (fog of war) show as '?'.
;-----------------------------------------------------------------------
    pushad
    xor  ebx, ebx                   ; row
map_row:
    cmp  ebx, mapRows
    jae  map_done
    mov  dh, bl
    add  dh, MAP_Y
    mov  dl, MAP_X
    call Gotoxy
    xor  ecx, ecx                   ; column
map_col:
    cmp  ecx, mapCols
    jae  map_next_row
    mov  esi, ebx
    imul esi, MAX_COLS
    add  esi, ecx
    cmp  ebx, playerRow
    jne  not_player
    cmp  ecx, playerCol
    jne  not_player
    mov  al, TILE_PLAYER
    jmp  draw_it
not_player:
    mov  al, grid[esi]
    cmp  fogEnabled, 0
    je   draw_it
    cmp  seen[esi], 0
    jne  draw_it
    mov  al, TILE_FOG               ; not discovered yet
draw_it:
    call DrawCell
    inc  ecx
    jmp  map_col
map_next_row:
    inc  ebx
    jmp  map_row
map_done:
    popad
    ret
DrawMap ENDP

;-----------------------------------------------------------------------
DrawCell PROC USES eax ecx edi
; Draws one map cell (2 characters wide) in the colour of its tile.
; The colour is looked up in the tileChars / tileColors arrays.
; Receives: AL = tile character
;-----------------------------------------------------------------------
    push eax
    mov  edi, OFFSET tileChars
    mov  ecx, NUM_TILE_TYPES
    cld
    repne scasb                     ; search the tile in the table
    mov  eax, lightGray             ; default colour (flags unchanged)
    jne  color_ready
    sub  edi, OFFSET tileChars + 1  ; EDI = index of the tile
    movzx eax, tileColors[edi]
color_ready:
    cmp  eax, lastColor             ; only change colour when needed
    je   same_color
    call SetColor
same_color:
    pop  eax

    cmp  al, TILE_WALL
    jne  not_wall
    mov  al, CH_WALL
    call WriteChar
    call WriteChar
    ret
not_wall:
    cmp  al, TILE_FLOOR
    jne  write_tile
    mov  al, CH_FLOOR
write_tile:
    call WriteChar
    mov  al, ' '
    call WriteChar
    ret
DrawCell ENDP

;-----------------------------------------------------------------------
HealthColor PROC
; Returns: EAX = green (>50), yellow (>20) or red, based on health
;-----------------------------------------------------------------------
    mov  eax, lightGreen
    cmp  health, 50
    ja   hc_done
    mov  eax, yellow
    cmp  health, 20
    ja   hc_done
    mov  eax, lightRed
hc_done:
    ret
HealthColor ENDP

;-----------------------------------------------------------------------
DrawHudValues PROC
; Writes the current values into the HUD panel.
;-----------------------------------------------------------------------
    pushad
    mColor white
    mHud 0, VAL_COL
    mov  edx, OFFSET playerName
    call WriteString

    mHud 1, VAL_COL
    cmp  gameMode, MODE_TIMED
    je   mode_timed
    mPrint "CLASSIC"
    jmp  mode_shown
mode_timed:
    mColor lightRed
    mPrint "TIME CHALLENGE"
mode_shown:
    mColor white
    mHud 2, VAL_COL
    mov  eax, level
    call WriteDec
    mPrint " / "
    mov  eax, totalLevels
    call WriteDec

    mColor yellow
    mHud 3, VAL_COL
    mov  eax, score
    call WriteDec
    call WritePad

    call HealthColor
    call SetColor
    mHud 4, VAL_COL
    mov  eax, health
    call WriteDec
    mPrint " / 100"
    call WritePad
    call DrawHealthBar

    mColor white
    mHud 6, VAL_COL
    mov  eax, steps
    call WriteDec
    call WritePad

    mHud 7, VAL_COL
    cmp  gameMode, MODE_TIMED
    je   show_moves
    mColor gray
    mPrint "no limit"
    jmp  moves_shown
show_moves:
    mColor white
    cmp  movesLeft, LOW_MOVES
    ja   moves_color_ok
    mColor lightRed
moves_color_ok:
    mov  eax, movesLeft
    call WriteDec
    mPrint " left"
    call WritePad
moves_shown:
    mColor yellow
    mHud 8, VAL_COL
    mov  eax, treasuresLeft
    call WriteDec
    mPrint " left"
    call WritePad

    mColor lightRed
    mHud 9, VAL_COL
    mov  eax, radarLeft
    call WriteDec
    mPrint " left"
    call WritePad

    mColor brown
    mHud 10, VAL_COL
    mov  eax, keysHeld
    call WriteDec
    call WritePad

    mHud 11, VAL_COL
    cmp  shieldOn, 0
    je   shield_off
    mColor cyan
    mPrint "ON "
    jmp  shield_shown
shield_off:
    mColor gray
    mPrint "OFF"
shield_shown:
    popad
    ret
DrawHudValues ENDP

;-----------------------------------------------------------------------
DrawHealthBar PROC
; Health bar: one full block for every 10 health, light blocks for the
; missing part, e.g. [######----]
;-----------------------------------------------------------------------
    pushad
    mHud 5, 1
    call HealthColor
    call SetColor
    mov  al, '['
    call WriteChar
    mov  eax, health
    xor  edx, edx
    mov  ecx, 10
    div  ecx                        ; EAX = number of full blocks
    mov  ebx, eax
    mov  ecx, eax
    jecxz empty_part
    mov  al, CH_FULL
full_loop:
    call WriteChar
    loop full_loop
empty_part:
    mColor gray
    mov  ecx, 10
    sub  ecx, ebx
    jecxz close_bar
    mov  al, CH_LIGHT
empty_loop:
    call WriteChar
    loop empty_loop
close_bar:
    call HealthColor
    call SetColor
    mov  al, ']'
    call WriteChar
    popad
    ret
DrawHealthBar ENDP

;-----------------------------------------------------------------------
DrawMessage PROC
; Writes the current message under the map and parks the cursor.
;-----------------------------------------------------------------------
    pushad
    mov  dh, msgRow
    mov  dl, MAP_X
    call Gotoxy
    mov  eax, msgColor
    call SetColor
    mov  edx, msgPtr
    call WriteString
    INVOKE Str_length, edx          ; EAX = length of the message
    mov  ecx, MSG_WIDTH
    sub  ecx, eax                   ; pad the rest of the line
    jbe  msg_parked
    mov  al, ' '
pad_loop:
    call WriteChar
    loop pad_loop
msg_parked:
    mov  dh, msgRow
    add  dh, 2
    mov  dl, 0
    call Gotoxy
    popad
    ret
DrawMessage ENDP

;=======================================================================
;                    END OF LEVEL / END OF GAME SCREENS
;=======================================================================

;-----------------------------------------------------------------------
ShowLevelComplete PROC
; Star rating: 3 stars if steps <= par, 2 if steps <= 1.5 * par,
; otherwise 1 star. Every star gives a score bonus.
;-----------------------------------------------------------------------
    pushad
    cmp  isCustom, 0
    je   level_par
    mov  ebx, CUSTOM_PAR
    jmp  have_par
level_par:
    mov  eax, level
    dec  eax
    mov  ebx, levelPar[eax*4]       ; EBX = par steps
have_par:
    mov  ecx, 3
    mov  eax, steps
    cmp  eax, ebx
    jbe  stars_done
    mov  ecx, 2
    mov  edx, ebx
    shr  edx, 1
    add  edx, ebx                   ; EDX = par * 1.5
    cmp  eax, edx
    jbe  stars_done
    mov  ecx, 1
stars_done:
    add  totalStars, ecx
    mov  esi, ecx                   ; ESI = stars
    mov  eax, ecx
    imul eax, STAR_BONUS
    add  score, eax
    mov  edi, eax                   ; EDI = bonus

    mColor lightGray
    call Clrscr
    mColor lightGreen
    INVOKE DrawBox, 18, 3, 44, 14
    mColor yellow
    mGoto 31, 5
    mPrint "LEVEL "
    mov  eax, level
    call WriteDec
    mPrint " COMPLETE"

    mColor white
    mGoto 24, 7
    mPrint "Steps taken   : "
    mov  eax, steps
    call WriteDec
    mGoto 24, 8
    mPrint "Par (3 stars) : "
    mov  eax, ebx
    call WriteDec
    mGoto 24, 9
    mPrint "Rating        : "
    mColor yellow
    mov  ecx, esi
gold_star:
    mPrint "* "
    loop gold_star
    mColor gray
    mov  ecx, 3
    sub  ecx, esi
    jecxz stars_shown
gray_star:
    mPrint "* "
    loop gray_star
stars_shown:
    mColor white
    mGoto 24, 10
    mPrint "Star bonus    : +"
    mov  eax, edi
    call WriteDec
    mGoto 24, 11
    mPrint "Total score   : "
    mov  eax, score
    call WriteDec
    mGoto 24, 12
    mPrint "Health        : "
    mov  eax, health
    call WriteDec

    mBeep 523, 100
    mBeep 659, 100
    mBeep 784, 160

    mColor gray
    mGoto 24, 15
    call WaitMsg
    popad
    ret
ShowLevelComplete ENDP

;-----------------------------------------------------------------------
ShowGameOver PROC
; Game over screen.  Receives: EAX = ST_DEAD or ST_TIMEOUT
;-----------------------------------------------------------------------
    pushad
    mov  ebx, eax
    mov  eax, level
    mov  levelReached, eax

    mColor lightGray
    call Clrscr
    mColor lightRed
    INVOKE DrawBox, 18, 3, 44, 12
    mGoto 31, 5
    mPrint "G A M E   O V E R"
    mColor white
    mGoto 23, 7
    cmp  ebx, ST_TIMEOUT
    je   out_of_moves
    mPrint "Your health dropped to zero."
    jmp  reason_shown
out_of_moves:
    mPrint "You ran out of moves."
reason_shown:
    mGoto 23, 9
    mPrint "Player        : "
    mov  edx, OFFSET playerName
    call WriteString
    mGoto 23, 10
    mPrint "Level reached : "
    mov  eax, levelReached
    call WriteDec
    mGoto 23, 11
    mPrint "Final score   : "
    mov  eax, score
    call WriteDec

    mBeep 400, 200
    mBeep 300, 200
    mBeep 200, 400

    mColor gray
    mGoto 23, 13
    call WaitMsg
    cmp  isCustom, 0
    jne  go_done
    call AddToLeaderboard
    call ShowLeaderboard
go_done:
    popad
    ret
ShowGameOver ENDP

;-----------------------------------------------------------------------
ShowVictory PROC
; Shown after the last level: congratulations + leaderboard.
;-----------------------------------------------------------------------
    pushad
    mov  eax, totalLevels
    mov  levelReached, eax

    mColor lightGray
    call Clrscr
    mColor yellow
    INVOKE DrawBox, 14, 3, 52, 13
    mGoto 24, 5
    mPrint "* * *   C O N G R A T U L A T I O N S   * * *"
    mColor lightGreen
    mGoto 20, 7
    cmp  isCustom, 0
    jne  custom_win
    mPrint "You escaped the vault with all the treasure."
    jmp  win_text_done
custom_win:
    mPrint "You completed your custom map."
win_text_done:
    mColor white
    mGoto 24, 9
    mPrint "Player       : "
    mov  edx, OFFSET playerName
    call WriteString
    mGoto 24, 10
    mPrint "Final score  : "
    mov  eax, score
    call WriteDec
    mGoto 24, 11
    mPrint "Total stars  : "
    mov  eax, totalStars
    call WriteDec
    mPrint " / "
    mov  eax, totalLevels
    imul eax, 3
    call WriteDec
    mGoto 24, 12
    mPrint "Health left  : "
    mov  eax, health
    call WriteDec

    mBeep 523, 120
    mBeep 659, 120
    mBeep 784, 120
    mBeep 1047, 300

    mColor gray
    mGoto 24, 14
    call WaitMsg
    cmp  isCustom, 0
    jne  win_done
    call AddToLeaderboard
    call ShowLeaderboard
win_done:
    popad
    ret
ShowVictory ENDP

;=======================================================================
;              SAVE / LOAD  (file handling + XOR encryption)
;=======================================================================

;-----------------------------------------------------------------------
XorCrypt PROC USES eax ecx edx esi
; Encrypts or decrypts a buffer with a repeating XOR key.
; (XOR twice with the same key gives back the original data.)
; Receives: ESI = buffer, ECX = number of bytes
;-----------------------------------------------------------------------
    xor  edx, edx                   ; position in the key
    cmp  ecx, 0
    je   crypt_done
crypt_loop:
    mov  al, xorKey[edx]
    xor  [esi], al
    inc  esi
    inc  edx
    cmp  edx, XOR_KEY_LEN
    jb   key_ok
    xor  edx, edx                   ; restart the key
key_ok:
    loop crypt_loop
crypt_done:
    ret
XorCrypt ENDP

;-----------------------------------------------------------------------
ComputeChecksum PROC USES ebx ecx esi
; Simple checksum (rotate + XOR) to detect edited save files.
; Receives: ESI = buffer, ECX = length     Returns: EAX = checksum
;-----------------------------------------------------------------------
    mov  eax, 5381
    cmp  ecx, 0
    je   sum_done
sum_loop:
    rol  eax, 5
    movzx ebx, BYTE PTR [esi]
    xor  eax, ebx
    inc  esi
    loop sum_loop
sum_done:
    ret
ComputeChecksum ENDP

;-----------------------------------------------------------------------
SaveGame PROC USES eax ecx edx esi
; Saves the whole game state to savegame.txt:
;   1. checksum the data   2. XOR-encrypt it in memory
;   3. write it to the file   4. XOR again to get the data back
;-----------------------------------------------------------------------
    mov  esi, OFFSET saveStart
    mov  ecx, SAVE_SIZE
    call ComputeChecksum
    mov  saveChecksum, eax

    mov  esi, OFFSET saveStart
    mov  ecx, SAVE_FILE_SIZE
    call XorCrypt                   ; encrypt

    mov  edx, OFFSET saveFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   save_failed
    mov  fileHandle, eax
    mov  edx, OFFSET saveStart
    mov  ecx, SAVE_FILE_SIZE
    call WriteToFile
    mov  eax, fileHandle
    call CloseFile

    mov  esi, OFFSET saveStart
    mov  ecx, SAVE_FILE_SIZE
    call XorCrypt                   ; decrypt back
    mov  msgPtr, OFFSET msgSaved
    mov  msgColor, lightGreen
    mBeep 1000, 60
    mBeep 1400, 60
    ret

save_failed:
    mov  esi, OFFSET saveStart
    mov  ecx, SAVE_FILE_SIZE
    call XorCrypt                   ; decrypt back
    mov  msgPtr, OFFSET msgSaveFail
    mov  msgColor, lightRed
    ret
SaveGame ENDP

;-----------------------------------------------------------------------
LoadGame PROC
; Loads savegame.txt, decrypts it, checks it and resumes the game.
;-----------------------------------------------------------------------
    pushad
    mov  edx, OFFSET saveFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   no_save_file
    mov  fileHandle, eax
    mov  edx, OFFSET loadBuffer
    mov  ecx, SAVE_FILE_SIZE
    call ReadFromFile
    jnc  load_read_ok
    xor  eax, eax
load_read_ok:
    mov  fileLen, eax
    mov  eax, fileHandle
    call CloseFile
    cmp  fileLen, SAVE_FILE_SIZE
    jne  bad_save

    mov  esi, OFFSET loadBuffer
    mov  ecx, SAVE_FILE_SIZE
    call XorCrypt                   ; decrypt

    cmp  DWORD PTR loadBuffer, SAVE_MAGIC
    jne  bad_save
    mov  esi, OFFSET loadBuffer
    mov  ecx, SAVE_SIZE
    call ComputeChecksum
    cmp  eax, DWORD PTR loadBuffer[SAVE_SIZE]
    jne  bad_save

    mov  esi, OFFSET loadBuffer     ; copy into the live game state
    mov  edi, OFFSET saveStart
    mov  ecx, SAVE_SIZE
    cld
    rep  movsb

    mov  totalLevels, NUM_LEVELS
    cmp  isCustom, 0
    je   levels_set
    mov  totalLevels, 1
levels_set:
    mov  msgPtr, OFFSET msgLoaded
    mov  msgColor, lightGreen
    mov  resumeFlag, 1
    call PlayGame
    jmp  load_done

no_save_file:
    mov  edx, OFFSET noticeNoSave
    call ShowNotice
    jmp  load_done
bad_save:
    mov  edx, OFFSET noticeCorrupt
    call ShowNotice
load_done:
    popad
    ret
LoadGame ENDP

;=======================================================================
;                LEADERBOARD  (file handling + sorting)
;=======================================================================

;-----------------------------------------------------------------------
ParseNumber PROC USES ecx
; Reads a decimal number from text.
; Receives: ESI = text, EDI = end of the text
; Returns:  EAX = value, ESI = first character after the number
;-----------------------------------------------------------------------
    xor  eax, eax
digit_loop:
    cmp  esi, edi
    jae  number_done
    movzx ecx, BYTE PTR [esi]
    cmp  cl, '0'
    jb   number_done
    cmp  cl, '9'
    ja   number_done
    sub  ecx, '0'
    imul eax, 10
    add  eax, ecx
    inc  esi
    jmp  digit_loop
number_done:
    ret
ParseNumber ENDP

;-----------------------------------------------------------------------
AppendNumber PROC USES eax ebx ecx edx
; Writes EAX as decimal text.
; Receives: EAX = value, EDI = destination   Returns: EDI after the text
;-----------------------------------------------------------------------
    mov  ebx, 10
    xor  ecx, ecx
make_digits:
    xor  edx, edx
    div  ebx                        ; EDX = last digit
    add  dl, '0'
    push edx
    inc  ecx
    cmp  eax, 0
    jne  make_digits
write_digits:
    pop  eax
    mov  [edi], al
    inc  edi
    loop write_digits
    ret
AppendNumber ENDP

;-----------------------------------------------------------------------
LoadLeaderboard PROC
; Reads leaderboard.txt. Each line is:  name,level,score
;-----------------------------------------------------------------------
    pushad
    mov  lbCount, 0
    mov  edx, OFFSET boardFile
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   lb_done
    mov  fileHandle, eax
    mov  edx, OFFSET fileBuffer
    mov  ecx, FILE_BUF_SIZE
    call ReadFromFile
    jnc  lb_read_ok
    xor  eax, eax
lb_read_ok:
    mov  fileLen, eax
    mov  eax, fileHandle
    call CloseFile

    mov  esi, OFFSET fileBuffer
    mov  edi, esi
    add  edi, fileLen               ; EDI = end of the text
next_line:
    cmp  esi, edi
    jae  lb_done
    mov  al, [esi]
    cmp  al, 0Dh
    je   skip_char
    cmp  al, 0Ah
    je   skip_char
    jmp  parse_entry
skip_char:
    inc  esi
    jmp  next_line

parse_entry:
    cmp  lbCount, MAX_LB
    jae  lb_done
    mov  eax, lbCount
    imul eax, LB_NAME_SIZE
    lea  ebx, lbNames[eax]          ; EBX = name slot
    xor  ecx, ecx
read_name:
    cmp  esi, edi
    jae  lb_done
    mov  al, [esi]
    inc  esi
    cmp  al, ','
    je   name_done
    cmp  al, 0Dh
    je   next_line                  ; broken line: ignore it
    cmp  al, 0Ah
    je   next_line
    cmp  ecx, MAX_NAME
    jae  read_name
    mov  [ebx+ecx], al
    inc  ecx
    jmp  read_name
name_done:
    mov  BYTE PTR [ebx+ecx], 0
    call ParseNumber                ; level
    mov  edx, lbCount
    mov  lbLevels[edx*4], eax
    cmp  esi, edi
    jae  no_comma
    cmp  BYTE PTR [esi], ','
    jne  no_comma
    inc  esi
no_comma:
    call ParseNumber                ; score
    mov  edx, lbCount
    mov  lbScores[edx*4], eax
    inc  lbCount
skip_rest:
    cmp  esi, edi
    jae  lb_done
    mov  al, [esi]
    cmp  al, 0Ah
    je   next_line
    inc  esi
    jmp  skip_rest

lb_done:
    call SortLeaderboard
    popad
    ret
LoadLeaderboard ENDP

;-----------------------------------------------------------------------
SwapLbEntries PROC
; Swaps leaderboard entries i and i+1.   Receives: EAX = i
;-----------------------------------------------------------------------
    pushad
    mov  ebx, eax
    mov  eax, lbScores[ebx*4]
    xchg eax, lbScores[ebx*4+4]
    mov  lbScores[ebx*4], eax
    mov  eax, lbLevels[ebx*4]
    xchg eax, lbLevels[ebx*4+4]
    mov  lbLevels[ebx*4], eax

    mov  eax, ebx
    imul eax, LB_NAME_SIZE
    lea  esi, lbNames[eax]
    lea  edi, [esi + LB_NAME_SIZE]
    mov  ecx, LB_NAME_SIZE
swap_bytes:
    mov  al, [esi]
    mov  dl, [edi]
    mov  [esi], dl
    mov  [edi], al
    inc  esi
    inc  edi
    loop swap_bytes
    popad
    ret
SwapLbEntries ENDP

;-----------------------------------------------------------------------
SortLeaderboard PROC
; Bubble sort: highest score first.
;-----------------------------------------------------------------------
    pushad
    mov  ecx, lbCount
    cmp  ecx, 1
    jbe  sort_done
    dec  ecx                        ; number of passes
outer_pass:
    push ecx
    xor  ebx, ebx                   ; i = 0
inner_pass:
    mov  eax, lbScores[ebx*4]
    cmp  eax, lbScores[ebx*4+4]
    jae  in_order
    mov  eax, ebx
    call SwapLbEntries
in_order:
    inc  ebx
    dec  ecx
    jnz  inner_pass
    pop  ecx
    dec  ecx
    jnz  outer_pass
sort_done:
    popad
    ret
SortLeaderboard ENDP

;-----------------------------------------------------------------------
SaveLeaderboard PROC
; Writes all entries to leaderboard.txt as  name,level,score  lines.
;-----------------------------------------------------------------------
    pushad
    mov  edi, OFFSET fileBuffer
    xor  ebx, ebx
build_entry:
    cmp  ebx, lbCount
    jae  write_board
    mov  eax, ebx
    imul eax, LB_NAME_SIZE
    lea  esi, lbNames[eax]
copy_name:
    mov  al, [esi]
    cmp  al, 0
    je   name_copied
    mov  [edi], al
    inc  esi
    inc  edi
    jmp  copy_name
name_copied:
    mov  BYTE PTR [edi], ','
    inc  edi
    mov  eax, lbLevels[ebx*4]
    call AppendNumber
    mov  BYTE PTR [edi], ','
    inc  edi
    mov  eax, lbScores[ebx*4]
    call AppendNumber
    mov  BYTE PTR [edi], 0Dh
    mov  BYTE PTR [edi+1], 0Ah
    add  edi, 2
    inc  ebx
    jmp  build_entry

write_board:
    mov  edx, OFFSET boardFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   board_done
    mov  fileHandle, eax
    mov  ecx, edi
    sub  ecx, OFFSET fileBuffer     ; ECX = number of bytes
    mov  edx, OFFSET fileBuffer
    call WriteToFile
    mov  eax, fileHandle
    call CloseFile
board_done:
    popad
    ret
SaveLeaderboard ENDP

;-----------------------------------------------------------------------
AddToLeaderboard PROC
; Adds the current player, sorts, keeps the top 10 and saves the file.
;-----------------------------------------------------------------------
    pushad
    call LoadLeaderboard
    mov  ebx, lbCount               ; free slot (array has MAX_LB+1)
    mov  eax, ebx
    imul eax, LB_NAME_SIZE
    lea  edi, lbNames[eax]
    INVOKE Str_copy, ADDR playerName, edi
    mov  eax, levelReached
    mov  lbLevels[ebx*4], eax
    mov  eax, score
    mov  lbScores[ebx*4], eax
    inc  lbCount
    call SortLeaderboard
    cmp  lbCount, MAX_LB
    jbe  count_ok
    mov  lbCount, MAX_LB            ; drop the lowest score
count_ok:
    call SaveLeaderboard
    popad
    ret
AddToLeaderboard ENDP

;-----------------------------------------------------------------------
ShowLeaderboard PROC
; Shows the sorted leaderboard in a table.
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr
    mColor yellow
    INVOKE DrawBox, 14, 1, 50, 18
    mGoto 30, 3
    mPrint "LEADERBOARD  -  TOP 10"
    mColor lightCyan
    mGoto 18, 5
    mPrint "RANK   NAME              LEVEL    SCORE"
    mColor gray
    mGoto 18, 6
    mPrint "----   ----------------  -----    -----"

    cmp  lbCount, 0
    jne  show_rows
    mColor white
    mGoto 25, 9
    mPrint "No scores yet - be the first."
    jmp  board_footer

show_rows:
    xor  ebx, ebx
board_row:
    cmp  ebx, lbCount
    jae  board_footer
    mov  eax, white
    cmp  ebx, 0
    jne  row_color
    mov  eax, yellow                ; first place in gold
row_color:
    call SetColor
    mov  dh, bl
    add  dh, 7
    mov  dl, 19
    call Gotoxy
    mov  eax, ebx
    inc  eax
    call WriteDec                   ; rank
    mov  dl, 25
    call Gotoxy
    mov  eax, ebx
    imul eax, LB_NAME_SIZE
    push edx
    lea  edx, lbNames[eax]
    call WriteString                ; name
    pop  edx
    mov  dl, 45
    call Gotoxy
    mov  eax, lbLevels[ebx*4]
    call WriteDec                   ; level
    mov  dl, 52
    call Gotoxy
    mov  eax, lbScores[ebx*4]
    call WriteDec                   ; score
    inc  ebx
    jmp  board_row

board_footer:
    mColor gray
    mGoto 25, 18
    call WaitMsg
    popad
    ret
ShowLeaderboard ENDP

;=======================================================================
;                            MAP EDITOR
;=======================================================================

;-----------------------------------------------------------------------
MapEditorMenu PROC
; Map editor menu: create a custom map or play it.
;-----------------------------------------------------------------------
    pushad
editor_menu:
    mColor lightGray
    call Clrscr
    mColor lightMagenta
    INVOKE DrawBox, 18, 3, 44, 10
    mColor yellow
    mGoto 35, 5
    mPrint "MAP EDITOR"
    mColor yellow
    mGoto 24, 7
    mPrint "[1]"
    mColor white
    mPrint "  Create a new custom map"
    mColor yellow
    mGoto 24, 8
    mPrint "[2]"
    mColor white
    mPrint "  Play your custom map"
    mColor yellow
    mGoto 24, 9
    mPrint "[3]"
    mColor white
    mPrint "  Back to main menu"
    mColor lightGreen
    mGoto 24, 11
    mPrint "Choose an option (1-3): "

editor_key:
    call ReadChar
    cmp  al, '1'
    jne  editor_two
    call CreateCustomMap
    jmp  editor_menu
editor_two:
    cmp  al, '2'
    jne  editor_three
    mov  isCustom, 1
    call NewGame
    mov  isCustom, 0
    jmp  editor_exit
editor_three:
    cmp  al, '3'
    jne  editor_key
editor_exit:
    popad
    ret
MapEditorMenu ENDP

;-----------------------------------------------------------------------
CreateCustomMap PROC
; Lets the player type a map row by row and writes it to custom.txt.
;-----------------------------------------------------------------------
    pushad
    mColor lightGray
    call Clrscr
    mColor yellow
    mGoto 2, 1
    mPrint "MAP EDITOR - create your own level"
    mColor white
    mGoto 2, 3
    mPrint "Type one row of the map per line (max 30 characters)."
    mGoto 2, 4
    mPrint "Press ENTER on an empty line when you are done (max 20 rows)."
    mColor lightCyan
    mGoto 2, 6
    mPrint "#  wall       .  floor      S  start      E  exit"
    mGoto 2, 7
    mPrint "T  treasure   X  trap       H  potion     P  portal (use 2)"
    mGoto 2, 8
    mPrint "K  key        D  door       A  shield"
    mColor gray
    mGoto 2, 9
    mPrint "Rules: exactly one S and at least one E. Surround the map with # walls."

    mov  edi, OFFSET fileBuffer     ; the map text is built here
    xor  ebx, ebx                   ; rows entered
    mov  edCountS, 0
    mov  edCountE, 0
editor_row:
    cmp  ebx, MAX_ROWS
    jae  editor_finish
    mov  dh, bl
    add  dh, 11
    mov  dl, 2
    call Gotoxy
    mColor gray
    mPrint "Row "
    mov  eax, ebx
    inc  eax
    cmp  eax, 10
    jae  two_digits
    mPrint " "
two_digits:
    call WriteDec
    mPrint ": "
    mColor white
    mov  edx, OFFSET lineBuf
    mov  ecx, SIZEOF lineBuf
    call ReadString                 ; EAX = characters typed
    cmp  eax, 0
    je   editor_finish
    mov  ecx, eax
    cmp  ecx, MAX_COLS
    jbe  length_ok
    mov  ecx, MAX_COLS
length_ok:
    mov  esi, OFFSET lineBuf
copy_row:
    mov  al, [esi]
    cmp  al, 'a'
    jb   upper_ok
    cmp  al, 'z'
    ja   upper_ok
    sub  al, 32                     ; to uppercase
upper_ok:
    cmp  al, TILE_START
    jne  not_s_tile
    inc  edCountS
not_s_tile:
    cmp  al, TILE_EXIT
    jne  not_e_tile
    inc  edCountE
not_e_tile:
    mov  [edi], al
    inc  esi
    inc  edi
    loop copy_row
    mov  BYTE PTR [edi], 0Dh        ; end the row with CR LF
    mov  BYTE PTR [edi+1], 0Ah
    add  edi, 2
    inc  ebx
    jmp  editor_row

editor_finish:
    cmp  ebx, 0
    jne  check_rules
    mov  edx, OFFSET noticeNoMap
    call ShowNotice
    jmp  editor_done
check_rules:
    cmp  edCountS, 1
    jne  rules_broken
    cmp  edCountE, 0
    jne  write_map
rules_broken:
    mov  edx, OFFSET noticeBadMap
    call ShowNotice
    jmp  editor_done

write_map:
    mov  edx, OFFSET customFile
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   map_write_fail
    mov  fileHandle, eax
    mov  ecx, edi
    sub  ecx, OFFSET fileBuffer
    mov  edx, OFFSET fileBuffer
    call WriteToFile
    mov  eax, fileHandle
    call CloseFile
    mov  edx, OFFSET noticeMapSaved
    call ShowNotice
    jmp  editor_done
map_write_fail:
    mov  edx, OFFSET noticeMapFail
    call ShowNotice
editor_done:
    popad
    ret
CreateCustomMap ENDP

END main
