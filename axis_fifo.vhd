----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128 
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: AXI Stream FIFO Controller/Responder Interface 
----------------------------------------------------------------------------
-- Library Declarations
library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------------
-- Entity definition
entity axis_fifo is
	generic (
		DATA_WIDTH	: integer	:= 32; --Still generic FIFO size
		FIFO_DEPTH	: integer	:= 1024
	);
	port (
		-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
		s00_axis_tstrb    : in std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '1');
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;

		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '1');
		m00_axis_tlast    : out std_logic := '0';
		m00_axis_tready   : in std_logic
	);
end axis_fifo;

----------------------------------------------------------------------------
-- Architecture Definition 
architecture Behavioral of axis_fifo is
----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------  
signal write : std_logic := '0';
signal read : std_logic := '0';
signal empty, full : std_logic := '0';
signal reset : std_logic := '0';

----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------  
component fifo is
    Generic (
		FIFO_DEPTH : integer := FIFO_DEPTH;
        DATA_WIDTH : integer := DATA_WIDTH);
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
end component fifo;

----------------------------------------------------------------------------
begin

----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------   

fifo_inst: fifo
    port map (
    clk_i => s00_axis_aclk,
    reset_i => reset,
    wr_en_i => write,
    wr_data_i => s00_axis_tdata,
    rd_en_i => read,
    rd_data_o => m00_axis_tdata,
    empty_o => empty,
    full_o => full);
----------------------------------------------------------------------------    
reset <= not s00_axis_aresetn;		
----------------------------------------------------------------------------
-- Logic
----------------------------------------------------------------------------  
write <= s00_axis_tvalid and (not full); -- write to fifo if upstream axi is valid and fifo is not full
read <= m00_axis_tready and (not empty); --read from fifo if downstream axi is ready and fifo is not empty

s00_axis_tready <= not full and s00_axis_aresetn; --tell upstream axi we are ready if fifo is not full and we're not being reset
m00_axis_tvalid <= not empty and m00_axis_aresetn; --tell downstream axi we are ready if fifo is not empty and we're not being reset

end Behavioral;
