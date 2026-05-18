----------------------------------------------------------------------------
-- 	ENGS 128 Spring 2025
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: Shift register with parallel read and serial input
----------------------------------------------------------------------------
-- Add libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity rx_shift_register is
    Generic ( DATA_WIDTH : integer := 16);
    Port ( 
      clk_i         : in std_logic;
      data_i        : in std_logic;
      read_en_i     : in std_logic;
      shift_en_i    : in std_logic;
      
      data_o        : out std_logic_vector(DATA_WIDTH-1 downto 0));
end rx_shift_register;
----------------------------------------------------------------------------
architecture Behavioral of rx_shift_register is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- ++++ Add internal signals here ++++
signal shift_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
signal output_buffer_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- ++++ Describe the behavior using processes ++++
----------------------------------------------------------------------------     
data_o <= output_buffer_reg;
----------------------------------------------------------------------------
-- Shift register logic
shift_reg_logic : process (clk_i)
begin
	if (rising_edge(clk_i)) then
	   if (read_en_i = '1') then 
	       output_buffer_reg  <= shift_reg;
	   elsif (shift_en_i = '1') then
	       shift_reg <= shift_reg(DATA_WIDTH-2 downto 0) & data_i; -- shift in new data
	   end if;
	end if;
end process shift_reg_logic;

----------------------------------------------------------------------------   
end Behavioral;