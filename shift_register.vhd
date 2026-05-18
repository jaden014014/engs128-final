----------------------------------------------------------------------------
-- 	ENGS 128 Spring 2025
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: Shift register with parallel load and serial output
----------------------------------------------------------------------------
-- Add libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity shift_register is
    Generic ( DATA_WIDTH : integer := 16);
    Port ( 
      clk_i         : in std_logic;
      data_i        : in std_logic_vector(DATA_WIDTH-1 downto 0);
      load_en_i     : in std_logic;
      shift_en_i    : in std_logic;
      
      data_o        : out std_logic);
end shift_register;
----------------------------------------------------------------------------
architecture Behavioral of shift_register is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
-- ++++ Add internal signals here ++++
signal shift_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- ++++ Describe the behavior using processes ++++
----------------------------------------------------------------------------     
data_o <= shift_reg(DATA_WIDTH-1);  -- hook up to MSB

----------------------------------------------------------------------------
-- Shift register logic
shift_reg_logic : process (clk_i)
begin
	if (falling_edge(clk_i)) then
	   if (load_en_i = '1') then       -- load takes priority
	       shift_reg <= data_i;
	   elsif (shift_en_i = '1') then
	       shift_reg <= shift_reg(DATA_WIDTH-2 downto 0) & shift_reg(DATA_WIDTH-1); -- circular shift
	   end if;
	end if;
end process shift_reg_logic;

----------------------------------------------------------------------------   
end Behavioral;