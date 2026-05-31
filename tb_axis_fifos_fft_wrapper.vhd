--------------------------------------------------------------------------------
-- Simple Testbench for axis_fifos_fft_wrapper
-- ENGS 128 - Jaden Parker
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tb_axis_fifos_fft_wrapper is
end tb_axis_fifos_fft_wrapper;

architecture tb of tb_axis_fifos_fft_wrapper is

    -----------------------------------------------------------------------
    -- Timing Constants
    -----------------------------------------------------------------------
    constant CLOCK_PERIOD    : time    := 8 ns;       -- 125 MHz aclk
    constant BCLK_PERIOD    : time    := 163.75 ns;
    constant LRCLK_PERIOD    : time    := 20833 ns;     -- ~48 kHz
    constant T_HOLD          : time    := 1 ns;

    -----------------------------------------------------------------------
    -- Audio Constants
    -----------------------------------------------------------------------
    constant AUDIO_DATA_WIDTH : integer := 24;
    constant SINE_FREQ_L        : real    := 750.0;     -- .75 kHz tone
    constant SINE_FREQ_R        : real    := 6000.0;     -- 6 kHz tone
    constant SAMPLE_RATE      : real    := 48000.0;    -- 48 kHz
    constant T_SAMPLE         : real    := 1.0 / SAMPLE_RATE;
    constant SINE_AMPL        : real    := real(2**(AUDIO_DATA_WIDTH-2));

    -----------------------------------------------------------------------
    signal aclk          : std_logic := '0';
    signal aresetn       : std_logic := '0';
    signal lrclk_raw     : std_logic := '0';
    signal bclk          : std_logic := '0';

    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_tstrb  : std_logic_vector(3 downto 0)  := (others => '1');
    signal s_axis_tlast  : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(31 downto 0);
    signal m_axis_tstrb  : std_logic_vector(3 downto 0);
    signal m_axis_tlast  : std_logic;
    signal m_axis_tready : std_logic := '1';

    -----------------------------------------------------------------------
    -- Audio generation signals
    -----------------------------------------------------------------------
    signal sine_data_L     : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
    signal sine_data_tx_L  : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
    signal sine_data_R     : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
    signal sine_data_tx_R  : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0) := (others => '0');
    signal data_i        : std_logic := '0';
    signal bit_count     : integer   := 0;

begin

    -----------------------------------------------------------------------
    -- DUT
    -----------------------------------------------------------------------
    dut : entity work.axis_fifos_fft_wrapper
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            lrclk_raw     => lrclk_raw,        
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tstrb  => s_axis_tstrb,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tready => s_axis_tready,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tstrb  => m_axis_tstrb,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tready => m_axis_tready
        );

    -----------------------------------------------------------------------
    -- System Clock (125 MHz)
    -----------------------------------------------------------------------
    aclk <= not aclk after CLOCK_PERIOD / 2;
    bclk <= not bclk after BCLK_PERIOD / 2;
    -----------------------------------------------------------------------
    -- LRCLK
    -----------------------------------------------------------------------
    lrclk_gen : process
    begin
        wait until aresetn = '1';
        loop
            lrclk_raw  <= '0';
            wait for LRCLK_PERIOD / 2;
            lrclk_raw  <= '1';
            wait for LRCLK_PERIOD / 2;
        end loop;
    end process lrclk_gen;

    -----------------------------------------------------------------------
    -- Reset
    -----------------------------------------------------------------------
    reset_gen : process
    begin
        aresetn <= '0';
        wait for CLOCK_PERIOD * 20;
        aresetn <= '1';
        wait;
    end process reset_gen;


    -----------------------------------------------------------------------
    generate_audio_data : process
        variable t              : real    := 0.0;
        variable sample_count_r : integer := 0;
        variable sample_count_l : integer := 0;
        variable sine_data_v_L    : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
        variable sine_data_tx_v_L : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);

        variable sine_data_v_R   : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
        variable sine_data_tx_v_R : std_logic_vector(AUDIO_DATA_WIDTH-1 downto 0);
    
        procedure send_axi_sample (
            data : std_logic_vector(31 downto 0);
            last : std_logic
        ) is
        begin
            s_axis_tdata  <= data;
            s_axis_tlast  <= last;
            s_axis_tvalid <= '1';
            loop
                wait until rising_edge(aclk);
                exit when s_axis_tready = '1';
            end loop;
            wait for T_HOLD;
            s_axis_tvalid <= '0';
            s_axis_tdata  <= (others => '0');
            s_axis_tlast  <= '0';
        end procedure;
    
    begin
        wait until aresetn = '1';
    
        loop
            -- Compute sine sample
            sine_data_v_L   := std_logic_vector(to_signed(
                integer(SINE_AMPL * sin(MATH_2_PI * SINE_FREQ_L * t)),
                AUDIO_DATA_WIDTH));
            sine_data_tx_v_L := (not sine_data_v_L(AUDIO_DATA_WIDTH-1))
                              & sine_data_v_L(AUDIO_DATA_WIDTH-2 downto 0);
            
            sine_data_v_R   := std_logic_vector(to_signed(
                integer(SINE_AMPL * sin(MATH_2_PI * SINE_FREQ_R * t)),
                AUDIO_DATA_WIDTH));
            sine_data_tx_v_R := (not sine_data_v_R(AUDIO_DATA_WIDTH-1))
                              & sine_data_v_R(AUDIO_DATA_WIDTH-2 downto 0);    
            -- For waveform viewing
            sine_data_L    <= sine_data_v_L;
            sine_data_tx_L <= sine_data_tx_v_L;
            sine_data_R    <= sine_data_v_R;
            sine_data_tx_R <= sine_data_tx_v_R;   

            -- Left channel: lrclk low
            wait until lrclk_raw = '0';
            for i in 0 to AUDIO_DATA_WIDTH-1 loop
                wait until falling_edge(bclk);
                data_i <= sine_data_tx_v_L(AUDIO_DATA_WIDTH-1-i);
            end loop;
            wait until falling_edge(bclk);
            data_i <= '0';
    
            sample_count_l := sample_count_l + 1;
            if sample_count_l = 64 then
                send_axi_sample(sine_data_tx_v_L & x"00", '1');
                sample_count_l := 0;
            else
                send_axi_sample(sine_data_tx_v_L & x"00", '0');
            end if;

            -- Right channel: lrclk high
            wait until lrclk_raw = '1';
            for i in 0 to AUDIO_DATA_WIDTH-1 loop
                wait until falling_edge(bclk);
                data_i <= sine_data_tx_v_R(AUDIO_DATA_WIDTH-1-i);
            end loop;
            wait until falling_edge(bclk);
            data_i <= '0';
    
            sample_count_r := sample_count_r + 1;
            if sample_count_r = 64 then
                send_axi_sample(sine_data_tx_v_R & x"00", '1');
                sample_count_r := 0;
            else
                send_axi_sample(sine_data_tx_v_R & x"00", '0');
            end if;
    

    
            t := t + T_SAMPLE;
            exit when t > (64.0 * T_SAMPLE * 10.0);
        end loop;
    

        wait until m_axis_tvalid = '1' for CLOCK_PERIOD * 200000;
    

    
        wait for CLOCK_PERIOD * 100;
        report "Simulation complete." severity failure;
        wait;
    end process generate_audio_data;
end tb;