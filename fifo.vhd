----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: FIFO buffer with AXI stream valid signal
----------------------------------------------------------------------------
-- Library Declarations
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------
-- Entity definition
entity fifo is
Generic (
    FIFO_DEPTH : integer := 1024; --FIFO can be any size
    DATA_WIDTH : integer := 32);
Port ( 
    clk_i       : in std_logic;
    reset_i     : in std_logic;
    
    -- Write channel
    wr_en_i     : in std_logic;
    wr_data_i   : in std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Read channel
    rd_en_i     : in std_logic;
    rd_data_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    
    -- Status flags
    empty_o         : out std_logic;
    full_o          : out std_logic);   
end fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of fifo is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
type mem_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0); --array of storage in memory
signal fifo_buf : mem_type := (others => (others => '0'));

signal read_pointer, write_pointer : integer range 0 to FIFO_DEPTH-1 := 0;
signal data_count : integer range 0 to FIFO_DEPTH := 0;  -- Changed from Fifo depth - 1
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Processes and Logic
----------------------------------------------------------------------------
process(clk_i)
begin

if rising_edge(clk_i) then

    if reset_i = '1' then -- Reset pointers and flags and output data 
        read_pointer <= 0;
        write_pointer <= 0;
        data_count <= 0;
        rd_data_o <= (others =>'0');
    else
    
        if rd_en_i = '1' then --Read if read enabled
            rd_data_o <= fifo_buf(read_pointer);
            read_pointer <= (read_pointer+1) mod (FIFO_DEPTH); --Wraparound to zero
        end if;
        
    
        if wr_en_i = '1' then --Write if write enablled
            fifo_buf(write_pointer) <= wr_data_i;
            write_pointer <= (write_pointer+1) mod (FIFO_DEPTH); --Wraparound to zero
        end if;                
       
        if data_count = 0 then --don't count below 0
            if rd_en_i = '0' and wr_en_i = '1' then
                data_count <= data_count +1;
            end if;        
        elsif data_count = FIFO_DEPTH then --Dont count above FIFO_DEPTH
            if rd_en_i = '1' and wr_en_i  = '0' then
                data_count <= data_count -1;
            end if;
        else -- count either direction
            if rd_en_i = '1' and wr_en_i  = '0' then
                data_count <= data_count -1;
            elsif rd_en_i = '0' and wr_en_i = '1' then
                data_count <= data_count +1;
            end if;
        end if;
           
    end if;
end if;
end process;

empty_o <= '1' when data_count = 0 else '0'; --Updating full and empty flags is immediate once data_count changes
full_o  <= '1' when data_count = FIFO_DEPTH else '0';
end Behavioral;
