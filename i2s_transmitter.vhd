----------------------------------------------------------------------------
--  Lab 1: DDS and the Audio Codec
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: I2S transmitter for SSM2603 audio codec
----------------------------------------------------------------------------
-- Add libraries 
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
----------------------------------------------------------------------------
-- Entity definition
entity i2s_transmitter is
    Generic (AC_DATA_WIDTH : integer := 24);
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
end i2s_transmitter;
----------------------------------------------------------------------------
architecture Behavioral of i2s_transmitter is
-- 3. Define internal constants, signals, and components used inside this entity

signal l_load_en, l_shift_en, r_load_en, r_shift_en : std_logic := '0';
signal l_data_o, r_data_o : std_logic := '0';
signal counter_tc, counter_reset : std_logic := '0';
----------------------------------------------------------------------------
-- Define custom types for your FSM
type state_type is (ResetState, Idle1State, LeftShiftState, Idle2State,  RightShiftState);	
signal curr_state, next_state : state_type := ResetState;

----------------------------------------------------------------------------
-- 3c. List all component declarations
component shift_register is
    Generic ( DATA_WIDTH : integer := AC_DATA_WIDTH);
    Port ( 
      clk_i         : in std_logic;
      data_i        : in std_logic_vector(DATA_WIDTH-1 downto 0);
      load_en_i     : in std_logic;
      shift_en_i    : in std_logic;
      
      data_o        : out std_logic);
end component;

-- Counter
component counter is
    Generic ( MAX_COUNT : integer := AC_DATA_WIDTH); 
    Port (  clk_i       : in STD_LOGIC;			
            reset_i     : in STD_LOGIC;		
            enable_i    : in STD_LOGIC;				
            tc_o        : out STD_LOGIC);
end component;

----------------------------------------------------------------------------
-- Define the entity's behavior after the "begin" keyword
begin
----------------------------------------------------------------------------
-- 4. Instantiate any components used in this entity
shift_reg_inst_left : shift_register 
    port map (
        clk_i => bclk_i,
        data_i => left_audio_data_i,          
        load_en_i => l_load_en,
        shift_en_i => l_shift_en,
        data_o => l_data_o);

shift_reg_inst_right : shift_register 
    port map (
        clk_i => bclk_i,
        data_i => right_audio_data_i,          
        load_en_i => r_load_en,
        shift_en_i => r_shift_en,
        data_o => r_data_o);
        
bit_counter : counter 
    port map (
        clk_i => bclk_i,
        reset_i => counter_reset,
        enable_i => '1',            -- always enabled
        tc_o => counter_tc);        


----------------------------------------------------------------------------
-- 5. Define processes to use the signals and entity inputs to set entity outputs

-- 5c. FSM Next State Logic Process
next_state_logic : process(curr_state, lrclk_raw_i, enable_i, counter_tc)
begin

	-- Default conditions
	next_state <= curr_state; 

	case curr_state is	
	    
	    when ResetState =>
			if (enable_i = '1' and lrclk_raw_i = '1') then     -- wait until enabled and lrclk is high	   
		        next_state <= Idle1State;
			end if;
		when Idle1State =>
			if (lrclk_raw_i = '0') then     -- wait until lrclk goes low   
		        next_state <= LeftShiftState;
			end if;
				
	--	when LeftLoadState =>
	--		next_state <= LeftShiftState;     -- stay here for one clock cycle
					
		when LeftShiftState =>
			if (counter_tc = '1') then		
				next_state <= Idle2State;
			end if;
			
		when Idle2State =>
			if (lrclk_raw_i = '1') then     -- wait until lrclk goes high  	   
		        next_state <= RightShiftState;
			end if;
		
		
	--	when RightLoadState =>
	--		next_state <= RightShiftState;     -- stay here for one clock cycle
					
		when RightShiftState =>
			if (counter_tc = '1') then		
				next_state <= Idle1State;
			end if;

		
		when others =>
			next_state <= ResetState;
			
	end case;					-- end of case statement
end process next_state_logic;

-- 5d. FSM Output Logic Process (asynchronous, no clock)

fsm_output_logic : process(curr_state, l_data_o, r_data_o) 
begin

	-- Add default conditions here
	l_load_en <= '0';	
	l_shift_en <= '0';			
	r_load_en <= '0';			
    r_shift_en <= '0';
    counter_reset <= '0';
    shift_done_o <= '0';
    dac_serial_data_o <= '0';
    
	-- Use a case statement to define outputs for each state
	case curr_state is		

		when ResetState =>		
		
		when Idle1State =>		
			shift_done_o  <= '1';
			counter_reset <= '1';		
			l_load_en  <= '1';		
		--when LeftLoadState =>
	--		l_load_en  <= '1';	
			
		when LeftShiftState =>
			l_shift_en  <= '1';
			dac_serial_data_o <= l_data_o;
		
		when Idle2State =>		
			shift_done_o  <= '1';
			counter_reset <= '1';		
			r_load_en  <= '1';
					
	--	when RightLoadState =>
	--		r_load_en  <= '1';
			
		when RightShiftState =>
			r_shift_en  <= '1';
		    dac_serial_data_o <= r_data_o;
		when others =>
			
	end case;					-- end of case statement
end process fsm_output_logic;
----------------------------------------------------------------------------
-- FSM State Update Process (synchronous, clocked)
state_update : process (bclk_i)
begin
	if (falling_edge(bclk_i)) then
		curr_state <= next_state; 		-- update current state on rising edge of the clock
	end if;
end process state_update;

----------------------------------------------------------------------------
end Behavioral;