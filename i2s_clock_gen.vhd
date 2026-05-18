----------------------------------------------------------------------------
--  ENGS 128
--  Author: Jaden Parker
----------------------------------------------------------------------------
-- 0. Add libraries
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;

library UNISIM;
use UNISIM.VComponents.all;     -- contains BUFG clock buffer
----------------------------------------------------------------------------
-- 1. Entity Definition
entity i2s_clock_gen is				
    Port ( clk_MCLK_i : in  STD_LOGIC;				
     --      clk_MCLK_o 	: out STD_LOGIC;
           clk_BCLK_o 	: out STD_LOGIC;
           clk_LRCLK_BUFG_o 	: out  STD_LOGIC;
		   clk_LRCLK_raw_o 	: out  STD_LOGIC);
end i2s_clock_gen;						

----------------------------------------------------------------------------
-- 2. Architecture Definition 
architecture Behavioral of i2s_clock_gen is
----------------------------------------------------------------------------
-- 3. Define internal constants, signals, and components used inside this entity
-- 3a. Define constants
constant MCLK_TO_BCLK_RATIO : integer := 4;
constant BCLK_TO_LRCLK_RATIO : integer := 64;
----------------------------------------------------------------------------
-- 3b. Define signals
signal mclk_sig  : std_logic := '0'; 
signal bclk_sig : std_logic := '0';
signal lrclk_sig : std_logic := '0';
signal lrclk_count   : integer := 0;
----------------------------------------------------------------------------
-- 3c. List all component declarations

component clock_divider is 
    Generic (CLK_DIV_RATIO : integer := 25_000_000);
	Port (fast_clk_i : in STD_LOGIC;		  
            slow_clk_o : out STD_LOGIC);	-- list the component's ports in the correct order (as defined in its entity file) 
end component;	


begin
mclk_sig <= clk_MCLK_i;
----------------------------------------------------------------------------
-- 4. Instantiate any components used in this entity

clock_divider_inst_1 : clock_divider  --BCLK
    generic map ( 		
		CLK_DIV_RATIO => MCLK_TO_BCLK_RATIO)
    port map (			
        fast_clk_i => mclk_sig ,
        slow_clk_o => bclk_sig);

lrclk_bufg : BUFG
    port map (
        I => lrclk_sig,
        O => clk_LRCLK_BUFG_o);
----------------------------------------------------------------------------
-- 5. Processes



lrclk_gen : process(bclk_sig)
begin
    if falling_edge(bclk_sig ) then
        if (lrclk_count = BCLK_TO_LRCLK_RATIO/2-1) then
            lrclk_count <= 0; -- reset
            lrclk_sig <= not lrclk_sig;
        else
            lrclk_count <= lrclk_count + 1;
        end if;
    end if;
end process lrclk_gen;

clk_LRCLK_raw_o <= lrclk_sig;
clk_BCLK_o <= bclk_sig;
end Behavioral;

