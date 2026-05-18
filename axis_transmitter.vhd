----------------------------------------------------------------------------
--  Lab 2: AXI Stream FIFO and DMA
----------------------------------------------------------------------------
--  ENGS 128
--	Author: Jaden Parker
----------------------------------------------------------------------------
--	Description: AXI stream transmitter for I2S data
----------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_transmitter is
	generic (
		C_AXI_STREAM_DATA_WIDTH	: integer	:= 32;
		AC_DATA_WIDTH : integer := 24);    
    Port (
    --I2S Ports
        lrclk_raw : in std_logic;
        l_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
        r_data_i : in std_logic_vector(AC_DATA_WIDTH-1 downto 0);
    --    sysclk_i : in std_logic;
        aresetn : in std_logic;
        -- AXI Stream Ports
		m00_axis_aclk     : in std_logic;
        m00_axis_tvalid   : out std_logic; 
		m00_axis_tdata    : out std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
		m00_axis_tstrb    : out std_logic_vector((C_AXI_STREAM_DATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast    : out std_logic;
		m00_axis_tready   : in std_logic);
end axis_transmitter;

architecture Behavioral of axis_transmitter is
----------------------------------------------------------------------------
-- 3. Define internal constants, signals, and components used inside this entity
-- 3a. Define constants
signal send : std_logic;
signal lrclk_last : std_logic;
signal lrclk_sync1 : std_logic;
signal lrclk_sync2 : std_logic;
signal ldata : std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);
signal rdata : std_logic_vector(C_AXI_STREAM_DATA_WIDTH-1 downto 0);

-- Define custom types for your FSM
type state_type is (ResetState, WaitState, LTransmitState, RTransmitState);	
signal curr_state, next_state : state_type := ResetState;
----------------------------------------------------------------------------


begin
----------------------------------------------------------------------------
m00_axis_tstrb <= (others => '1');   -- all 1s meaning all bytes valid
m00_axis_tlast <= '0';


-- 5. Define processes
-- 5a. Define clocked processe
dbl_ff_sync : process(m00_axis_aclk ) 
begin
    if (rising_edge(m00_axis_aclk)) then
        lrclk_sync1 <= lrclk_raw; 
        lrclk_sync2 <= lrclk_sync1; 
    end if;
end process dbl_ff_sync;

send_update : process (m00_axis_aclk) --send signal is high on rising edge of lrclk (will send right side data first)
begin			
	if (rising_edge(m00_axis_aclk)) then
	   if (lrclk_sync2 = '1' and lrclk_last = '0') then
	       send <= '1';
       else
           send <= '0';
       end if;
	   lrclk_last <= lrclk_sync2;
	end if;
end process send_update; 

data_update : process(m00_axis_aclk)
begin 
    if (rising_edge(m00_axis_aclk)) then
        ldata <= l_data_i & "00000000"; --Encode 25th bit to be 0 for left
        rdata <= r_data_i & "10000000"; --Encode 25th bit to be 1 for right
    end if;
end process data_update;
    
----------------------------------------------------------------------------
-- 5c. FSM Next State Logic Process
next_state_logic : process(curr_state, aresetn, m00_axis_tready, send) 
begin

	-- Defaults
	next_state <= curr_state;
    if (aresetn = '0') then --Reset if aresetn = 0, no matter what state I'm in
        next_state <= ResetState;
    else 
        case curr_state is	
    
            when ResetState =>
                if (aresetn = '1') then
                    next_state <= WaitState;
               else  
               end if;  
            
            when WaitState =>		
                if (send = '1') then		
                    next_state <= LTransmitState;
               else  
               end if;  
            
            when LTransmitState  =>     --Every rising LRCLK, the transmitter will send left data once ready signal is received, then immediately send right data (once ready is high again). This ensures new data for both sides every time.
                if (m00_axis_tready = '1') then		
                    next_state <= RTransmitState;
               else  
               end if;  
                
            when RTransmitState  => 
                if (m00_axis_tready = '1') then		
                    next_state <= WaitState;
               else  
               end if;  
                        
            when others => 
                next_state <= ResetState; 
                
         end case;
     end if;				
end process next_state_logic;

----------------------------------------------------------------------------
-- 5d. FSM Output Logic Process (asynchronous, no clock)

fsm_output_logic : process(curr_state,ldata,rdata) 
begin

	-- Defaults
    m00_axis_tvalid <= '1';

	case curr_state is		

		when ResetState =>		
			m00_axis_tvalid <= '0';
		
		when WaitState =>		
			m00_axis_tvalid <= '0';
		
		when LTransmitState =>
			m00_axis_tdata <= ldata;
		
		when RTransmitState =>
			m00_axis_tdata <= rdata	;
		when others => 
	end case;					
end process fsm_output_logic;

----------------------------------------------------------------------------
-- 5e. FSM State Update Process (synchronous, clocked)
state_update : process (m00_axis_aclk)
begin
	if (rising_edge(m00_axis_aclk)) then
		curr_state <= next_state; 
	end if;
end process state_update;

----------------------------------------------------------------------------

end Behavioral;

