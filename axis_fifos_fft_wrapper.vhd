----------------------------------------------------------------------------
--  Final Project: AXI Stream FFT and HDMI
----------------------------------------------------------------------------
--  ENGS 128 
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: AXI Stream FIFO and FFT and fft_feeder_fsm interface
----------------------------------------------------------------------------
-- Library Declarations
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_fifos_fft_wrapper is
    generic (
        DATA_WIDTH : integer := 32;  
        FIFO_DEPTH     : integer := 64; 
        CONFIG_WIDTH   : integer := 16; 
        FFT_DATA_WIDTH : integer := 48  
    );
    port (

        aclk            : in  std_logic;
        aresetn         : in  std_logic;
        lrclk_raw      : in  std_logic;
        lrclk_bufg      : in  std_logic;

        s_axis_tvalid   : in  std_logic;
        s_axis_tdata    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_tstrb    : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        s_axis_tlast    : in  std_logic;
        s_axis_tready   : out std_logic;


        m_axis_tvalid   : out std_logic;
        m_axis_tdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m_axis_tstrb    : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        m_axis_tlast    : out std_logic;
        m_axis_tready   : in  std_logic
    );
end axis_fifos_fft_wrapper;

architecture Behavioral of axis_fifos_fft_wrapper is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------ 
component axis_fifo is
    generic (
        DATA_WIDTH : integer := DATA_WIDTH;
        FIFO_DEPTH : integer := FIFO_DEPTH
    );
    port (
        s00_axis_aclk    : in std_logic;
        s00_axis_aresetn : in std_logic;
        s00_axis_tready  : out std_logic;
        s00_axis_tdata   : in std_logic_vector(DATA_WIDTH-1 downto 0);
        s00_axis_tstrb   : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        s00_axis_tlast   : in std_logic;
        s00_axis_tvalid  : in std_logic;

        m00_axis_aclk    : in std_logic;
        m00_axis_aresetn : in std_logic;
        m00_axis_tvalid  : out std_logic;
        m00_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        m00_axis_tstrb   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
        m00_axis_tlast   : out std_logic;
        m00_axis_tready  : in std_logic
    );
end component;

component fft_feeder_fsm is
	generic (
		FIFO_DEPTH	: integer	:= 64;
		FFT_DATA_WIDTH : integer	:= FFT_DATA_WIDTH
	);    
    Port ( 
        --Config ports 
        config_tdata_o : out std_logic_vector(15 downto 0);
        config_tvalid_o : out std_logic;       
        config_tready_i : in std_logic;  
        
        lrclk_bufg : in std_logic;
        aclk     : in std_logic;
		aresetn  : in std_logic;

		tlast_o    : out std_logic
    );
end component;

-- FFT IP 
component axis_fft is
    port (
        aclk                 : in  std_logic;
        aresetn              : in  std_logic;
        s_axis_config_tdata  : in  std_logic_vector(CONFIG_WIDTH-1 downto 0);
        s_axis_config_tvalid : in  std_logic;
        s_axis_config_tready : out std_logic;
        s_axis_data_tdata    : in  std_logic_vector(FFT_DATA_WIDTH-1 downto 0);
        s_axis_data_tvalid   : in  std_logic;
        s_axis_data_tready   : out std_logic;
        s_axis_data_tlast    : in  std_logic;
        m_axis_data_tdata    : out std_logic_vector(FFT_DATA_WIDTH-1 downto 0);
        m_axis_data_tvalid   : out std_logic;
        m_axis_data_tready   : in  std_logic;
        m_axis_data_tuser    : out std_logic_vector(8-1 downto 0);
        m_axis_data_tlast    : out std_logic
    );
end component;

component counter is
    Generic ( MAX_COUNT : integer);   
    Port (  clk_i       : in STD_LOGIC;			
            reset_i     : in STD_LOGIC;		
            enable_i    : in STD_LOGIC;				
            tc_o        : out STD_LOGIC);
end component counter;

-- Signals from Input FIFO to L and R data fifos
signal fifo_0_m_tvalid  : std_logic;
signal fifo_0_m_tdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_0_m_tstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
signal fifo_0_m_tlast   : std_logic;
signal fifo_0_m_tready  : std_logic;

signal fifo_l_s_tvalid  : std_logic;
signal fifo_l_s_tdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_l_s_tstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
signal fifo_l_s_tlast   : std_logic;
signal fifo_l_s_tready  : std_logic;

signal fifo_l_m_tvalid  : std_logic;
signal fifo_l_m_tdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_l_m_tstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
signal fifo_l_m_tlast   : std_logic;
signal fifo_l_m_tready  : std_logic;

signal fifo_r_s_tvalid  : std_logic;
signal fifo_r_s_tdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_r_s_tstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
signal fifo_r_s_tlast   : std_logic;
signal fifo_r_s_tready  : std_logic;

signal fifo_r_m_tvalid  : std_logic;
signal fifo_r_m_tdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fifo_r_m_tstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
signal fifo_r_m_tlast   : std_logic;
signal fifo_r_m_tready  : std_logic;


-- FFT Data Input
signal fft_s_tdata       : std_logic_vector(FFT_DATA_WIDTH-1 downto 0);
signal fft_s_tvalid  : std_logic;
signal fft_s_tready  : std_logic;
signal fft_s_tlast  : std_logic;

signal config_tvalid     : std_logic := '0';
signal config_tready     : std_logic;
signal config_tdata     : std_logic_vector(15 downto 0);

-- Signals from FFT  to output FIFO
signal fft_m_tvalid      : std_logic;
signal fft_m_tdata       : std_logic_vector(DATA_WIDTH-1 downto 0);
signal fft_m_tlast       : std_logic;
signal fft_m_tready      : std_logic;


signal lrclk_raw_sync1 : std_logic;
signal lrclk_raw_sync2 : std_logic;

signal lrclk_bufg_sync1 : std_logic;
signal lrclk_bufg_sync2 : std_logic;

signal tc_l : std_logic;
signal tc_r : std_logic;
signal reset_l : std_logic;
signal reset_r : std_logic;

type state_type is (LeftSelect, RightSelect);	
signal curr_state, next_state : state_type := RightSelect;

begin

------------------------------------------------------------------------
-- Fifo 0 goes to either fifo l or fifo r depending on lrclk
------------------------------------------------------------------------
input_fifo_inst : axis_fifo
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        s00_axis_aclk     => aclk,
        s00_axis_aresetn  => aresetn,
        s00_axis_tvalid   => s_axis_tvalid,
        s00_axis_tdata    => s_axis_tdata,
        s00_axis_tstrb    => s_axis_tstrb,
        s00_axis_tlast    => s_axis_tlast,
        s00_axis_tready   => s_axis_tready,

        m00_axis_aclk     => aclk,
        m00_axis_aresetn  => aresetn,
        m00_axis_tvalid   => fifo_0_m_tvalid,
        m00_axis_tdata    => fifo_0_m_tdata,
        m00_axis_tstrb    => fifo_0_m_tstrb,
        m00_axis_tlast    => fifo_0_m_tlast,
        m00_axis_tready   => fifo_0_m_tready
    );

input_fifo_left : axis_fifo
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        s00_axis_aclk     => aclk,
        s00_axis_aresetn  => aresetn,
        s00_axis_tvalid   => fifo_l_s_tvalid,
        s00_axis_tdata    => fifo_l_s_tdata,
        s00_axis_tstrb    => fifo_l_s_tstrb,
        s00_axis_tlast    => fifo_l_s_tlast,
        s00_axis_tready   => fifo_l_s_tready,

        m00_axis_aclk     => aclk,
        m00_axis_aresetn  => aresetn,
        m00_axis_tvalid   => fifo_l_m_tvalid,
        m00_axis_tdata    => fifo_l_m_tdata,
        m00_axis_tstrb    => fifo_l_m_tstrb,
        m00_axis_tlast    => fifo_l_m_tlast,
        m00_axis_tready   => fifo_l_m_tready
    );
    
input_fifo_right : axis_fifo
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        s00_axis_aclk     => aclk,
        s00_axis_aresetn  => aresetn,
        s00_axis_tvalid   => fifo_r_s_tvalid,
        s00_axis_tdata    => fifo_r_s_tdata,
        s00_axis_tstrb    => fifo_r_s_tstrb,
        s00_axis_tlast    => fifo_r_s_tlast,
        s00_axis_tready   => fifo_r_s_tready,

        m00_axis_aclk     => aclk,
        m00_axis_aresetn  => aresetn,
        m00_axis_tvalid   => fifo_r_m_tvalid,
        m00_axis_tdata    => fifo_r_m_tdata,
        m00_axis_tstrb    => fifo_r_m_tstrb,
        m00_axis_tlast    => fifo_r_m_tlast,
        m00_axis_tready   => fifo_r_m_tready
    );

fft_feeder_inst: fft_feeder_fsm
    generic map(
    FIFO_DEPTH	=> FIFO_DEPTH,
    FFT_DATA_WIDTH => DATA_WIDTH
	)   
    port map(
    lrclk_bufg => lrclk_bufg_sync2,
    aclk => aclk,
    aresetn => aresetn,    
    config_tdata_o     => config_tdata,
    config_tready_i     => config_tready,
    config_tvalid_o      => config_tvalid,
    tlast_o             => fft_s_tlast
    );
    
counter_left: counter
    generic map(MAX_COUNT => 2*FIFO_DEPTH)
    port map(
    clk_i => lrclk_bufg_sync2,
    reset_i => reset_l,
    enable_i => '1',
    tc_o => tc_l);
    
counter_right: counter
    generic map(MAX_COUNT => 2*FIFO_DEPTH)
    port map(
    clk_i => lrclk_bufg_sync2,
    reset_i => reset_r,
    enable_i => '1',
    tc_o => tc_r);

fft_core_inst : axis_fft
    port map (
        aclk                 => aclk,
        aresetn              => aresetn,

        s_axis_config_tdata  => config_tdata, 
        s_axis_config_tvalid => config_tvalid,
        s_axis_config_tready => config_tready,

        -- Input Stream 
        s_axis_data_tdata    => fft_s_tdata,
        s_axis_data_tvalid   => fft_s_tvalid,
        s_axis_data_tready   => fft_s_tready,
        s_axis_data_tlast    => fft_s_tlast, --comes from fsm

        -- Output Stream 
        m_axis_data_tdata    => fft_m_tdata,
        m_axis_data_tvalid   => fft_m_tvalid,
        m_axis_data_tready   => fft_m_tready,
        m_axis_data_tlast    => fft_m_tlast
    );


output_fifo_inst : axis_fifo
    generic map (
        DATA_WIDTH => DATA_WIDTH,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        s00_axis_aclk     => aclk,
        s00_axis_aresetn  => aresetn,
        s00_axis_tvalid   => fft_m_tvalid,
        s00_axis_tdata    => (fft_m_tdata(23 downto 0) & lrclk_raw_sync2 & "0000000"),
        s00_axis_tstrb    => (others => '1'),
        s00_axis_tlast    => fft_m_tlast,
        s00_axis_tready   => fft_m_tready,

        m00_axis_aclk     => aclk,
        m00_axis_aresetn  => aresetn,
        m00_axis_tvalid   => m_axis_tvalid,
        m00_axis_tdata    => m_axis_tdata,
        m00_axis_tstrb    => m_axis_tstrb,
        m00_axis_tlast    => m_axis_tlast,
        m00_axis_tready   => m_axis_tready
    );

dbl_ff_sync: process(aclk) --Double FF synchronizer
begin
    if rising_edge(aclk) then
        lrclk_raw_sync1 <= lrclk_raw;
        lrclk_raw_sync2 <= lrclk_raw_sync1;
        lrclk_bufg_sync1 <= lrclk_bufg;
        lrclk_bufg_sync2 <= lrclk_bufg_sync1;        
    end if;
end process;

----------------------------------------------------------------------------
--FSM Next State Logic Process

next_state_logic : process(curr_state, tc_l, tc_r)
begin

	-- Add default conditions here
	next_state <= curr_state; 
    case curr_state is	

        when LeftSelect  =>	
            if tc_l = '1' then
                next_state <= RightSelect;
            end if;
            
        when RightSelect  =>	
            if tc_r = '1' then
                next_state <= LeftSelect ;
            end if;
        
        when others => 
            next_state <= LeftSelect ; 
    end case;
end process next_state_logic;

-- FSM Output Logic Process
fsm_output_logic : process(curr_state) 
begin

	-- Defaults
	reset_l  <= '0';
	reset_r <= '0';
	case curr_state is		

		when LeftSelect  =>		
	       reset_r <= '1';
		
		when RightSelect =>		
	       reset_l <= '1';
		
		when others =>
	end case;	
end process fsm_output_logic;

----------------------------------------------------------------------------
-- 5e. FSM State Update Process (synchronous, clocked)
state_update : process (lrclk_bufg_sync2)
begin
	if (rising_edge(lrclk_bufg_sync2)) then
		curr_state <= next_state; 
	end if;
end process state_update;

--Logic

fifo_l_s_tvalid <= fifo_0_m_tvalid when lrclk_raw_sync2 = '0' else '0';
fifo_r_s_tvalid <= '0'             when lrclk_raw_sync2 = '0' else fifo_0_m_tvalid;

fifo_l_s_tdata  <= fifo_0_m_tdata;
fifo_l_s_tstrb  <= fifo_0_m_tstrb;
fifo_l_s_tlast  <= fifo_0_m_tlast;
fifo_l_s_tready <= fifo_0_m_tready;

fifo_r_s_tdata  <= fifo_0_m_tdata;
fifo_r_s_tstrb  <= fifo_0_m_tstrb;
fifo_r_s_tlast  <= fifo_0_m_tlast;
fifo_r_s_tready <= fifo_0_m_tready;



fft_s_tvalid <= fifo_l_m_tvalid when tc_l = '1' else
                fifo_r_m_tvalid when tc_r = '1' else
                '0';

fft_s_tdata  <= fifo_l_m_tdata(24 downto 1) & "000000000000000000000000" when tc_l = '1' else
                fifo_r_m_tdata(24 downto 1) & "000000000000000000000000"   when tc_r = '1' else
                (others => '0');

    
end Behavioral;