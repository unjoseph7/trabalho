-- fifo.vhdl
-- First In First Out (FIFO) buffer implementation
-- This module implements a single-byte FIFO buffer used to temporarily store
-- keyboard scan codes before they are processed by the system.
-- The FIFO has depth of 1, which simplifies control logic and is sufficient
-- for the keyboard interface application.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
  generic(
    B: natural := 8  -- Number of bits per data word (8 bits for keyboard codes)
  );
  port(
    clk, reset : in  std_logic;                    -- System clock and asynchronous reset
    rd,  wr    : in  std_logic;                    -- Read and write enable signals
    w_data     : in  std_logic_vector (B-1 downto 0); -- Input data to be written
    empty, full: out std_logic;                    -- Status flags: empty and full
    r_data     : out std_logic_vector (B-1 downto 0)  -- Output data read from FIFO
  );
end fifo;

architecture arch of fifo is
  -- Internal storage register (single byte FIFO)
  signal array_reg: std_logic_vector(B-1 downto 0);
  
  -- Status flags: current and next state
  signal full_reg, empty_reg, full_next, empty_next: std_logic;
  
  -- Combined operation signal: concatenation of write and read signals
  -- "00" = no operation, "01" = read, "10" = write, "11" = simultaneous read/write
  signal wr_op: std_logic_vector(1 downto 0);
  
  -- Write enable signal: only active when FIFO is not full
  signal wr_en: std_logic;
begin
  -- Data storage register process
  -- Stores input data when write is enabled and FIFO is not full
  process(clk, reset)
  begin
    if (reset = '1') then
      -- Reset: clear all data
      array_reg <= (others => '0');
    elsif (clk'event and clk = '1') then
      -- Write data only when write enable is active
      if wr_en = '1' then
        array_reg <= w_data;
      end if;
    end if;
  end process;

  -- Read port: data is always available at output (combinational)
  -- Since this is a single-byte FIFO, reading is simply outputting the register
  r_data <= array_reg;

  -- Write enable logic: only allow write when FIFO is not full
  -- This prevents overflow conditions
  wr_en <= wr and (not full_reg);

  -- FIFO control logic: status flags register
  -- This process updates the full and empty flags based on operations
  process(clk, reset)
  begin
    if (reset = '1') then
      -- Reset: FIFO starts empty
      full_reg  <= '0';
      empty_reg <= '1';
    elsif (clk'event and clk = '1') then
      -- Update flags with next state values
      full_reg  <= full_next;
      empty_reg <= empty_next;
    end if;
  end process;

  -- Next-state logic for status flags
  -- Determines the next state of full/empty flags based on current operation
  wr_op <= wr & rd;  -- Combine write and read signals for state machine
  
  process(wr_op, empty_reg, full_reg)
  begin
    -- Default: maintain current state
    full_next  <= full_reg;
    empty_next <= empty_reg;
    
    case wr_op is
      when "00" =>  -- No operation: maintain current state
        null;
        
      when "01" =>  -- Read operation
        if (empty_reg /= '1') then
          -- If not empty, reading will make it empty
          full_next  <= '0';
          empty_next <= '1';
        end if;
        
      when "10" =>  -- Write operation
        if (full_reg /= '1') then
          -- If not full, writing will make it full
          empty_next <= '0';
          full_next  <= '1';
        end if;
        
      when others =>  -- Simultaneous read/write: maintain state
        -- In this implementation, simultaneous operations don't change state
        null;
    end case;
  end process;

  -- Output assignments: connect internal registers to output ports
  full  <= full_reg;
  empty <= empty_reg;
end arch;
