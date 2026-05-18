----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: AXI stream wrapper for controlling I2S audio data flow
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;       
library UNISIM;
use UNISIM.VComponents.all;                             
----------------------------------------------------------------------------
-- Entity definition
entity axis_i2s_wrapper is
	generic (
		-- Parameters of Axi Stream Bus Interface S00_AXIS, M00_AXIS
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32
	);
    Port ( 
        --AXI DDS Outside 
        l_dds_i : in std_logic_vector(24-1 downto 0);       
        r_dds_i : in std_logic_vector(24-1 downto 0);
        input_sel_i : in std_logic;
        ----------------------------------------------------------------------------
        -- Fabric clock from Zynq PS or Clocking Wizard in block design
		clk_i : in  std_logic;	
		mclk_i : in std_logic; --mclk generated from clocking wizard
		
		
		lrclk_raw_o : out std_logic;
		lrclk_bufg_o : out std_logic;
        ----------------------------------------------------------------------------
        -- I2S audio codec ports		
		-- User controls
	--	ac_mute_en_i : in STD_LOGIC;
		
		-- Audio Codec I2S controls
        ac_bclk_o : out STD_LOGIC;
        ac_mclk_o : out STD_LOGIC;
        ac_mute_n_o : out STD_LOGIC;	-- Active Low
        
        -- Audio Codec DAC (audio out)
        ac_dac_data_o : out STD_LOGIC;
        ac_dac_lrclk_o : out STD_LOGIC;
        
        -- Audio Codec ADC (audio in)
        ac_adc_data_i : in STD_LOGIC;
        ac_adc_lrclk_o : out STD_LOGIC;
        
        ----------------------------------------------------------------------------
        -- AXI Stream Interface (Receiver/Responder)
    	-- Ports of Axi Responder Bus Interface S00_AXIS
		s00_axis_aclk     : in std_logic;
		s00_axis_aresetn  : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic;
		
        -- AXI Stream Interface (Tranmitter/Controller)
		-- Ports of Axi Controller Bus Interface M00_AXIS
		m00_axis_aclk     : in std_logic;
		m00_axis_aresetn  : in std_logic;
		m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic;
		--Debug Ports (ILA)
		dbg_left_audio_rx_o : out std_logic_vector(23 downto 0); --left audio rx from codec
		dbg_left_audio_tx_o : out std_logic_vector(23 downto 0);--left audio tx to codec
		dbg_right_audio_rx_o : out std_logic_vector(23 downto 0);--right audio rx from codec
		dbg_right_audio_tx_o : out std_logic_vector(23 downto 0)); --right audio tx to codec
		
end axis_i2s_wrapper;
----------------------------------------------------------------------------
architecture Behavioral of axis_i2s_wrapper is
----------------------------------------------------------------------------
-- Define Constants and Signals
----------------------------------------------------------------------------
constant AC_DATA_WIDTH : integer := 24;
constant DDS_DATA_WIDTH : integer := 24;
constant DDS_PHASE_DATA_WIDTH: integer := 12;

signal bclk : std_logic;
signal lrclk : std_logic;
signal lrclk_raw : std_logic;

signal l_data_axis_tx : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal r_data_axis_tx : std_logic_vector(AC_DATA_WIDTH-1 downto 0);



signal l_data_sync1, l_data_sync2, r_data_sync1, r_data_sync2 : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal l_dds_sync1, r_dds_sync1, l_dds_sync2, r_dds_sync2 : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal l_data_sync01, l_data_sync02, r_data_sync01, r_data_sync02 : std_logic_vector(AC_DATA_WIDTH-1 downto 0);



signal l_data_axis_rx : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal r_data_axis_rx : std_logic_vector(AC_DATA_WIDTH-1 downto 0);

signal l_data_selected : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
signal r_data_selected : std_logic_vector(AC_DATA_WIDTH-1 downto 0);
----------------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------------
-- Clock generation
component i2s_clock_gen is				
    Port ( clk_MCLK_i : in  STD_LOGIC;				
           clk_BCLK_o 	: out STD_LOGIC;
           clk_LRCLK_BUFG_o 	: out  STD_LOGIC;
		   clk_LRCLK_raw_o 	: out  STD_LOGIC);
end component;	

---------------------------------------------------------------------------- 
 -- I2S receiver
component i2s_receiver is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		bclk_i    : in std_logic;	
		lrclk_raw_i   : in std_logic;
		
		-- Data
		left_audio_data_o     : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_o    : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		adc_serial_data_i     : in std_logic;  
		enable_i              : in std_logic := '1';
		shift_done_o          : out std_logic);  
end component;
	
	
---------------------------------------------------------------------------- 
-- I2S transmitter

component i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port (

        -- Timing
		bclk_i    : in std_logic;	
		lrclk_raw_i   : in std_logic;
		
		-- Data
		left_audio_data_i     : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
		right_audio_data_i    : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        enable_i      : in std_logic := '1';
		dac_serial_data_o     : out std_logic;
		shift_done_o          : out std_logic);  
end component;

---------------------------------------------------------------------------- 
-- AXI stream transmitter
component axis_transmitter is
	generic (
		C_AXI_STREAM_DATA_WIDTH	: integer	:= C_AXI_STREAM_DATA_WIDTH;
		AC_DATA_WIDTH : integer := AC_DATA_WIDTH);    
    Port (
        lrclk_raw : in std_logic;
        l_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        r_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
 --       sysclk_i : in std_logic;
        aresetn : in std_logic;
		m00_axis_aclk     : in std_logic;        
        m00_axis_tvalid   : out std_logic;
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic);
end component;
    
---------------------------------------------------------------------------- 
-- AXI stream receiver
component axis_responder is
	generic (
		C_AXI_STREAM_DATA_WIDTH	: integer	:= C_AXI_STREAM_DATA_WIDTH;
		AC_DATA_WIDTH : integer := AC_DATA_WIDTH);    
    Port (
        lrclk_raw : in std_logic;
        l_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        r_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        
        l_valid_o : out std_logic;
        r_valid_o : out std_logic;
        
        aresetn : in std_logic;
		s00_axis_aclk      : in std_logic;		
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic);
end component;
----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Component instantiations
    -- Ports connected such that only AXI Stream and external I2S Ports remain to be connected outside the wrapper
----------------------------------------------------------------------------    
-- Clock generation
clock_gen_inst: i2s_clock_gen
    port map (clk_MCLK_i => mclk_i,		
           clk_BCLK_o => bclk,
           clk_LRCLK_BUFG_o => lrclk,
		   clk_LRCLK_raw_o => lrclk_raw   
    );

---------------------------------------------------------------------------- 
-- I2S receiver
i2s_receiver_inst: i2s_receiver
    port map (
		bclk_i => bclk,
		lrclk_raw_i => lrclk_raw,
		
		-- Data
		left_audio_data_o => l_data_axis_tx,
		right_audio_data_o => r_data_axis_tx,
		adc_serial_data_i => ac_adc_data_i,
		enable_i => '1',
		shift_done_o => open
    );

---------------------------------------------------------------------------- 
-- I2S transmitter
i2s_transmitter_inst: i2s_transmitter
    port map (

        -- Timing
		bclk_i => bclk,
		lrclk_raw_i => lrclk_raw,
		
		-- Data
		left_audio_data_i => l_data_sync02,
		right_audio_data_i => r_data_sync02,
        enable_i => '1',
		dac_serial_data_o => ac_dac_data_o,
		shift_done_o => open  --not used
    );

---------------------------------------------------------------------------- 
-- AXI stream transmitter
axis_transmitter_inst: axis_transmitter
    port map (
        lrclk_raw => lrclk_raw,
        l_data_i => l_data_selected,
        r_data_i => r_data_selected,
        m00_axis_aclk => m00_axis_aclk,
        aresetn => m00_axis_aresetn,
        m00_axis_tvalid => m00_axis_tvalid,
		m00_axis_tdata => m00_axis_tdata,
		m00_axis_tstrb => m00_axis_tstrb,
		m00_axis_tlast => m00_axis_tlast,
		m00_axis_tready => m00_axis_tready
    );
    
---------------------------------------------------------------------------- 
-- AXI stream responder
axis_responder_inst: axis_responder
    port map (
        lrclk_raw => lrclk_raw,
        l_data_o => l_data_axis_rx,
        r_data_o => r_data_axis_rx,
        
        l_valid_o => open,
        r_valid_o => open,
        
        s00_axis_aclk => s00_axis_aclk,
        aresetn => s00_axis_aresetn,
        s00_axis_tvalid => s00_axis_tvalid,
		s00_axis_tdata => s00_axis_tdata,
		s00_axis_tstrb => s00_axis_tstrb,
		s00_axis_tlast => s00_axis_tlast,
		s00_axis_tready => s00_axis_tready  
    );
    
---------------------------------------------------------------------------- 
-- ODDRs below for clock forwarding to audio codec
m_clk_forward : ODDR
    generic map(
        DDR_CLK_EDGE => "SAME_EDGE", 
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => ac_mclk_o, -- The output pin
        C  => mclk_i,     -- The internal clock source
        CE => '1',          -- Clock Enable
        D1 => '1',          -- High on rising edge
        D2 => '0',          -- Low on falling edge
        R  => '0', 
        S  => '0'
    );
    
b_clk_forward : ODDR
    generic map(
        DDR_CLK_EDGE => "SAME_EDGE", 
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => ac_bclk_o, -- The output pin
        C  => bclk,     -- The internal clock source
        CE => '1',          -- Clock Enable
        D1 => '1',          -- High on rising edge
        D2 => '0',          -- Low on falling edge
        R  => '0', 
        S  => '0'
    );

ac_dac_lrclk_forward : ODDR
    generic map(
        DDR_CLK_EDGE => "SAME_EDGE", 
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => ac_dac_lrclk_o, -- The output pin
        C  => lrclk,     -- The internal clock source
        CE => '1',          -- Clock Enable
        D1 => '1',          -- High on rising edge
        D2 => '0',          -- Low on falling edge
        R  => '0', 
        S  => '0'
    );   

ac_adc_lrclk_forward : ODDR
    generic map(
        DDR_CLK_EDGE => "SAME_EDGE", 
        INIT         => '0',
        SRTYPE       => "SYNC")
    port map (
        Q  => ac_adc_lrclk_o, -- The output pin
        C  => lrclk,     -- The internal clock source
        CE => '1',          -- Clock Enable
        D1 => '1',          -- High on rising edge
        D2 => '0',          -- Low on falling edge
        R  => '0', 
        S  => '0'
    );       
---------------------------------------------------------------------------- 
-- Logic
---------------------------------------------------------------------------- 
ac_mute_n_o <= '1'; --mute never enabled
lrclk_raw_o <= lrclk_raw;
lrclk_bufg_o <= lrclk;
----------
--DDS/AC Input Selection mux 
input_sel_mux: process(input_sel_i, l_dds_sync2, r_dds_sync2, l_data_sync2, r_data_sync2)
begin
    case input_sel_i is 
        when '0' =>
            l_data_selected <= l_dds_sync2;
            r_data_selected <= r_dds_sync2;
        when '1' =>
            l_data_selected <= l_data_sync2;
            r_data_selected <= r_data_sync2;        
        when others => 
            l_data_selected <= l_data_sync2;
            r_data_selected <= r_data_sync2;              
    end case;
end process;

----------------------------------------------------------------------------
dbl_ff_sync1: process(clk_i)
begin
    if rising_edge(clk_i) then
        -- Sync both AC and DDS data
        l_data_sync1 <= l_data_axis_tx;
        r_data_sync1 <= r_data_axis_tx;
        l_data_sync2 <= l_data_sync1;
        r_data_sync2 <= r_data_sync1;
        
        -- Add DDS sync registers
        l_dds_sync1 <= l_dds_i;
        r_dds_sync1 <= r_dds_i;
        l_dds_sync2 <= l_dds_sync1;
        r_dds_sync2 <= r_dds_sync1;
    end if;
end process;

dbl_ff_sync2: process(bclk) --Double FF synchronizer between AXIS Rx and I2S Transmitter for metastability
begin
    if falling_edge(bclk) then
        l_data_sync01 <= l_data_axis_rx;
        r_data_sync01 <= r_data_axis_rx;
        l_data_sync02 <= l_data_sync01;
        r_data_sync02 <= r_data_sync01;
    end if;
end process;

--Debug hookups 
dbg_left_audio_rx_o  <= l_data_selected;-- l_data_axis_tx;
dbg_left_audio_tx_o  <= l_data_axis_rx;
dbg_right_audio_rx_o <= r_data_selected; --r_data_axis_tx;
dbg_right_audio_tx_o <= r_data_axis_rx;
end Behavioral;