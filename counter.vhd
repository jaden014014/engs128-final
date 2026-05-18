----------------------------------------------------------------------------
-- 	ENGS 128
--	Author: Kendall Farnham
----------------------------------------------------------------------------
--	Description: scalable counter with terminal count status flag
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity counter is
    Generic ( MAX_COUNT : integer := 100);   
    Port (  clk_i       : in STD_LOGIC;			
            reset_i     : in STD_LOGIC;		
            enable_i    : in STD_LOGIC;				
            tc_o        : out STD_LOGIC);
end counter;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of counter is

----------------------------------------------------------------------------
-- Define Constants and Signals
signal count_int : integer range 0 to MAX_COUNT-1 := 0;

begin
----------------------------------------------------------------------------
-- Assign output ports from signals
tc_o <= '1' when count_int = MAX_COUNT-1 else '0';

----------------------------------------------------------------------------
-- Counter logic
incrementer_logic : process(clk_i)
begin
	if falling_edge(clk_i) then
	   if (reset_i = '1') then 
	       count_int <= 0;
	   elsif (enable_i = '1') then 
	       if (count_int = MAX_COUNT-1) then 
	           count_int <= 0;                 -- reset counter to 0
	       else
	           count_int <= count_int + 1;     -- increment
	       end if;
        end if;
	end if;
end process incrementer_logic;


end Behavioral;