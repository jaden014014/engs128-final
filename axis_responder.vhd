----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: AXI stream responder for I2S data
----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_responder is
	generic (
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24);    
    Port (
        --I2S Ports
        lrclk_raw : in std_logic;
        l_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        r_data_o : out std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        aresetn : in std_logic;
        
        --LAB 3 l and r valid ports --
        l_valid_o : out std_logic;
        r_valid_o : out std_logic;

		--AXIS Ports
		s00_axis_aclk     : in std_logic;
		s00_axis_tready   : out std_logic;
		s00_axis_tdata	  : in std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		s00_axis_tstrb    : in std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast    : in std_logic;
		s00_axis_tvalid   : in std_logic);
end axis_responder;

architecture Behavioral of axis_responder is

-- Define custom types for your FSM
type state_type is (ResetState, WaitState1, WaitState2, LLatchState, RLatchState, SetReady1, SetReady2);	
signal curr_state, next_state : state_type := ResetState;
signal tready: std_logic; --Internal signal for ready
signal l_valid : std_logic;
signal r_valid : std_logic;
signal lrclk_sync1 : std_logic;
signal lrclk_sync2 : std_logic;

begin
s00_axis_tready <= tready;
l_valid_o <= l_valid; 
r_valid_o <= r_valid;

--
data_update : process (s00_axis_aclk)
begin
	if (rising_edge(s00_axis_aclk)) then
        if s00_axis_tvalid = '1' and tready = '1' then
            if s00_axis_tdata(7) = '0' then
                l_data_o <= s00_axis_tdata(C_AXI_STREAM_DATA_WIDTH-1 downto 8);
            else
                r_data_o <= s00_axis_tdata(C_AXI_STREAM_DATA_WIDTH-1 downto 8);
            end if;
        end if;
	end if;
end process data_update;

dbl_ff_sync : process(s00_axis_aclk ) 
begin
    if (rising_edge(s00_axis_aclk)) then
        lrclk_sync1 <= lrclk_raw; 
        lrclk_sync2 <= lrclk_sync1; 
    end if;
end process dbl_ff_sync;

-- 5c. FSM Next State Logic Process
next_state_logic : process(curr_state, lrclk_sync2, aresetn, s00_axis_tvalid) 
begin

	-- Default
	next_state <= curr_state; 	
    if (aresetn = '0') then -- Will go back to reset from any state
        next_state <= ResetState;
    else
        case curr_state is	
    
            when ResetState =>
                if (aresetn = '1') then
                    next_state <= WaitState1;
               else  
               end if;  
            
            when WaitState1 => --Wait for lrclk low
                if lrclk_sync2 = '0' then
                    next_state <= LLatchState;
                else
                end if;            
            
            when LLatchState => --Will latch left incoming data, then set ready in next state 
                next_state <= SetReady1;
            
            when SetReady1 => --Set ready signal if we have a valid signal
                if s00_axis_tvalid = '1' then 
                    next_state <= WaitState2;
                else 
                end if;		
            
            when WaitState2 => -- wait for LRCLK high
                if lrclk_sync2 = '1' then
                    next_state <= RLatchState;
                else
                end if;            
            
            when RLatchState => --Will latch right incoming data, then set ready in next state 
                next_state <= SetReady2;
            
            when SetReady2 =>  --Set ready signal if we have a valid signal
                if s00_axis_tvalid = '1' then 
                    next_state <= WaitState1;
                else 
                end if;
            
            when others => 
                next_state <= ResetState; 
	   end case;
    end if;
end process next_state_logic;

----------------------------------------------------------------------------
-- 5d. FSM Output Logic Process (asynchronous, no clock)

fsm_output_logic : process(curr_state) 
begin

	-- Defaults
    tready <= '0';
    l_valid <= '1';
    r_valid <= '1';
    
	case curr_state is		

		when ResetState =>		

		when WaitState1 =>		
	
		when LLatchState =>
            l_valid <= '0';
		when SetReady1 =>
            tready <= '1';	
		when WaitState2 =>		
	
		when RLatchState =>
            r_valid <= '0';
		when SetReady2 =>
            tready <= '1';		
		when others => 
	end case;					
end process fsm_output_logic;

----------------------------------------------------------------------------
-- 5e. FSM State Update Process (synchronous, clocked)
state_update : process (s00_axis_aclk)
begin
	if (rising_edge(s00_axis_aclk)) then
		curr_state <= next_state; 		
	end if;
end process state_update;

----------------------------------------------------------------------------

end Behavioral;