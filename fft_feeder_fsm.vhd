----------------------------------------------------------------------------
--  Final Project: AXI Stream FFT and HDMI output
----------------------------------------------------------------------------
--  ENGS 128 
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: Controls inputs to fft - 64 samples at a time
----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity fft_feeder_fsm is
	generic (
		FIFO_DEPTH	: integer	:= 64;
		FFT_DATA_WIDTH : integer	:= 48
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
end fft_feeder_fsm;


architecture Behavioral of fft_feeder_fsm is

signal tc : std_logic := '0';
signal lrclk_sync1 : std_logic;
signal lrclk_sync2 : std_logic;
signal data_o : std_logic_vector(FFT_DATA_WIDTH-1 downto 0);

type state_type is (ResetState, ConfigState, RunState);	
signal curr_state, next_state : state_type := ResetState;

component counter is
    Generic ( MAX_COUNT : integer := FIFO_DEPTH);   
    Port (  clk_i       : in STD_LOGIC;			
            reset_i     : in STD_LOGIC;		
            enable_i    : in STD_LOGIC;				
            tc_o        : out STD_LOGIC);
end component counter;


begin

counter_inst: counter
    port map(
    clk_i => lrclk_sync2,
    reset_i => tc,
    enable_i => '1',
    tc_o => tc);

----------------------------------------------------------------------------
--FSM Next State Logic Process

next_state_logic : process(curr_state, config_tready_i, aresetn, tc)
begin

	-- Add default conditions here
	next_state <= curr_state; 
    if aresetn = '0' then
        next_state <= ResetState;
    else
        case curr_state is	
    
            when ResetState =>	
                next_state <= ConfigState;
            
            when ConfigState =>	
                if (config_tready_i = '1') and (aresetn = '1') then		
                    next_state <= RunState;
                end if;
            
            when RunState =>
                if tc = '1' then
                    next_state <= ConfigState;
                else next_state <= RunState;
                end if;
            
            when others => -- this is like the "else" part of an if/else statement, but shouldn't reached
                next_state <= ResetState; -- can put a default here in case something weird happens in the hardware
                
        end case;
    end if;
end process next_state_logic;

-- FSM Output Logic Process
fsm_output_logic : process(curr_state) 
begin

	-- Defaults
	config_tvalid_o  <= '0';
	config_tdata_o <= "0000101010101101";
    tlast_o <= '0';
	case curr_state is		

		when ResetState =>		
	       config_tdata_o <= "0000000000000000";  
		
		when ConfigState =>		
			config_tvalid_o  <= '1';	
		    tlast_o <= '1';
		    
		when RunState =>
		
		when others =>
	end case;	
end process fsm_output_logic;

----------------------------------------------------------------------------
-- 5e. FSM State Update Process (synchronous, clocked)
state_update : process (aclk)
begin
	if (rising_edge(aclk)) then
		curr_state <= next_state; 
	end if;
end process state_update;

dbl_ff_sync: process(aclk) --Double FF synchronizer
begin
    if rising_edge(aclk) then
        lrclk_sync1 <= lrclk_bufg;
        lrclk_sync2 <= lrclk_sync1;
    end if;
end process;

end Behavioral;
