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

        fft_tvalid_i    : in  std_logic;
        fft_tready_i    : in  std_logic;        
        aclk     : in std_logic;
		aresetn  : in std_logic;

		tlast_o    : out std_logic
    );
end fft_feeder_fsm;


architecture Behavioral of fft_feeder_fsm is

signal data_o : std_logic_vector(FFT_DATA_WIDTH-1 downto 0);

type state_type is (ResetState, ConfigState, RunState, AssertTlastState);	
signal curr_state, next_state : state_type := ResetState;

signal sample_count : integer range 0 to FIFO_DEPTH := 0;


begin


----------------------------------------------------------------------------
--FSM Next State Logic Process

next_state_logic : process(curr_state, config_tready_i, aresetn, fft_tvalid_i, fft_tready_i, sample_count)
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
                if fft_tvalid_i = '1' and fft_tready_i = '1' then
                    if sample_count = FIFO_DEPTH - 2 then
                        next_state        <= AssertTlastState;
                    end if;
                end if;
                
             when AssertTlastState =>	
                if fft_tvalid_i = '1' and fft_tready_i = '1' then
--                    if sample_count = FIFO_DEPTH - 1 then
                        next_state        <= RunState;
--                    end if;
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

		    
		when RunState =>
		  
		when AssertTlastState => 
		    tlast_o <= '1';

		when others =>
	end case;	
end process fsm_output_logic;

----------------------------------------------------------------------------
-- 5e. FSM State Update Process (synchronous, clocked)
state_update : process(aclk)
begin
    if rising_edge(aclk) then
        curr_state <= next_state;
        -- Reset count on state transitions
        if curr_state = RunState or curr_state = AssertTlastState then
            if fft_tvalid_i = '1' and fft_tready_i = '1' then
                if sample_count = FIFO_DEPTH - 1 then
                    sample_count <= 0;
                else
                    sample_count <= sample_count + 1;
                end if;
            end if;
        else
            sample_count <= 0;
        end if;
    end if;
end process state_update;

end Behavioral;
