-- =============================================================================
-- DEBOUNCE MODULE MODIFIED FOR ACTIVE-HIGH RESET
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity debounce_mod is
generic (
    FREQ_CLOCK_MHZ : integer := 50;  -- Clock frequency in MHz
    TIME_DEBOUNCE_MS : integer := 20; -- Debounce time in milliseconds
    RESET_LOW_ACTIVE : boolean := false;  -- Reset polarity: false = active high
    INPUT_LOW_ACTIVE : boolean := false  -- Button input polarity
);
port (
    clk_i : in std_logic;       -- System clock input
    rst_i : in std_logic;       -- External reset input
    btn_in_i : in std_logic;    -- Raw button input
    btn_out_o : out std_logic;  -- Debounced button output
    pulse_rising_o : out std_logic; -- Rising edge pulse output
    pulse_falling_o : out std_logic -- Falling edge pulse output
);
end entity debounce_mod;

architecture rtl_mod of debounce_mod is

    -- Function to check if reset is active based on polarity
    function is_reset_active_f(signal rst_sig : std_logic) return boolean is 
    begin
        if RESET_LOW_ACTIVE then
            return rst_sig = '0';
        else
            return rst_sig = '1';  -- Active high reset
        end if;
    end function;

    -- Function to normalize input polarity
    function normalize_input_f(signal inp_sig : std_logic) return std_logic is
    begin
        if INPUT_LOW_ACTIVE then
            return not inp_sig;  -- Invert if input is active low
        else
            return inp_sig;
        end if;
    end function;

    -- Debounce counter maximum value
    constant MAX_COUNTER : integer := (FREQ_CLOCK_MHZ * 1000) * TIME_DEBOUNCE_MS - 1;
    subtype cnt_type is integer range 0 to MAX_COUNTER;

    -- Internal signals
    signal cnt : cnt_type := 0;                       -- Counter for debounce timing
    signal ff_sync : std_logic_vector(2 downto 0) := (others => '0'); -- 3-stage synchronizer
    signal btn_clean : std_logic := '0';             -- Debounced button value
    signal btn_previous : std_logic := '0';          -- Previous button state
    signal rst_n_sig : std_logic;                    -- Internal reset signal
    signal btn_norm_sig : std_logic;                 -- Normalized button input

begin
    -- Apply reset and normalize button input
    rst_n_sig <= '0' when is_reset_active_f(rst_i) else '1';
    btn_norm_sig <= normalize_input_f(btn_in_i);

    -- Synchronization process: synchronize asynchronous input to clock
    sync_proc: process(clk_i, rst_n_sig)
    begin
        if rst_n_sig = '0' then
            ff_sync <= (others => '0');  -- Reset synchronizer
        elsif rising_edge(clk_i) then
            ff_sync <= ff_sync(1 downto 0) & btn_norm_sig; -- Shift in new input
        end if;
    end process sync_proc;

    -- Debounce process: increment counter and update button state
    debounce_proc: process(clk_i, rst_n_sig)
    begin
        if rst_n_sig = '0' then
            cnt <= 0;
            btn_clean <= '0';
            btn_previous <= '0';
        elsif rising_edge(clk_i) then
            btn_previous <= btn_clean; -- Store previous state

            if ff_sync(2) /= ff_sync(1) then
                cnt <= 0;  -- Reset counter if input changed
            else
                if cnt < MAX_COUNTER then
                    cnt <= cnt + 1; -- Increment counter
                else
                    btn_clean <= ff_sync(2); -- Update debounced output
                end if;
            end if;
        end if;
    end process debounce_proc;

    -- Output assignments
    btn_out_o <= btn_clean;                            -- Debounced button
    pulse_rising_o <= btn_clean and not btn_previous; -- Rising edge pulse
    pulse_falling_o <= not btn_clean and btn_previous;-- Falling edge pulse
end architecture rtl_mod;

-- =============================================================================
-- ULA2 MODULE (ALU) - ARITHMETIC/LOGIC OPERATIONS
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity ula2_mod is
port (
    IN1, IN2 : in signed(3 downto 0);                 -- 4-bit signed inputs
    OUT_ANS : out std_logic_vector(3 downto 0);       -- 4-bit result output
    SEL_OP : in std_logic_vector(2 downto 0);         -- Operation selector
    FLAG_ZERO, FLAG_NEG, FLAG_CARRY, FLAG_OVER : out std_logic -- ALU flags
);
end ula2_mod;

architecture hw_mod of ula2_mod is
    signal op_temp : std_logic_vector(3 downto 0); -- Temporary result storage
begin
    -- Process to calculate ALU output based on inputs and operation
    process(IN1, IN2, SEL_OP)
        variable var_temp : signed(4 downto 0);   -- Temp variable for arithmetic
        variable var_mult : signed(7 downto 0);   -- Temp variable for multiplication
    begin
        FLAG_CARRY <= '0'; -- Reset flags
        FLAG_OVER <= '0';

        case SEL_OP is
            when "000" => -- Addition
                var_temp := resize(IN1, 5) + resize(IN2, 5);
                op_temp <= std_logic_vector(var_temp(3 downto 0));
                FLAG_CARRY <= var_temp(4);
                FLAG_OVER <= (IN1(3) and IN2(3) and not var_temp(3)) or
                             (not IN1(3) and not IN2(3) and var_temp(3));

            when "001" => -- Subtraction
                var_temp := resize(IN1, 5) - resize(IN2, 5);
                op_temp <= std_logic_vector(var_temp(3 downto 0));
                FLAG_CARRY <= not var_temp(4);
                FLAG_OVER <= (not IN1(3) and IN2(3) and var_temp(3)) or
                             (IN1(3) and not IN2(3) and not var_temp(3));

            when "010" => -- Multiply by 2 (shift left)
                var_temp := resize(IN1, 5) sll 1;
                op_temp <= std_logic_vector(var_temp(3 downto 0));
                FLAG_CARRY <= IN1(3);
                FLAG_OVER <= IN1(3) xor var_temp(3);

            when "011" => -- Divide by 2 (shift right)
                var_temp := resize(IN2, 5) srl 1;
                op_temp <= std_logic_vector(var_temp(3 downto 0));
                FLAG_CARRY <= IN2(0);
                FLAG_OVER <= '0';

            when "100" => -- XOR
                op_temp <= std_logic_vector(IN1) xor std_logic_vector(IN2);

            when "101" => -- NOT
                op_temp <= not std_logic_vector(IN1);

            when "110" => -- Multiplication
                var_mult := IN1 * IN2;
                op_temp <= std_logic_vector(var_mult(3 downto 0));
                if var_mult > 7 or var_mult < -8 then
                    FLAG_OVER <= '1';
                    FLAG_CARRY <= '1';
                else
                    FLAG_OVER <= '0';
                    FLAG_CARRY <= '0';
                end if;

            when "111" => -- Shift left logical
                var_temp := resize(IN1, 5);
                var_temp := var_temp sll 1;
                op_temp <= std_logic_vector(var_temp(3 downto 0));
                FLAG_CARRY <= IN1(3);
                FLAG_OVER <= IN1(3) xor var_temp(3);

            when others =>
                op_temp <= "0000";
                FLAG_CARRY <= '0';
                FLAG_OVER <= '0';
        end case;
    end process;

    OUT_ANS <= op_temp;                           -- ALU output
    FLAG_ZERO <= '1' when op_temp = "0000" else '0'; -- Zero flag
    FLAG_NEG <= op_temp(3);                        -- Negative flag
end hw_mod;

-- =============================================================================
-- TOP_LEVEL MODULE WITH BUTTONS, SWITCHES, LEDs, AND FSM
-- =============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top_level_mod is
port(
    CLK50 : in std_logic;                    -- 50MHz system clock
    RST_BTN : in std_logic;                  -- Active-high reset button
    BTN_OK : in std_logic;                   -- OK button for FSM
    BTN_BACK : in std_logic;                 -- BACK button for FSM
    SWITCHES : in std_logic_vector(3 downto 0); -- 4-bit switch input
    LED_GREEN : out std_logic_vector(3 downto 0);-- ALU result display
    LED_RED : out std_logic_vector(7 downto 0)   -- Status LEDs
);
end top_level_mod;

architecture rtl_top_mod of top_level_mod is

    -- Component declarations
    component debounce_mod is
        generic (
            FREQ_CLOCK_MHZ : integer := 50;
            TIME_DEBOUNCE_MS : integer := 20;
            RESET_LOW_ACTIVE : boolean := false;
            INPUT_LOW_ACTIVE : boolean := false
        );
        port (
            clk_i : in std_logic;
            rst_i : in std_logic;
            btn_in_i : in std_logic;
            btn_out_o : out std_logic;
            pulse_rising_o : out std_logic;
            pulse_falling_o : out std_logic
        );
    end component;

    component ula2_mod is
        port (
            IN1, IN2 : in signed(3 downto 0);
            OUT_ANS : out std_logic_vector(3 downto 0);
            SEL_OP : in std_logic_vector(2 downto 0);
            FLAG_ZERO, FLAG_NEG, FLAG_CARRY, FLAG_OVER : out std_logic
        );
    end component;

    -- Internal signals
    signal rst_internal_sig : std_logic;           -- Internal reset signal
    signal pulse_btn0_sig, pulse_btn1_sig : std_logic; -- Debounced button pulses

    -- FSM states
    type state_input_type is (ST_SEL_OP, ST_INPUT_A, ST_INPUT_B, ST_SHOW_RES);
    signal state_input_sig : state_input_type;

    -- Registers for operation and operands
    signal reg_op : std_logic_vector(2 downto 0) := "000";
    signal reg_a : std_logic_vector(3 downto 0) := "0000";
    signal reg_b : std_logic_vector(3 downto 0) := "0000";
    signal reg_result : std_logic_vector(3 downto 0);

    -- ALU flags
    signal flag_z, flag_n, flag_c, flag_v : std_logic;

begin

    rst_internal_sig <= RST_BTN; -- Connect reset button to internal reset

    -- Debounce instances for OK and BACK buttons
    debounce_ok: debounce_mod
        generic map (
            FREQ_CLOCK_MHZ => 50,
            TIME_DEBOUNCE_MS => 20,
            RESET_LOW_ACTIVE => false,
            INPUT_LOW_ACTIVE => true
        )
        port map (
            clk_i => CLK50,
            rst_i => rst_internal_sig,
            btn_in_i => BTN_OK,
            btn_out_o => open,
            pulse_rising_o => pulse_btn0_sig,
            pulse_falling_o => open
        );

    debounce_back: debounce_mod
        generic map (
            FREQ_CLOCK_MHZ => 50,
            TIME_DEBOUNCE_MS => 20,
            RESET_LOW_ACTIVE => false,
            INPUT_LOW_ACTIVE => true
        )
        port map (
            clk_i => CLK50,
            rst_i => rst_internal_sig,
            btn_in_i => BTN_BACK,
            btn_out_o => open,
            pulse_rising_o => pulse_btn1_sig,
            pulse_falling_o => open
        );

    -- FSM process: handles button presses and updates state
    fsm_input_proc: process(CLK50)
    begin
        if rising_edge(CLK50) then
            if rst_internal_sig = '1' then
                -- Reset all FSM states and registers
                state_input_sig <= ST_SEL_OP;
                reg_op <= "000";
                reg_a <= "0000";
                reg_b <= "0000";
            else
                -- FSM state transitions
                case state_input_sig is
                    when ST_SEL_OP =>
                        if pulse_btn0_sig = '1' then
                            reg_op <= SWITCHES(2 downto 0); -- Select operation
                            state_input_sig <= ST_INPUT_A;
                        end if;

                    when ST_INPUT_A =>
                        if pulse_btn0_sig = '1' then
                            reg_a <= SWITCHES; -- Capture operand A
                            state_input_sig <= ST_INPUT_B;
                        elsif pulse_btn1_sig = '1' then
                            state_input_sig <= ST_SEL_OP; -- Go back
                        end if;

                    when ST_INPUT_B =>
                        if pulse_btn0_sig = '1' then
                            reg_b <= SWITCHES; -- Capture operand B
                            state_input_sig <= ST_SHOW_RES;
                        elsif pulse_btn1_sig = '1' then
                            state_input_sig <= ST_INPUT_A; -- Go back
                        end if;

                    when ST_SHOW_RES =>
                        if pulse_btn1_sig = '1' then
                            state_input_sig <= ST_SEL_OP; -- Go back to select op
                        end if;

                    when others =>
                        state_input_sig <= ST_SEL_OP;
                end case;
            end if;
        end if;
    end process fsm_input_proc;

    -- Instantiate ALU
    ula_inst_mod: ula2_mod
        port map (
            IN1 => signed(reg_a),
            IN2 => signed(reg_b),
            SEL_OP => reg_op,
            OUT_ANS => reg_result,
            FLAG_ZERO => flag_z,
            FLAG_NEG => flag_n,
            FLAG_CARRY => flag_c,
            FLAG_OVER => flag_v
        );

    -- Connect ALU result to green LEDs
    LED_GREEN <= reg_result;

    -- Display FSM state on red LEDs
    LED_RED(7) <= '1' when state_input_sig = ST_SHOW_RES else '0';
    LED_RED(6) <= '1' when state_input_sig = ST_INPUT_B else '0';
    LED_RED(5) <= '1' when state_input_sig = ST_INPUT_A else '0';
    LED_RED(4) <= '1' when state_input_sig = ST_SEL_OP else '0';

    -- Display ALU flags on lower red LEDs
    LED_RED(3) <= flag_v;
    LED_RED(2) <= flag_c;
    LED_RED(1) <= flag_n;
    LED_RED(0) <= flag_z;

end architecture rtl_top_mod;
