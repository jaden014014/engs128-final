----------------------------------------------------------------------------
--  Final Project: AXI Stream FFT and HDMI output
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

entity axis_fft_wrapper is
    generic (
        IN_DATA_WIDTH  : integer := 32;   -- 24-bit audio inside a 32-bit word
        OUT_DATA_WIDTH : integer := 64;   -- 32-bit Real + 32-bit Imaginary
        FIFO_DEPTH     : integer := 1024; -- Depth for both FIFOs
        CONFIG_WIDTH   : integer := 16    -- Default Xilinx FFT config width
    );
    port (
        -- Global Clock and Reset
        aclk            : in  std_logic;
        aresetn         : in  std_logic;

        -- Slave Interface (Connects to your Upstream I2S/Audio Source)
        s_axis_tvalid   : in  std_logic;
        s_axis_tdata    : in  std_logic_vector(IN_DATA_WIDTH-1 downto 0);
        s_axis_tstrb    : in  std_logic_vector((IN_DATA_WIDTH/8)-1 downto 0);
        s_axis_tlast    : in  std_logic;
        s_axis_tready   : out std_logic;

        -- Master Interface (Connects to your Downstream DMA / Processor)
        m_axis_tvalid   : out std_logic;
        m_axis_tdata    : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
        m_axis_tstrb    : out std_logic_vector((OUT_DATA_WIDTH/8)-1 downto 0);
        m_axis_tlast    : out std_logic;
        m_axis_tready   : in  std_logic
    );
end axis_fft_wrapper;

architecture Structural of axis_fft_wrapper is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------ 
component axis_fifo is
    generic (
        DATA_WIDTH : integer := 32;
        FIFO_DEPTH : integer := 1024
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
I need fft_feeder_fsm
-- FFT IP 
component axis_fft is
    port (
        aclk                 : in  std_logic;
        aresetn              : in  std_logic;
        s_axis_config_tdata  : in  std_logic_vector(CONFIG_WIDTH-1 downto 0);
        s_axis_config_tvalid : in  std_logic;
        s_axis_config_tready : out std_logic;
        s_axis_data_tdata    : in  std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
        s_axis_data_tvalid   : in  std_logic;
        s_axis_data_tready   : out std_logic;
        s_axis_data_tlast    : in  std_logic;
        m_axis_data_tdata    : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
        m_axis_data_tvalid   : out std_logic;
        m_axis_data_tready   : in  std_logic;
        m_axis_data_tlast    : out std_logic
    );
end component;

-- Signals from Input FIFO to FFT
signal fifo_in_m_tvalid  : std_logic;
signal fifo_in_m_tdata   : std_logic_vector(IN_DATA_WIDTH-1 downto 0);
signal fifo_in_m_tstrb   : std_logic_vector((IN_DATA_WIDTH/8)-1 downto 0);
signal fifo_in_m_tlast   : std_logic;
signal fifo_in_m_tready  : std_logic;

-- FFT Data Input
signal fft_s_tdata       : std_logic_vector(OUT_DATA_WIDTH-1 downto 0);


signal config_tvalid     : std_logic := '0';
signal config_tready     : std_logic;
signal config_done       : std_logic := '0';

-- Signals from FFT  to output FIFO
signal fft_m_tvalid      : std_logic;
signal fft_m_tdata       : std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
signal fft_m_tlast       : std_logic;
signal fft_m_tready      : std_logic;

begin

------------------------------------------------------------------------
-- 1. Input FIFO Instantiation (32-bit Data Width)
------------------------------------------------------------------------
input_fifo_inst : axis_fifo
    generic map (
        DATA_WIDTH => IN_DATA_WIDTH,
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
        m00_axis_tvalid   => fifo_in_m_tvalid,
        m00_axis_tdata    => fifo_in_m_tdata,
        m00_axis_tstrb    => fifo_in_m_tstrb,
        m00_axis_tlast    => fifo_in_m_tlast,
        m00_axis_tready   => fifo_in_m_tready
    );

------------------------------------------------------------------------
-- 2. Data Bus Packing (Real Audio Data -> Complex FFT Format)
------------------------------------------------------------------------
-- zeros for real Audio
fft_s_tdata <= (63 downto 32 => '0') & fifo_in_m_tdata;

------------------------------------------------------------------------
-- 3. Automated FFT Configuration State Machine
------------------------------------------------------------------------
process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            config_tvalid <= '0';
            config_done   <= '0';
        else
            if config_done = '0' then
                config_tvalid <= '1';
                if config_tready = '1' and config_tvalid = '1' then
                    config_tvalid <= '0';
                    config_done   <= '1';
                end if;
            else
                config_tvalid <= '0';
            end if;
        end if;
    end if;
end process;

------------------------------------------------------------------------
-- 4. Xilinx FFT IP Core Instantiation
------------------------------------------------------------------------
fft_core_inst : axis_fft
    port map (
        aclk                 => aclk,
        aresetn              => aresetn,

        -- Automated configuration (Config Vector = 1 for Forward FFT)
        s_axis_config_tdata  => std_logic_vector(to_unsigned(1, CONFIG_WIDTH)), 
        s_axis_config_tvalid => config_tvalid,
        s_axis_config_tready => config_tready,

        -- Input Stream (From Input FIFO output)
        s_axis_data_tdata    => fft_s_tdata,
        s_axis_data_tvalid   => fifo_in_m_tvalid,
        s_axis_data_tready   => fifo_in_m_tready,
        s_axis_data_tlast    => fifo_in_m_tlast,

        -- Output Stream (Directly maps into Output FIFO input)
        m_axis_data_tdata    => fft_m_tdata,
        m_axis_data_tvalid   => fft_m_tvalid,
        m_axis_data_tready   => fft_m_tready,
        m_axis_data_tlast    => fft_m_tlast
    );

------------------------------------------------------------------------
-- 5. Output FIFO Instantiation (64-bit Data Width)
------------------------------------------------------------------------
output_fifo_inst : axis_fifo
    generic map (
        DATA_WIDTH => OUT_DATA_WIDTH,
        FIFO_DEPTH => FIFO_DEPTH
    )
    port map (
        s00_axis_aclk     => aclk,
        s00_axis_aresetn  => aresetn,
        s00_axis_tvalid   => fft_m_tvalid,
        s00_axis_tdata    => fft_m_tdata,
        s00_axis_tstrb    => (others => '1'), -- Strobe fully active for complex data
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

end Structural;