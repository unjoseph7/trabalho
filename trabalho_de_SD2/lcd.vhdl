-- lcd.vhdl
-- Main Module: LCD Controller and Hangman Game Logic
-- This is the top-level module that integrates all system components:
--   - Keyboard interface (PS/2 receiver and code manager)
--   - LCD display controller (HD44780 driver)
--   - Hangman game logic (word selection, letter matching, win/lose conditions)
--   - LFSR for pseudo-random word selection (Mode A: ROM with 64 words)
-- The module implements a complete interactive hangman game on FPGA.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity lcd is
  Port (
    LCD_DB : out std_logic_vector(7 downto 0); -- LCD data bus (8 bits)
    RS     : out std_logic;                     -- LCD Register Select (0=command, 1=data)
    RW     : out std_logic;                     -- LCD Read/Write (0=write, 1=read)
    CLK    : in  std_logic;                     -- System clock (50 MHz)
    OE     : out std_logic;                     -- LCD Output Enable (active low)
    rst    : in  std_logic;                     -- Asynchronous reset
    ps2d, ps2c : in  std_logic;                 -- PS/2 keyboard data and clock
    tecla      : out std_logic_vector(7 downto 0) -- Debug output: current key code
  );
end lcd;

architecture Behavioral of lcd is

  -- Keyboard code manager component declaration
  -- Integrates PS/2 receiver, FIFO, and ASCII converter
  component kb_code
    port (
      clk, reset   : in  std_logic;
      ps2d, ps2c   : in  std_logic;
      rd_key_code  : in  std_logic;
      key_code     : out std_logic_vector(7 downto 0);
      kb_buf_empty : out std_logic
    );
  end component;

  -- Type definitions for word storage
  -- WORD_T: array of 12 bytes (max word length)
  -- ROM_T: array of 64 words (ROM for Mode A)
  type WORD_T is array(0 to 11) of std_logic_vector(7 downto 0);
  type ROM_T  is array(0 to 63) of WORD_T;

  -- ROM containing 64 words for hangman game (Mode A)
  -- Each word is stored as ASCII hexadecimal values
  -- X"00" indicates end of word (empty character positions)
  -- Words are related to FPGA, VHDL, and digital electronics terminology
  constant ROM_WORDS : ROM_T := (
    -- Word 0: "SPARTAN" (Xilinx FPGA family)
    (X"53",X"50",X"41",X"52",X"54",X"41",X"4E",X"00",X"00",X"00",X"00",X"00"),
    -- Word 1: "XILINX" (FPGA manufacturer)
    (X"58",X"49",X"4C",X"49",X"4E",X"58",X"00",X"00",X"00",X"00",X"00",X"00"),
    -- Word 2: "FPGA" (Field Programmable Gate Array)
    (X"46",X"50",X"47",X"41",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    -- Word 3: "VHDL" (Hardware Description Language)
    (X"56",X"48",X"44",X"4C",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"43",X"4C",X"4F",X"43",X"4B",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"52",X"45",X"53",X"45",X"54",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"53",X"49",X"47",X"4E",X"41",X"4C",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"50",X"52",X"4F",X"43",X"45",X"53",X"53",X"00",X"00",X"00",X"00",X"00"),
    (X"45",X"4E",X"54",X"49",X"54",X"59",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"41",X"52",X"43",X"48",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"47",X"45",X"4E",X"45",X"52",X"49",X"43",X"00",X"00",X"00",X"00",X"00"),
    (X"50",X"4F",X"52",X"54",X"4D",X"41",X"50",X"00",X"00",X"00",X"00",X"00"),
    (X"4B",X"45",X"59",X"42",X"4F",X"41",X"52",X"44",X"00",X"00",X"00",X"00"),
    (X"44",X"49",X"53",X"50",X"4C",X"41",X"59",X"00",X"00",X"00",X"00",X"00"),
    (X"48",X"41",X"4E",X"47",X"4D",X"41",X"4E",X"00",X"00",X"00",X"00",X"00"),
    (X"48",X"44",X"34",X"34",X"37",X"38",X"30",X"00",X"00",X"00",X"00",X"00"),
    (X"54",X"45",X"43",X"4C",X"41",X"44",X"4F",X"00",X"00",X"00",X"00",X"00"),
    (X"42",X"52",X"41",X"53",X"49",X"4C",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"52",X"4F",X"4D",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"4C",X"46",X"53",X"52",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"52",X"41",X"4E",X"44",X"4F",X"4D",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"42",X"49",X"54",X"53",X"54",X"52",X"45",X"41",X"4D",X"00",X"00",X"00"),
    (X"53",X"59",X"4E",X"54",X"48",X"45",X"53",X"49",X"53",X"00",X"00",X"00"),
    (X"54",X"49",X"4D",X"49",X"4E",X"47",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"43",X"4F",X"4E",X"53",X"54",X"52",X"41",X"49",X"4E",X"54",X"00",X"00"),
    (X"50",X"41",X"43",X"4B",X"41",X"47",X"45",X"00",X"00",X"00",X"00",X"00"),
    (X"56",X"45",X"43",X"54",X"4F",X"52",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"53",X"54",X"44",X"4C",X"4F",X"47",X"49",X"43",X"00",X"00",X"00",X"00"),
    (X"4E",X"55",X"4D",X"45",X"52",X"49",X"43",X"00",X"00",X"00",X"00",X"00"),
    (X"43",X"4F",X"55",X"4E",X"54",X"45",X"52",X"00",X"00",X"00",X"00",X"00"),
    (X"44",X"49",X"56",X"49",X"44",X"45",X"52",X"00",X"00",X"00",X"00",X"00"),
    (X"44",X"45",X"42",X"4F",X"55",X"4E",X"43",X"45",X"00",X"00",X"00",X"00"),
    (X"4D",X"41",X"4B",X"45",X"43",X"4F",X"44",X"45",X"00",X"00",X"00",X"00"),
    (X"42",X"52",X"45",X"41",X"4B",X"43",X"4F",X"44",X"45",X"00",X"00",X"00"),
    (X"50",X"41",X"52",X"49",X"44",X"41",X"44",X"45",X"00",X"00",X"00",X"00"),
    (X"53",X"45",X"47",X"4D",X"45",X"4E",X"54",X"00",X"00",X"00",X"00",X"00"),
    (X"4D",X"41",X"54",X"52",X"49",X"5A",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"43",X"41",X"4D",X"49",X"4E",X"48",X"4F",X"00",X"00",X"00",X"00",X"00"),
    (X"4C",X"41",X"52",X"47",X"55",X"52",X"41",X"00",X"00",X"00",X"00",X"00"),
    (X"41",X"4C",X"54",X"55",X"52",X"41",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"45",X"4E",X"44",X"45",X"52",X"45",X"43",X"4F",X"00",X"00",X"00",X"00"),
    (X"44",X"49",X"52",X"45",X"49",X"54",X"41",X"00",X"00",X"00",X"00",X"00"),
    (X"45",X"53",X"51",X"55",X"45",X"52",X"44",X"41",X"00",X"00",X"00",X"00"),
    (X"4C",X"49",X"4D",X"50",X"41",X"52",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"43",X"55",X"52",X"53",X"4F",X"52",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"42",X"4C",X"49",X"4E",X"4B",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"45",X"52",X"52",X"4F",X"53",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"50",X"41",X"4C",X"41",X"56",X"52",X"41",X"00",X"00",X"00",X"00",X"00"),
    (X"56",X"45",X"4E",X"43",X"45",X"55",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"46",X"49",X"4D",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"49",X"4E",X"49",X"43",X"49",X"4F",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"50",X"52",X"4F",X"4E",X"54",X"4F",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"4A",X"4F",X"47",X"4F",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"41",X"53",X"43",X"49",X"49",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"50",X"53",X"32",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"44",X"41",X"44",X"4F",X"53",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    -- Words 56-63: Empty entries (reserved for future words)
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00"),
    (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00")
  );

  -- LCD initialization and control state machine type
  -- States for LCD initialization sequence and character writing
  type mstate is (
    stFunctionSet,        -- Set LCD function (8-bit, 2-line mode)
    stDisplayCtrlSet,     -- Set display control (display on, cursor off)
    stDisplayClear,       -- Clear display command
    stPowerOn_Delay,      -- Wait for power-on stabilization (50 ms)
    stFunctionSet_Delay,  -- Delay after function set
    stDisplayCtrlSet_Delay, -- Delay after display control set
    stDisplayClear_Delay, -- Delay after display clear (2 ms)
    stInitDne,            -- Initialization done, ready for writing
    stActWr,              -- Activate write operation
    stCharDelay           -- Delay after character write
  );

  -- Write control state machine type
  -- Controls the OE (Output Enable) signal timing for LCD
  type wstate is (stRW, stEnable, stIdle);

  -- Clock division signals
  -- Divides 50 MHz system clock to generate 1 microsecond clock for LCD timing
  signal clkCount  : std_logic_vector(5 downto 0);  -- 6-bit counter for clock division
  signal activateW : std_logic := '0';               -- Signal to activate write operation
  signal count     : std_logic_vector(16 downto 0) := "00000000000000000"; -- Delay counter
  signal delayOK   : std_logic := '0';               -- Flag indicating delay period completed
  signal oneUSClk  : std_logic;                      -- 1 microsecond clock (divided from 50 MHz)

  -- LCD main state machine signals
  signal stCur  : mstate := stPowerOn_Delay;  -- Current state
  signal stNext : mstate;                     -- Next state
  signal stCurW : wstate := stIdle;           -- Current write control state
  signal stNextW: wstate;                    -- Next write control state

  -- Keyboard interface signals
  signal rd_key_code  : std_logic;                    -- Read signal for keyboard code
  signal key_read     : std_logic_vector(7 downto 0);  -- ASCII code read from keyboard
  signal kb_empty     : std_logic;                    -- Flag: keyboard buffer empty

  -- Game state variables
  signal tried     : std_logic_vector(25 downto 0) := (others => '0'); -- Bitmap: letters A-Z tried
  signal revealed  : std_logic_vector(11 downto 0) := (others => '0'); -- Bitmap: positions revealed
  signal errors    : unsigned(2 downto 0) := (others => '0');          -- Error counter (0-6)
  signal game_win  : std_logic := '0';  -- Flag: game won
  signal game_lose : std_logic := '0';  -- Flag: game lost (6 errors)
  signal gameover  : std_logic := '0';  -- Flag: game finished (win or lose)

  -- Word management signals
  signal word_buf    : WORD_T := (others => X"00"); -- Buffer storing current word
  signal word_loaded : std_logic := '0';            -- Flag: word loaded from ROM

  -- LFSR (Linear Feedback Shift Register) for pseudo-random word selection
  -- Polynomial: x^16 + x^15 + x^13 + x^12 + x^10 + 1
  -- Initial seed: 0xACE1
  signal lfsr_reg, lfsr_next : std_logic_vector(15 downto 0) := X"ACE1";
  signal word_idx            : integer range 0 to 63 := 0; -- Index to select word from ROM

  -- LCD command array type
  -- Format: bit 9 = RS, bit 8 = RW, bits 7-0 = data
  -- "00" = command (RS=0, RW=0), "10" = data write (RS=1, RW=0)
  type LCD_CMDS_T is array(integer range 35 downto 0) of std_logic_vector (9 downto 0);

  -- LCD command and data array
  -- Contains initialization commands and display text
  -- Dynamically updated based on game state
  signal LCD_CMDS : LCD_CMDS_T := (
    -- Initialization commands (positions 0-3)
    0  => "00"&X"3C",  -- Function set: 8-bit, 2-line, 5x8 font
    1  => "00"&X"0C",  -- Display control: display on, cursor off, blink off
    2  => "00"&X"01",  -- Clear display
    3  => "00"&X"02",  -- Return home
    
    -- Line 1: "PALAVRA: " or "VOCE VENCEU!" (positions 4-12)
    4  => "10"&X"50",  -- 'P'
    5  => "10"&X"41",  -- 'A'
    6  => "10"&X"4C",  -- 'L'
    7  => "10"&X"41",  -- 'A'
    8  => "10"&X"56",  -- 'V'
    9  => "10"&X"52",  -- 'R'
    10 => "10"&X"41",  -- 'A'
    11 => "10"&X"3A",  -- ':'
    12 => "10"&X"20",  -- ' ' (space)
    
    -- Word display slots: 12 positions for letters (positions 13-24)
    -- Initially all underscores (X"5F"), updated dynamically
    13 => "10"&X"5F", 14 => "10"&X"5F", 15 => "10"&X"5F", 16 => "10"&X"5F",
    17 => "10"&X"5F", 18 => "10"&X"5F", 19 => "10"&X"5F", 20 => "10"&X"5F",
    21 => "10"&X"5F", 22 => "10"&X"5F", 23 => "10"&X"5F", 24 => "10"&X"5F",
    
    -- Line 2 command and text: "ERROS: X/6" (positions 25-35)
    25 => "00"&X"C0",  -- Set DDRAM address to second line (0x40)
    26 => "10"&X"45",  -- 'E'
    27 => "10"&X"52",  -- 'R'
    28 => "10"&X"52",  -- 'R'
    29 => "10"&X"4F",  -- 'O'
    30 => "10"&X"53",  -- 'S'
    31 => "10"&X"3A",  -- ':'
    32 => "10"&X"20",  -- ' ' (space)
    33 => "10"&X"30",  -- '0' (error count, updated dynamically)
    34 => "10"&X"2F",  -- '/'
    35 => "10"&X"36"   -- '6' (maximum errors)
  );

  -- Debug output signal
  signal tecla_s : std_logic_vector(7 downto 0) := (others => '0');

  -- LCD command pointer and control
  signal lcd_cmd_ptr : integer range 0 to LCD_CMDS'HIGH + 1 := 0; -- Pointer to current LCD command
  signal writeDone   : std_logic := '0';                        -- Flag: all commands written

begin
  -- Keyboard code manager instance
  -- Integrates PS/2 receiver, FIFO, and ASCII converter
  leitura: kb_code
    port map (
      CLK, rst, ps2d, ps2c,
      rd_key_code,
      key_read,
      kb_empty
    );

  -- Clock divider: generates 1 microsecond clock from 50 MHz system clock
  -- Divides by 32: 50 MHz / 32 = 1.5625 MHz ≈ 1 MHz (close enough for LCD timing)
  process (CLK)
  begin
    if (CLK'event and CLK = '1') then
      clkCount <= clkCount + 1;  -- Increment 6-bit counter
    end if;
  end process;

  -- Extract bit 5 from counter: creates ~1 MHz clock (period ≈ 1 μs)
  oneUSClk <= clkCount(5);

  -- Delay counter process
  -- Counts microseconds for LCD timing requirements
  process (oneUSClk)
  begin
    if (oneUSClk'event and oneUSClk = '1') then
      if delayOK = '1' then
        -- Delay completed: reset counter
        count <= "00000000000000000";
      else
        -- Increment counter while waiting
        count <= count + 1;
      end if;
    end if;
  end process;

  -- Delay completion detection
  -- Checks if delay period has elapsed for current LCD state
  -- Delays are specified in microseconds (binary values)
  delayOK <= '1' when ((stCur = stPowerOn_Delay        and count = "00100111001010010") or  -- 50 ms (50000 μs)
                       (stCur = stFunctionSet_Delay    and count = "00000000000110010") or  -- 50 μs
                       (stCur = stDisplayCtrlSet_Delay and count = "00000000000110010") or  -- 50 μs
                       (stCur = stDisplayClear_Delay   and count = "00000011001000000") or  -- 2 ms (2000 μs)
                       (stCur = stCharDelay            and count = "11111111111111111"))   -- Max delay for character
             else '0';

  -- LCD main state machine register
  -- Updates state on 1 μs clock edge
  process (oneUSClk, rst)
  begin
    if oneUSClk = '1' and oneUSClk'Event then
      if rst = '1' then
        -- Reset: return to power-on delay state
        stCur <= stPowerOn_Delay;
      else
        -- Update state with next state value
        stCur <= stNext;
      end if;
    end if;
  end process;

  -- LFSR next value calculation
  -- Implements polynomial: x^16 + x^15 + x^13 + x^12 + x^10 + 1
  -- Feedback taps: bits 15, 13, 12, 10 (XORed together)
  -- Shifts left and inserts XOR result at LSB
  lfsr_next <= lfsr_reg(14 downto 0) & (lfsr_reg(15) xor lfsr_reg(13) xor lfsr_reg(12) xor lfsr_reg(10));

  -- LFSR and word selection process
  -- Generates pseudo-random sequence and selects word index
  process(oneUSClk, rst)
  begin
    if rst = '1' then
      -- Reset: initialize LFSR with seed and clear word loaded flag
      lfsr_reg    <= X"ACE1";  -- Initial seed for LFSR
      word_loaded <= '0';
    elsif (oneUSClk'event and oneUSClk = '1') then
      -- Update LFSR during power-on delay (while waiting for LCD stabilization)
      if stCur = stPowerOn_Delay and word_loaded = '0' then
        -- Continuously shift LFSR to generate pseudo-random sequence
        lfsr_reg <= lfsr_next;
      end if;
      -- Select word index when LCD initialization is complete
      if (stCur = stDisplayClear_Delay and delayOK = '1' and word_loaded = '0') then
        -- Extract 6 LSBs from LFSR to get index 0-63
        word_idx    <= conv_integer(unsigned(lfsr_reg(5 downto 0)));
        word_loaded <= '1';  -- Mark word as loaded
      end if;
    end if;
  end process;

  -- Word buffer loading process
  -- Loads selected word from ROM into buffer when game starts
  process(oneUSClk, rst)
  begin
    if rst = '1' then
      -- Reset: clear word buffer
      word_buf   <= (others => X"00");
    elsif (oneUSClk'event and oneUSClk = '1') then
      -- Load word when: word index is ready, game hasn't started (all flags reset)
      if word_loaded = '1' and revealed = "000000000000" and tried = "00000000000000000000000000" and errors = 0 then
        -- Copy selected word from ROM to buffer
        word_buf <= ROM_WORDS(word_idx);
      end if;
    end if;
  end process;

  -- Main game logic process: keyboard input processing
  -- Handles letter input, matching, error counting, and win/lose detection
  lendo: process (CLK, rst)
    variable new_revealed : std_logic_vector(11 downto 0); -- Temporary revealed positions
    variable found        : boolean;                        -- Flag: letter found in word
    variable idx          : integer;                        -- Letter index (0-25 for A-Z)
    variable all_ok       : boolean;                        -- Flag: all letters revealed
  begin
    if rst = '1' then
      -- Reset: clear all game state
      tried      <= (others => '0');  -- Clear tried letters bitmap
      revealed   <= (others => '0');  -- Clear revealed positions bitmap
      errors     <= (others => '0');  -- Reset error counter
      game_win   <= '0';              -- Clear win flag
      game_lose  <= '0';              -- Clear lose flag
      gameover   <= '0';              -- Clear gameover flag
      rd_key_code <= '0';             -- Clear read signal
      tecla_s     <= (others => '0'); -- Clear debug output
    elsif (CLK'event and CLK = '1') then
      if (kb_empty = '1') then
        -- Keyboard buffer empty: no key available
        rd_key_code <= '0';
      else
        -- Key available: read and process
        tecla_s     <= key_read;      -- Store for debug output
        rd_key_code <= '1';           -- Signal read to keyboard module
        
        if gameover = '0' then
          -- Game still active: process key input
          -- Check if key is valid letter (A-Z: ASCII 0x41-0x5A)
          if (key_read >= X"41") and (key_read <= X"5A") then
            -- Calculate letter index: A=0, B=1, ..., Z=25
            idx := conv_integer(unsigned(key_read)) - 65;
            
            if (idx >= 0 and idx < 26) then
              -- Check if letter has been tried before
              if tried(idx) = '0' then
                -- New letter: process it
                tried(idx) <= '1';  -- Mark letter as tried
                new_revealed := revealed;  -- Copy current revealed state
                found        := false;     -- Initialize found flag
                
                -- Search for letter in word (check all 12 positions)
                for j in 0 to 11 loop
                  if (word_buf(j) /= X"00") then  -- Valid character position
                    if word_buf(j) = key_read then
                      -- Letter found at position j: reveal it
                      new_revealed(j) := '1';
                      found := true;
                    end if;
                  end if;
                end loop;
                
                -- Update revealed positions
                revealed <= new_revealed;
                
                -- Check if letter was found in word
                if (not found) then
                  -- Letter not in word: increment error counter
                  if errors < 6 then
                    errors <= errors + 1;
                  end if;
                end if;
                
                -- Check win condition: all letters revealed
                all_ok := true;
                for j in 0 to 11 loop
                  if (word_buf(j) /= X"00") then  -- Valid character position
                    if new_revealed(j) = '0' then
                      -- At least one position not revealed: game not won yet
                      all_ok := false;
                    end if;
                  end if;
                end loop;
                
                -- Set win flag if all letters revealed
                if all_ok = true then
                  game_win <= '1';
                end if;
              end if;
              -- If letter already tried, ignore it (duplicate prevention)
            end if;
          end if;
          -- If key is not A-Z, ignore it
        end if;
        
        -- Check lose condition: 6 errors reached
        if errors = 6 then
          game_lose <= '1';
        end if;
        
        -- Set gameover flag when game ends (win or lose)
        if game_win = '1' or game_lose = '1' then
          gameover <= '1';
        end if;
      end if;
    end if;
  end process;

  -- Generate statement: creates 12 processes for word display slots
  -- Each process updates one LCD command position (13-24) based on game state
  -- Dynamically shows revealed letters or underscores
  gen_slots: for i in 0 to 11 generate
  begin
    slot_upd: process(word_buf, revealed, game_lose)
    begin
      if word_buf(i) = X"00" then
        -- Empty position: display space
        LCD_CMDS(13+i) <= "10"&X"20";  -- ASCII space character
      else
        -- Valid character position
        if (revealed(i) = '1') or (game_lose = '1') then
          -- Letter revealed or game lost: show actual letter
          LCD_CMDS(13+i) <= "10"&word_buf(i);  -- Display letter from word buffer
        else
          -- Letter not revealed: show underscore
          LCD_CMDS(13+i) <= "10"&X"5F";  -- ASCII underscore character '_'
        end if;
      end if;
    end process;
  end generate;

  -- Error counter display update process
  -- Updates LCD command position 33 with ASCII digit representing error count
  -- Position 33 is the error count digit in "ERROS: X/6"
  process(errors)
  begin
    case conv_integer(errors) is
      when 0 => LCD_CMDS(33) <= "10"&X"30";  -- '0' (ASCII 0x30)
      when 1 => LCD_CMDS(33) <= "10"&X"31";  -- '1' (ASCII 0x31)
      when 2 => LCD_CMDS(33) <= "10"&X"32";  -- '2' (ASCII 0x32)
      when 3 => LCD_CMDS(33) <= "10"&X"33";  -- '3' (ASCII 0x33)
      when 4 => LCD_CMDS(33) <= "10"&X"34";  -- '4' (ASCII 0x34)
      when 5 => LCD_CMDS(33) <= "10"&X"35";  -- '5' (ASCII 0x35)
      when others => LCD_CMDS(33) <= "10"&X"36";  -- '6' (ASCII 0x36) - maximum errors
    end case;
  end process;

  -- Victory message display process
  -- Updates LCD line 1 to show "VOCE VENCEU!" when game is won
  -- Otherwise displays "PALAVRA: " (default game state)
  process(game_win)
  begin
    if game_win = '1' then
      -- Display victory message: "VOCE VENCEU!"
      LCD_CMDS(4)  <= "10"&X"56";  -- 'V'
      LCD_CMDS(5)  <= "10"&X"4F";  -- 'O'
      LCD_CMDS(6)  <= "10"&X"43";  -- 'C'
      LCD_CMDS(7)  <= "10"&X"45";  -- 'E'
      LCD_CMDS(8)  <= "10"&X"20";  -- ' ' (space)
      LCD_CMDS(9)  <= "10"&X"56";  -- 'V'
      LCD_CMDS(10) <= "10"&X"45";  -- 'E'
      LCD_CMDS(11) <= "10"&X"4E";  -- 'N'
      LCD_CMDS(12) <= "10"&X"43";  -- 'C'
    else
      -- Default: display "PALAVRA: "
      LCD_CMDS(4)  <= "10"&X"50";  -- 'P'
      LCD_CMDS(5)  <= "10"&X"41";  -- 'A'
      LCD_CMDS(6)  <= "10"&X"4C";  -- 'L'
      LCD_CMDS(7)  <= "10"&X"41";  -- 'A'
      LCD_CMDS(8)  <= "10"&X"56";  -- 'V'
      LCD_CMDS(9)  <= "10"&X"52";  -- 'R'
      LCD_CMDS(10) <= "10"&X"41";  -- 'A'
      LCD_CMDS(11) <= "10"&X"3A";  -- ':'
      LCD_CMDS(12) <= "10"&X"20";  -- ' ' (space)
    end if;
  end process;

  -- Debug output: current key code
  tecla <= tecla_s;

  -- Write completion detection
  -- Signals when all LCD commands have been written
  writeDone <= '1' when (lcd_cmd_ptr = LCD_CMDS'HIGH + 1) else '0';

  -- LCD command pointer update process
  -- Controls which command/character is being written to LCD
  process (lcd_cmd_ptr, oneUSClk)
  begin
    if (oneUSClk'event and oneUSClk = '1') then
      if ((stNext = stInitDne or stNext = stDisplayCtrlSet or stNext = stDisplayClear) and writeDone = '0') then
        -- Increment pointer when writing commands or characters
        lcd_cmd_ptr <= lcd_cmd_ptr + 1;
      elsif stCur = stPowerOn_Delay or stNext = stPowerOn_Delay then
        -- Reset pointer at start of initialization
        lcd_cmd_ptr <= 0;
      elsif writeDone = '1' then
        -- All commands written: point to first data position (after init commands)
        lcd_cmd_ptr <= 3;
      else
        -- Maintain current pointer position
        lcd_cmd_ptr <= lcd_cmd_ptr;
      end if;
    end if;
  end process;

  -- LCD main state machine: next-state and output logic
  -- Controls LCD initialization sequence and character writing
  -- Each state sets RS, RW, LCD_DB, and activateW signals appropriately
  process (stCur, delayOK, lcd_cmd_ptr)
  begin
    case stCur is
      when stPowerOn_Delay =>
        -- Wait for power-on stabilization (50 ms)
        if delayOK = '1' then stNext <= stFunctionSet; else stNext <= stPowerOn_Delay; end if;
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);  -- Extract RS from command array
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);   -- Extract RW from command array
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);  -- Extract data from command array
        activateW <= '0';  -- Don't activate write during delay
        
      when stFunctionSet =>
        -- Send function set command (8-bit, 2-line mode)
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '1';  -- Activate write
        stNext    <= stFunctionSet_Delay;
        
      when stFunctionSet_Delay =>
        -- Wait for function set to complete (50 μs)
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '0';
        if delayOK = '1' then stNext <= stDisplayCtrlSet; else stNext <= stFunctionSet_Delay; end if;
        
      when stDisplayCtrlSet =>
        -- Send display control command (display on, cursor off)
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '1';
        stNext    <= stDisplayCtrlSet_Delay;
        
      when stDisplayCtrlSet_Delay =>
        -- Wait for display control to complete (50 μs)
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '0';
        if delayOK = '1' then stNext <= stDisplayClear; else stNext <= stDisplayCtrlSet_Delay; end if;
        
      when stDisplayClear =>
        -- Send clear display command
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '1';
        stNext    <= stDisplayClear_Delay;
        
      when stDisplayClear_Delay =>
        -- Wait for display clear to complete (2 ms)
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '0';
        if delayOK = '1' then stNext <= stInitDne; else stNext <= stDisplayClear_Delay; end if;
        
      when stInitDne =>
        -- Initialization complete: ready to write characters
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '0';
        stNext    <= stActWr;  -- Transition to write activation
        
      when stActWr =>
        -- Activate write operation for character
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '1';  -- Signal write control FSM to activate OE
        stNext    <= stCharDelay;
        
      when stCharDelay =>
        -- Wait for character write to complete
        RS        <= LCD_CMDS(lcd_cmd_ptr)(9);
        RW        <= LCD_CMDS(lcd_cmd_ptr)(8);
        LCD_DB    <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
        activateW <= '0';
        if delayOK = '1' then stNext <= stInitDne; else stNext <= stCharDelay; end if;
    end case;
  end process;

  -- Write control state machine register
  -- Controls OE (Output Enable) signal timing for LCD
  process (oneUSClk, rst)
  begin
    if oneUSClk = '1' and oneUSClk'Event then
      if rst = '1' then
        -- Reset: return to idle state
        stCurW <= stIdle;
      else
        -- Update state with next state value
        stCurW <= stNextW;
      end if;
    end if;
  end process;

  -- Write control state machine: next-state and output logic
  -- Generates proper OE timing sequence for LCD write operations
  -- OE must be low (active) during write, high (inactive) otherwise
  process (stCurW, activateW)
  begin
    case stCurW is
      when stRw =>
        -- Prepare for write: set OE low (active)
        OE      <= '0';  -- Output Enable active
        stNextW <= stEnable;  -- Transition to enable state
        
      when stEnable =>
        -- Enable state: maintain OE low for LCD to latch data
        OE      <= '0';  -- Keep Output Enable active
        stNextW <= stIdle;  -- Return to idle
        
      when stIdle =>
        -- Idle state: OE high (inactive), waiting for write request
        OE <= '1';  -- Output Enable inactive
        if activateW = '1' then
          -- Write requested: transition to stRw
          stNextW <= stRw;
        else
          -- No write requested: remain in idle
          stNextW <= stIdle;
        end if;
    end case;
  end process;

end Behavioral;
