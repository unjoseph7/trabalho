-- ps2_rx.vhdl
-- PS/2 Keyboard Receiver Module
-- This module implements a complete PS/2 protocol receiver that decodes
-- serial data from a PS/2 keyboard. The PS/2 protocol uses synchronous
-- serial communication with 11 bits per transmission:
--   1 start bit (always '0')
--   8 data bits (LSB first)
--   1 parity bit (even parity)
--   1 stop bit (always '1')
-- The keyboard provides its own clock signal (PS2C) typically at 10-16.7 kHz.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ps2_rx is
  port (
    clk, reset   : in std_logic;                    -- System clock (50 MHz) and asynchronous reset
    ps2d, ps2c   : in std_logic;                    -- PS/2 data and clock signals from keyboard
    rx_en        : in std_logic;                    -- Receive enable signal
    rx_done_tick : out std_logic;                   -- Pulse signal indicating byte reception complete
    dout         : out std_logic_vector(7 downto 0) -- Received 8-bit data byte
  );
end ps2_rx;

architecture arch of ps2_rx is
  -- Finite State Machine states for reception
  -- idle: waiting for transmission start
  -- dps: receiving data, parity, and stop bits
  -- load: finalizing reception and signaling completion
  type statetype is (idle, dps, load);
  signal state_reg, state_next : statetype;
  
  -- Clock filter: 8-bit shift register to filter noise from PS2C signal
  -- Requires 8 consecutive samples of same value to change state
  signal filter_reg, filter_next : std_logic_vector(7 downto 0);
  
  -- Filtered PS2C signal: stable clock signal after filtering
  signal f_ps2c_reg, f_ps2c_next : std_logic;
  
  -- Bit shift register: stores all 11 bits of PS/2 transmission
  -- b_reg(10) = start bit, b_reg(9 downto 2) = data, b_reg(1) = parity, b_reg(0) = stop
  signal b_reg, b_next : std_logic_vector(10 downto 0);
  
  -- Bit counter: counts remaining bits to receive (starts at 9 for 8 data + parity + stop)
  signal n_reg, n_next : unsigned(3 downto 0);
  
  -- Falling edge detection: detects when PS2C transitions from high to low
  signal fall_edge : std_logic;
begin
  -- Clock filter and falling edge detection process
  -- Filters the PS2C signal to eliminate noise and glitches
  process (clk, reset)
  begin
    if reset = '1' then
      -- Reset: clear filter register and filtered clock
      filter_reg <= (others => '0');
      f_ps2c_reg <= '0';
    elsif (clk'event and clk = '1') then
      -- Update filter register and filtered clock signal
      filter_reg <= filter_next;
      f_ps2c_reg <= f_ps2c_next;
    end if;
  end process;

  -- Filter implementation: shift register that samples PS2C
  -- New sample enters at MSB, oldest sample is shifted out
  filter_next <= ps2c & filter_reg(7 downto 1);
  
  -- Filtered clock logic: requires 8 consecutive '1's or '0's to change state
  -- This eliminates noise and ensures only valid clock transitions are processed
  f_ps2c_next <= '1' when filter_reg = "11111111" else  -- All ones: clock is high
                 '0' when filter_reg = "00000000" else  -- All zeros: clock is low
                 f_ps2c_reg;                            -- Otherwise: maintain current state
  
  -- Falling edge detection: detects transition from high to low
  -- PS/2 protocol samples data on falling edge of clock
  fall_edge <= f_ps2c_reg and (not f_ps2c_next);

  -- Reception state machine: receives and decodes PS/2 transmission
  -- FSMD (Finite State Machine with Datapath) for receiving start, 8 data, parity, and stop bits
  process (clk, reset)
  begin
    if reset = '1' then
      -- Reset: return to idle state, clear counters and bit register
      state_reg <= idle;
      n_reg     <= (others => '0');
      b_reg     <= (others => '0');
    elsif (clk'event and clk = '1') then
      -- Update state, counter, and bit register
      state_reg <= state_next;
      n_reg     <= n_next;
      b_reg     <= b_next;
    end if;
  end process;

  -- Next-state and datapath logic
  -- Determines next state and updates bit register and counter
  process(state_reg, n_reg, b_reg, fall_edge, rx_en, ps2d)
  begin
    -- Default values: no completion signal, maintain current state
    rx_done_tick <= '0';
    state_next   <= state_reg;
    n_next       <= n_reg;
    b_next       <= b_reg;
    
    case state_reg is
      when idle =>
        -- Wait for falling edge and receive enable
        if fall_edge = '1' and rx_en = '1' then
          -- Capture start bit and shift into bit register
          b_next    <= ps2d & b_reg(10 downto 1);
          n_next    <= "1001";  -- Initialize counter: 9 bits remaining (8 data + parity + stop)
          state_next <= dps;     -- Transition to data reception state
        end if;
        
      when dps =>  -- Data, Parity, Stop reception state
        -- On each falling edge, capture one bit
        if fall_edge = '1' then
          -- Shift new bit into register (MSB first, LSB last)
          b_next <= ps2d & b_reg(10 downto 1);
          
          if n_reg = 0 then
            -- All bits received: transition to load state
            state_next <= load;
          else
            -- Decrement bit counter
            n_next <= n_reg - 1;
          end if;
        end if;
        
      when load =>
        -- Finalize reception: signal completion and return to idle
        state_next   <= idle;    -- Return to idle (one extra cycle for timing)
        rx_done_tick <= '1';     -- Signal that byte reception is complete
    end case;
  end process;

  -- Output: extract 8 data bits from bit register
  -- b_reg(9 downto 2) contains the 8 data bits (after start bit)
  dout <= b_reg(8 downto 1);
end arch;
