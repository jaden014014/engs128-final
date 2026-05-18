----------------------------------------------------------------------------
--  Lab 3: Streaming Audio DSP
----------------------------------------------------------------------------
--  ENGS 128
-- Author: Jaden Parker
----------------------------------------------------------------------------
-- Description: Testbench of AXI stream wrapper for FIR selection
--              Tests both DDS and AC stream input selection
----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.all;     
use IEEE.STD_LOGIC_UNSIGNED.ALL;       
library UNISIM;
use UNISIM.VComponents.all;      

entity tb_axis_fir_wrapper is
end tb_axis_fir_wrapper;

architecture testbench of tb_axis_fir_wrapper is

----------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------
constant C_AXI_STREAM_DATA_WIDTH : integer := 32;
constant AC_DATA_WIDTH           : integer := 24;
constant AXI_DATA_WIDTH          : integer := 32;
constant AXI_FIFO_DEPTH          : integer := 12;
constant CLOCK_PERIOD            : time := 8ns;
constant MCLOCK_PERIOD           : time := 81.38ns;
constant AUDIO_DATA_WIDTH        : integer := 24;
-- Sine wave constants for AC stream test
constant SINE_FREQ               : real := 1000.0;
constant SINE_AMPL               : real := real(2**(AUDIO_DATA_WIDTH-1)-1);
constant SAMPLING_FREQ           : real := 48000.00;
constant T_SAMPLE                : real := 1.0/SAMPLING_FREQ;

----------------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------------
signal clk         : std_logic := '0';
signal mclk        : std_logic := '0';
signal bclk        : std_logic := '0';
signal lrclk       : std_logic := '0';
signal data_o      : std_logic := '0';
signal data_i      : std_logic := '0';
signal axi_reset_n : std_logic := '0';
signal test_num    : integer := 0;
signal input_sel   : std_logic := '0';     -- 0 = DDS, 1 = AC stream

-- FIR control
signal channel_select : std_logic_vector(1 downto 0) := "00";
signal dds_enable     : std_logic := '1';

-- AC stream sine wave signals
signal bit_count     : integer := AUDIO_DATA_WIDTH-1;
signal sine_data     : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
signal sine_data_tx  : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');

-- FIFO 0
signal fifo_0_axis_data_out       : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_0_axis_data_in        : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_0_axis_data_out_valid : std_logic := '0';
signal fifo_0_axis_data_in_valid  : std_logic := '0';
signal fifo_0_axis_data_out_last  : std_logic := '0';
signal fifo_0_axis_data_in_last   : std_logic := '0';
signal fifo_0_axis_ready          : std_logic := '0';
signal fifo_0_axis_ready_m        : std_logic;
signal fifo_0_axis_tstrb          : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);

-- FIFO 1
signal fifo_1_axis_data_s           : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_1_axis_tstrb_s          : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
signal fifo_1_axis_data_out_last_s  : std_logic := '0';
signal fifo_1_axis_data_out_valid_s : std_logic := '0';
signal fifo_1_axis_data_out         : std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
signal fifo_1_axis_data_out_valid   : std_logic := '0';
signal fifo_1_axis_data_out_last    : std_logic := '0';
signal fifo_1_axis_ready            : std_logic := '0';
signal fifo_1_axis_tstrb            : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);

signal axis_tstrb         : std_logic_vector((AXI_DATA_WIDTH/8)-1 downto 0);
signal s00_i2s_axis_ready : std_logic := '0';

-- DDS signals
signal left_dds_data  : std_logic_vector(23 downto 0) := (others => '0');
signal right_dds_data : std_logic_vector(23 downto 0) := (others => '0');

-- AXI Lite signals for DDS
signal dds_axi_awaddr  : std_logic_vector(3 downto 0)  := (others => '0');
signal dds_axi_awprot  : std_logic_vector(2 downto 0)  := (others => '0');
signal dds_axi_awvalid : std_logic := '0';
signal dds_axi_awready : std_logic;
signal dds_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
signal dds_axi_wstrb   : std_logic_vector(3 downto 0)  := (others => '1');
signal dds_axi_wvalid  : std_logic := '0';
signal dds_axi_wready  : std_logic;
signal dds_axi_bresp   : std_logic_vector(1 downto 0);
signal dds_axi_bvalid  : std_logic;
signal dds_axi_bready  : std_logic := '0';
signal dds_axi_araddr  : std_logic_vector(3 downto 0)  := (others => '0');
signal dds_axi_arprot  : std_logic_vector(2 downto 0)  := (others => '0');
signal dds_axi_arvalid : std_logic := '0';
signal dds_axi_arready : std_logic;
signal dds_axi_rdata   : std_logic_vector(31 downto 0);
signal dds_axi_rresp   : std_logic_vector(1 downto 0);
signal dds_axi_rvalid  : std_logic;
signal dds_axi_rready  : std_logic := '1';

----------------------------------------------------------------------------
-- Component Declarations
----------------------------------------------------------------------------
component engs128_axi_dds is
generic (
    DDS_DATA_WIDTH          : integer := 24;
    DDS_PHASE_DATA_WIDTH    : integer := 12;
    C_S00_AXI_DATA_WIDTH    : integer := 32;
    C_S00_AXI_ADDR_WIDTH    : integer := 4
);
port (
    dds_clk_i                 : in  std_logic;
  --  dds_reset_i               : in  std_logic;
    left_dds_data_o           : out std_logic_vector(23 downto 0);
    right_dds_data_o          : out std_logic_vector(23 downto 0);
    left_dds_phase_inc_dbg_o  : out std_logic_vector(11 downto 0);
    right_dds_phase_inc_dbg_o : out std_logic_vector(11 downto 0);
    s00_axi_aclk    : in  std_logic;
    s00_axi_aresetn : in  std_logic;
    s00_axi_awaddr  : in  std_logic_vector(3 downto 0);
    s00_axi_awprot  : in  std_logic_vector(2 downto 0);
    s00_axi_awvalid : in  std_logic;
    s00_axi_awready : out std_logic;
    s00_axi_wdata   : in  std_logic_vector(31 downto 0);
    s00_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s00_axi_wvalid  : in  std_logic;
    s00_axi_wready  : out std_logic;
    s00_axi_bresp   : out std_logic_vector(1 downto 0);
    s00_axi_bvalid  : out std_logic;
    s00_axi_bready  : in  std_logic;
    s00_axi_araddr  : in  std_logic_vector(3 downto 0);
    s00_axi_arprot  : in  std_logic_vector(2 downto 0);
    s00_axi_arvalid : in  std_logic;
    s00_axi_arready : out std_logic;
    s00_axi_rdata   : out std_logic_vector(31 downto 0);
    s00_axi_rresp   : out std_logic_vector(1 downto 0);
    s00_axi_rvalid  : out std_logic;
    s00_axi_rready  : in  std_logic
);
end component;

component axis_fifo is
generic (
    DATA_WIDTH : integer := AXI_DATA_WIDTH;
    FIFO_DEPTH : integer := AXI_FIFO_DEPTH
);
port (
    s00_axis_aclk    : in  std_logic;
    s00_axis_aresetn : in  std_logic;
    s00_axis_tready  : out std_logic;
    s00_axis_tdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    s00_axis_tstrb   : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
    s00_axis_tlast   : in  std_logic;
    s00_axis_tvalid  : in  std_logic;
    m00_axis_aclk    : in  std_logic;
    m00_axis_aresetn : in  std_logic;
    m00_axis_tvalid  : out std_logic;
    m00_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    m00_axis_tstrb   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
    m00_axis_tlast   : out std_logic;
    m00_axis_tready  : in  std_logic
);
end component;

component axis_fir_wrapper is
generic (
    C_AXI_STREAM_DATA_WIDTH : integer := 32);
port (
    clk_i            : in  std_logic;
    lrclk_raw        : in  std_logic;
    enable_i         : in  std_logic;
    sel_i            : in  std_logic_vector(1 downto 0);
    s00_axis_aclk    : in  std_logic;
    s00_axis_aresetn : in  std_logic;
    s00_axis_tready  : out std_logic;
    s00_axis_tdata   : in  std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
    s00_axis_tstrb   : in  std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
    s00_axis_tlast   : in  std_logic;
    s00_axis_tvalid  : in  std_logic;
    m00_axis_aclk    : in  std_logic;
    m00_axis_aresetn : in  std_logic;
    m00_axis_tvalid  : out std_logic;
    m00_axis_tdata   : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
    m00_axis_tstrb   : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
    m00_axis_tlast   : out std_logic;
    m00_axis_tready  : in  std_logic
);
end component;

component axis_i2s_wrapper is
generic (
    C_AXI_STREAM_DATA_WIDTH : integer := 32
);
port (
    l_dds_i          : in  std_logic_vector(23 downto 0);
    r_dds_i          : in  std_logic_vector(23 downto 0);
    input_sel_i      : in  std_logic;
    clk_i            : in  std_logic;
    mclk_i           : in  std_logic;
    lrclk_raw_o      : out std_logic;
    lrclk_bufg_o     : out std_logic;
 --   ac_mute_en_i     : in  std_logic;
    ac_bclk_o        : out std_logic;
    ac_mclk_o        : out std_logic;
    ac_mute_n_o      : out std_logic;
    ac_dac_data_o    : out std_logic;
    ac_dac_lrclk_o   : out std_logic;
    ac_adc_data_i    : in  std_logic;
    ac_adc_lrclk_o   : out std_logic;
    s00_axis_aclk    : in  std_logic;
    s00_axis_aresetn : in  std_logic;
    s00_axis_tready  : out std_logic;
    s00_axis_tdata   : in  std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
    s00_axis_tstrb   : in  std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
    s00_axis_tlast   : in  std_logic;
    s00_axis_tvalid  : in  std_logic;
    m00_axis_aclk    : in  std_logic;
    m00_axis_aresetn : in  std_logic;
    m00_axis_tvalid  : out std_logic;
    m00_axis_tdata   : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
    m00_axis_tstrb   : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
    m00_axis_tlast   : out std_logic;
    m00_axis_tready  : in  std_logic;
    dbg_left_audio_rx_o  : out std_logic_vector(23 downto 0);
    dbg_left_audio_tx_o  : out std_logic_vector(23 downto 0);
    dbg_right_audio_rx_o : out std_logic_vector(23 downto 0);
    dbg_right_audio_tx_o : out std_logic_vector(23 downto 0)
);
end component;

----------------------------------------------------------------------------
begin
----------------------------------------------------------------------------
-- Concurrent Assignments
----------------------------------------------------------------------------
fifo_0_axis_data_in_last <= '0';
axis_tstrb <= (others => '1');

----------------------------------------------------------------------------
-- Component Instantiations
----------------------------------------------------------------------------
dds_inst: engs128_axi_dds
port map (
    dds_clk_i                 => clk,
 --   dds_reset_i               => not(axi_reset_n),
    left_dds_data_o           => left_dds_data,
    right_dds_data_o          => right_dds_data,
    left_dds_phase_inc_dbg_o  => open,
    right_dds_phase_inc_dbg_o => open,
    s00_axi_aclk    => clk,
    s00_axi_aresetn => axi_reset_n,
    s00_axi_awaddr  => dds_axi_awaddr,
    s00_axi_awprot  => dds_axi_awprot,
    s00_axi_awvalid => dds_axi_awvalid,
    s00_axi_awready => dds_axi_awready,
    s00_axi_wdata   => dds_axi_wdata,
    s00_axi_wstrb   => dds_axi_wstrb,
    s00_axi_wvalid  => dds_axi_wvalid,
    s00_axi_wready  => dds_axi_wready,
    s00_axi_bresp   => dds_axi_bresp,
    s00_axi_bvalid  => dds_axi_bvalid,
    s00_axi_bready  => dds_axi_bready,
    s00_axi_araddr  => dds_axi_araddr,
    s00_axi_arprot  => dds_axi_arprot,
    s00_axi_arvalid => dds_axi_arvalid,
    s00_axi_arready => dds_axi_arready,
    s00_axi_rdata   => dds_axi_rdata,
    s00_axi_rresp   => dds_axi_rresp,
    s00_axi_rvalid  => dds_axi_rvalid,
    s00_axi_rready  => dds_axi_rready
);

fifo_0_rx_to_fifo: axis_fifo
port map (
    s00_axis_aclk    => clk,
    s00_axis_aresetn => axi_reset_n,
    s00_axis_tready  => fifo_0_axis_ready,
    s00_axis_tdata   => fifo_0_axis_data_in,
    s00_axis_tstrb   => axis_tstrb,
    s00_axis_tlast   => fifo_0_axis_data_in_last,
    s00_axis_tvalid  => fifo_0_axis_data_in_valid,
    m00_axis_aclk    => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid  => fifo_0_axis_data_out_valid,
    m00_axis_tdata   => fifo_0_axis_data_out,
    m00_axis_tstrb   => fifo_0_axis_tstrb,
    m00_axis_tlast   => fifo_0_axis_data_out_last,
    m00_axis_tready  => fifo_0_axis_ready_m
);

axis_fir: axis_fir_wrapper
port map (
    clk_i            => clk,
    lrclk_raw        => lrclk,
    enable_i         => dds_enable,
    sel_i            => channel_select,
    s00_axis_aclk    => clk,
    s00_axis_aresetn => axi_reset_n,
    s00_axis_tready  => fifo_0_axis_ready_m,
    s00_axis_tdata   => fifo_0_axis_data_out,
    s00_axis_tstrb   => fifo_0_axis_tstrb,
    s00_axis_tlast   => fifo_0_axis_data_out_last,
    s00_axis_tvalid  => fifo_0_axis_data_out_valid,
    m00_axis_aclk    => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid  => fifo_1_axis_data_out_valid_s,
    m00_axis_tdata   => fifo_1_axis_data_s,
    m00_axis_tstrb   => fifo_1_axis_tstrb_s,
    m00_axis_tlast   => fifo_1_axis_data_out_last_s,
    m00_axis_tready  => fifo_1_axis_ready
);

fifo_1_fifo_to_tx: axis_fifo
port map (
    s00_axis_aclk    => clk,
    s00_axis_aresetn => axi_reset_n,
    s00_axis_tready  => fifo_1_axis_ready,
    s00_axis_tdata   => fifo_1_axis_data_s,
    s00_axis_tstrb   => fifo_1_axis_tstrb_s,
    s00_axis_tlast   => fifo_1_axis_data_out_last_s,
    s00_axis_tvalid  => fifo_1_axis_data_out_valid_s,
    m00_axis_aclk    => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid  => fifo_1_axis_data_out_valid,
    m00_axis_tdata   => fifo_1_axis_data_out,
    m00_axis_tstrb   => fifo_1_axis_tstrb,
    m00_axis_tlast   => fifo_1_axis_data_out_last,
    m00_axis_tready  => s00_i2s_axis_ready
);

axis_i2s_wrapper_inst: axis_i2s_wrapper
port map (
    l_dds_i          => left_dds_data,
    r_dds_i          => right_dds_data,
    input_sel_i      => input_sel,
    clk_i            => clk,
    mclk_i           => mclk,
    lrclk_raw_o      => lrclk,
    lrclk_bufg_o     => open,
  --  ac_mute_en_i     => '0',
    ac_bclk_o        => bclk,
    ac_mclk_o        => open,
    ac_mute_n_o      => open,
    ac_dac_data_o    => data_o,
    ac_dac_lrclk_o   => open,
    ac_adc_data_i    => data_i,
    ac_adc_lrclk_o   => open,
    s00_axis_aclk    => clk,
    s00_axis_aresetn => axi_reset_n,
    s00_axis_tready  => s00_i2s_axis_ready,
    s00_axis_tdata   => fifo_1_axis_data_out,
    s00_axis_tstrb   => axis_tstrb,
    s00_axis_tlast   => fifo_1_axis_data_out_last,
    s00_axis_tvalid  => fifo_1_axis_data_out_valid,
    m00_axis_aclk    => clk,
    m00_axis_aresetn => axi_reset_n,
    m00_axis_tvalid  => fifo_0_axis_data_in_valid,
    m00_axis_tdata   => fifo_0_axis_data_in,
    m00_axis_tstrb   => fifo_0_axis_tstrb,
    m00_axis_tlast   => fifo_0_axis_data_in_last,
    m00_axis_tready  => fifo_0_axis_ready,
    dbg_left_audio_rx_o  => open,
    dbg_left_audio_tx_o  => open,
    dbg_right_audio_rx_o => open,
    dbg_right_audio_tx_o => open
);

----------------------------------------------------------------------------
-- Clock Generation
----------------------------------------------------------------------------
clk_gen: process
begin
    clk <= '0';
    wait for CLOCK_PERIOD;
    loop
        clk <= not(clk);
        wait for CLOCK_PERIOD/2;
    end loop;
end process clk_gen;

mclk_gen: process
begin
    mclk <= '0';
    wait for MCLOCK_PERIOD;
    loop
        mclk <= not(mclk);
        wait for MCLOCK_PERIOD/2;
    end loop;
end process mclk_gen;

----------------------------------------------------------------------------
-- Main Stimulus: DDS config, input sel switching, FIR sel switching
----------------------------------------------------------------------------
dds_stimulus: process
begin
    ----------------------------------------------------------------------------
    -- TEST 0: Reset
    ----------------------------------------------------------------------------
    test_num    <= 0;
    input_sel   <= '0';         -- start with DDS input
    axi_reset_n <= '0';
    wait for 30ns;
    axi_reset_n <= '1';
    wait for 30ns;

    ----------------------------------------------------------------------------
    -- TEST 1: DDS Input, LPF selected
    -- input_sel = 0 (DDS), channel_select = "00" (LPF)
    ----------------------------------------------------------------------------
    test_num       <= 1;
    input_sel      <= '0';
    channel_select <= "00";

    -- Write left channel phase increment (address 0x0 = 1kHz)
    dds_axi_awaddr  <= x"0";
    dds_axi_awvalid <= '1';
    dds_axi_wdata   <= std_logic_vector(to_unsigned(85, 32));
    dds_axi_wvalid  <= '1';
    dds_axi_bready  <= '1';
    wait until (dds_axi_awready = '1' and dds_axi_wready = '1');
    wait until rising_edge(clk);
    dds_axi_awvalid <= '0';
    dds_axi_wvalid  <= '0';
    wait until dds_axi_bvalid = '1';
    wait until rising_edge(clk);
    dds_axi_bready  <= '0';
    wait for 50ns;

    -- Write right channel phase increment (address 0x4 = 1kHz)
    dds_axi_awaddr  <= x"4";
    dds_axi_awvalid <= '1';
    dds_axi_wdata   <= std_logic_vector(to_unsigned(85, 32));
    dds_axi_wvalid  <= '1';
    dds_axi_bready  <= '1';
    wait until (dds_axi_awready = '1' and dds_axi_wready = '1');
    wait until rising_edge(clk);
    dds_axi_awvalid <= '0';
    dds_axi_wvalid  <= '0';
    wait until dds_axi_bvalid = '1';
    wait until rising_edge(clk);
    dds_axi_bready  <= '0';

    -- Let DDS + LPF run for several samples
    -- 48kHz sample rate, wait ~20 samples = 20 * (1/48000) seconds
    wait for 500000ns;

    ----------------------------------------------------------------------------
    -- TEST 2: AC stream input, HPF selected
    ----------------------------------------------------------------------------
    test_num       <= 2;
    input_sel      <= '1';
    channel_select <= "01";
    wait for 500000ns;

    wait;
end process dds_stimulus;

----------------------------------------------------------------------------
-- AC Stream: Sine wave bit-banged into I2S ADC input
-- Runs continuously, only has effect when input_sel = '1'
----------------------------------------------------------------------------
generate_audio_data: process
    variable t : real := 0.0;
begin
    loop
        -- Generate sine sample
        sine_data <= std_logic_vector(to_signed(
            integer(SINE_AMPL * sin(math_2_pi * SINE_FREQ * t)),
            AUDIO_DATA_WIDTH));

        -- Wait for right channel (lrclk high)
        wait until lrclk = '1';
        -- Convert to offset binary for I2S
        sine_data_tx <= std_logic_vector(unsigned(
            not(sine_data(AUDIO_DATA_WIDTH-1)) &
            sine_data(AUDIO_DATA_WIDTH-2 downto 0)));

        -- Transmit right channel bits MSB first
        bit_count <= AUDIO_DATA_WIDTH-1;
        for i in 0 to AUDIO_DATA_WIDTH-1 loop
            wait until bclk = '0';
            data_i <= sine_data_tx(AUDIO_DATA_WIDTH-1-i);
        end loop;
        wait until bclk = '0';
        data_i <= '0';

        -- Wait for left channel (lrclk low)
        wait until lrclk = '0';

        -- Transmit left channel bits MSB first
        for i in 0 to AUDIO_DATA_WIDTH-1 loop
            wait until bclk = '0';
            data_i <= sine_data_tx(AUDIO_DATA_WIDTH-1-i);
        end loop;
        wait until bclk = '0';
        data_i <= '0';

        -- Increment time by one sample
        t := t + T_SAMPLE;
    end loop;
end process generate_audio_data;

end testbench;