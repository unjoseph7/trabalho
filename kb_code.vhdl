-- kb_code.vhdl
-- Keyboard Code Manager Module
-- This module integrates the PS/2 receiver, FIFO buffer, and ASCII converter
-- to provide a complete keyboard interface. It implements MAKE event detection,
-- which captures key presses (not releases) by detecting the BREAK code (0xF0)
-- followed by the key's scan code. This provides natural debouncing since
-- only key press events are processed.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity kb_code is
  generic(
    W_SIZE : integer := 2  -- FIFO size parameter (2^W_SIZE words, not used in this implementation)
  );
  port (
    clk, reset    : in  std_logic;                    -- System clock and asynchronous reset
    ps2d, ps2c    : in  std_logic;                    -- PS/2 data and clock signals
    rd_key_code   : in  std_logic;                    -- Read signal: requests next key code
    key_code      : out std_logic_vector(7 downto 0); -- ASCII code of pressed key
    kb_buf_empty  : out std_logic                     -- Flag: indicates no key codes available
  );
end kb_code;

architecture arch of kb_code is
  -- PS/2 BREAK code constant: 0xF0 indicates key release
  -- When this code is received, the next code is the key that was released
  -- By capturing the code after BREAK, we get the MAKE event (key was pressed)
  constant BRK : std_logic_vector(7 downto 0) := "11110000"; -- 0xF0 (break code)
  
  -- Finite State Machine states for MAKE event detection
  -- wait_brk: waiting for BREAK code (0xF0)
  -- get_code: waiting for key code after BREAK
  type statetype is (wait_brk, get_code);
  signal state_reg, state_next : statetype;
  
  -- Internal signals for data flow
  signal scan_out, w_data      : std_logic_vector(7 downto 0); -- Scan codes from PS/2 RX
  signal scan_done_tick,       -- Pulse from PS/2 RX indicating byte received
         got_code_tick         : std_logic;                    -- Pulse to write code to FIFO
  signal ascii_code,           -- ASCII code from converter
         key_code_2            : std_logic_vector(7 downto 0); -- Scan code from FIFO
begin
  -- PS/2 Receiver instance
  -- Continuously receives scan codes from keyboard when enabled
  ps2_rx_unit: entity work.ps2_rx(arch)
    port map(
      clk          => clk,
      reset        => reset,
      rx_en        => '1',              -- Always enabled: continuously receive
      ps2d         => ps2d,
      ps2c         => ps2c,
      rx_done_tick => scan_done_tick,   -- Pulse when byte received
      dout         => scan_out          -- Received scan code (8 bits)
    );

  -- FIFO buffer instance (1 byte depth)
  -- Temporarily stores scan codes before ASCII conversion
  -- Provides flow control and prevents data loss
  fifo_key_unit: entity work.fifo(arch)
    generic map(B => 8)  -- 8-bit data width
    port map(
      clk    => clk,
      reset  => reset,
      rd     => rd_key_code,      -- Read when upper module requests
      wr     => got_code_tick,     -- Write when MAKE event detected
      w_data => scan_out,          -- Scan code from PS/2 receiver
      empty  => kb_buf_empty,      -- Output: indicates FIFO empty
      full   => open,              -- Full flag not used
      r_data => key_code_2         -- Scan code read from FIFO
    );

  -- PS/2 to ASCII converter instance
  -- Converts scan codes to ASCII character codes
  -- Implements lookup table for all keys (A-Z, 0-9, special characters)
  key2ascii_unit: entity work.key2ascii(arch)
    port map(
      key_code   => key_code_2,   -- Scan code from FIFO
      ascii_code => ascii_code     -- ASCII code output
    );

  -- State machine register: stores current state
  -- Synchronous process that updates state on clock edge
  process (clk, reset)
  begin
    if reset = '1' then
      -- Reset: start in wait_brk state
      state_reg <= wait_brk;
    elsif (clk'event and clk = '1') then
      -- Update state with next state value
      state_reg <= state_next;
    end if;
  end process;

  -- State machine next-state and output logic
  -- Implements MAKE event detection by waiting for BREAK code followed by key code
  process(state_reg, scan_done_tick, scan_out)
  begin
    -- Default values: no write to FIFO, maintain current state
    got_code_tick <= '0';
    state_next    <= state_reg;
    
    case state_reg is
      when wait_brk =>
        -- Wait for BREAK code (0xF0) indicating key release
        if scan_done_tick = '1' and scan_out = BRK then
          -- BREAK code detected: transition to get_code state
          -- The next scan code will be the key that was released (which means it was pressed)
          state_next <= get_code;
        end if;
        
      when get_code =>
        -- Wait for key code after BREAK
        if scan_done_tick = '1' then
          -- Key code received: this is the MAKE event (key was pressed)
          got_code_tick <= '1';     -- Write to FIFO
          state_next    <= wait_brk; -- Return to waiting for next BREAK
        end if;
    end case;
    
    -- Output: always provide ASCII code (combinational)
    -- The ASCII code is available immediately after conversion
    key_code <= ascii_code;
  end process;
end arch;
