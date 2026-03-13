-- key2ascii.vhdl
-- PS/2 to ASCII Conversion Look-Up Table (LUT)
-- This module implements a combinational conversion from PS/2 scan codes
-- (Scan Code Set 2) to ASCII character codes. The conversion is performed
-- using a with-select statement, which creates a hardware lookup table.
-- All letters are converted to uppercase ASCII (A-Z: 0x41-0x5A).
-- This is a purely combinational circuit with zero latency.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key2ascii is
  port (
    key_code   : in  std_logic_vector(7 downto 0); -- PS/2 scan code input (Set 2)
    ascii_code : out std_logic_vector(7 downto 0)  -- ASCII character code output
  );
end key2ascii;

architecture arch of key2ascii is
begin
  -- Combinational conversion using with-select statement
  -- Maps each PS/2 scan code to its corresponding ASCII character
  -- The mapping follows the PS/2 Scan Code Set 2 standard
  with key_code select
    ascii_code <=
      -- Numeric keys: 0-9
      "00110000" when "01000101", -- 0 -> ASCII '0' (0x30)
      "00110001" when "00010110", -- 1 -> ASCII '1' (0x31)
      "00110010" when "00011110", -- 2 -> ASCII '2' (0x32)
      "00110011" when "00100110", -- 3 -> ASCII '3' (0x33)
      "00110100" when "00100101", -- 4 -> ASCII '4' (0x34)
      "00110101" when "00101110", -- 5 -> ASCII '5' (0x35)
      "00110110" when "00110110", -- 6 -> ASCII '6' (0x36)
      "00110111" when "00111101", -- 7 -> ASCII '7' (0x37)
      "00111000" when "00111110", -- 8 -> ASCII '8' (0x38)
      "00111001" when "01000110", -- 9 -> ASCII '9' (0x39)

      -- Alphabetic keys: A-Z (uppercase only)
      "01000001" when "00011100", -- A -> ASCII 'A' (0x41)
      "01000010" when "00110010", -- B -> ASCII 'B' (0x42)
      "01000011" when "00100001", -- C -> ASCII 'C' (0x43)
      "01000100" when "00100011", -- D -> ASCII 'D' (0x44)
      "01000101" when "00100100", -- E -> ASCII 'E' (0x45)
      "01000110" when "00101011", -- F -> ASCII 'F' (0x46)
      "01000111" when "00110100", -- G -> ASCII 'G' (0x47)
      "01001000" when "00110011", -- H -> ASCII 'H' (0x48)
      "01001001" when "01000011", -- I -> ASCII 'I' (0x49)
      "01001010" when "00111011", -- J -> ASCII 'J' (0x4A)
      "01001011" when "01000010", -- K -> ASCII 'K' (0x4B)
      "01001100" when "01001011", -- L -> ASCII 'L' (0x4C)
      "01001101" when "00111010", -- M -> ASCII 'M' (0x4D)
      "01001110" when "00110001", -- N -> ASCII 'N' (0x4E)
      "01001111" when "01000100", -- O -> ASCII 'O' (0x4F)
      "01010000" when "01001101", -- P -> ASCII 'P' (0x50)
      "01010001" when "00010101", -- Q -> ASCII 'Q' (0x51)
      "01010010" when "00101101", -- R -> ASCII 'R' (0x52)
      "01010011" when "00011011", -- S -> ASCII 'S' (0x53)
      "01010100" when "00101100", -- T -> ASCII 'T' (0x54)
      "01010101" when "00111100", -- U -> ASCII 'U' (0x55)
      "01010110" when "00101010", -- V -> ASCII 'V' (0x56)
      "01010111" when "00011101", -- W -> ASCII 'W' (0x57)
      "01011000" when "00100010", -- X -> ASCII 'X' (0x58)
      "01011001" when "00110101", -- Y -> ASCII 'Y' (0x59)
      "01011010" when "00011010", -- Z -> ASCII 'Z' (0x5A)

      -- Special character keys
      "01100000" when "00001110", -- Grave accent (`) -> ASCII '`' (0x60)
      "00101101" when "01001110", -- Minus sign -> ASCII '-' (0x2D)
      "00111101" when "01010101", -- Equals sign -> ASCII '=' (0x3D)
      "01011011" when "01010100", -- Left bracket -> ASCII '[' (0x5B)
      "01011101" when "01011011", -- Right bracket -> ASCII ']' (0x5D)
      "01011100" when "01011101", -- Backslash -> ASCII '\' (0x5C)
      "00111011" when "01001100", -- Semicolon -> ASCII ';' (0x3B)
      "00100111" when "01010010", -- Apostrophe -> ASCII ''' (0x27)
      "00101100" when "01000001", -- Comma -> ASCII ',' (0x2C)
      "00101110" when "01001001", -- Period -> ASCII '.' (0x2E)
      "00101111" when "01001010", -- Slash -> ASCII '/' (0x2F)

      -- Control keys
      "00100000" when "00101001", -- Space bar -> ASCII space (0x20)
      "00001101" when "01011010", -- Enter key -> ASCII carriage return (0x0D)
      "00001000" when "01100110", -- Backspace -> ASCII backspace (0x08)
      
      -- Default case: unmapped keys return asterisk
      -- This serves as an indicator for unrecognized scan codes
      "00101010" when others;     -- Default -> ASCII '*' (0x2A)
end arch;
