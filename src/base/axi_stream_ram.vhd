-- ============================================================================
-- Entity: stream_ram_interface
-- Description:
--   This module provides an interface between an AXI-Stream-like input and a
--   single-port RAM. It writes streaming data into RAM and provides a
--   separate read interface. Assumes MEMORY_DEPTH_g is larger than the
--   total number of incoming data words.
-- ============================================================================

library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library work;
    use work.math_utils.all;
    
entity axi_stream_ram_interface is
    generic(
        DATA_WIDTH_g : positive := 32;
        MEMORY_DEPTH_g : positive := 32
    );
    Port (
        clk : in std_logic;
        rst : in std_logic;
        -- axi stream signal
        -- input from kyber
        s_valid : in std_logic;
        s_ready :out std_logic;
        s_data : in std_logic_vector(DATA_WIDTH_g-1 downto 0);
        s_last : in std_logic;    
        -- read memory
        Rd_en : in std_logic;
        Rd_Addr : in std_logic_vector(clog2(MEMORY_DEPTH_g)-1 downto 0);
        Rd_data : out std_logic_vector(DATA_WIDTH_g-1 downto 0)
    );
end axi_stream_ram_interface;

architecture Behavioral of axi_stream_ram_interface is
    signal Rd_data_s :  std_logic_vector(DATA_WIDTH_g-1 downto 0);
    signal Wr_Addr : std_logic_vector(clog2(MEMORY_DEPTH_g)-1 downto 0);
    type state_t is (IDLE_st, WRITE_MEM_st);
    -- interface of memory
    type TwoProcess_r is record
        state : state_t;
        -- write interface for sram
        Wr_En :  std_logic;
        Wr_Addr : unsigned(clog2(MEMORY_DEPTH_g)-1 downto 0);
        Wr_Data : std_logic_vector(DATA_WIDTH_g-1 downto 0);
        -- ready back pressure
        s_ready : std_logic;
    end record;
    
    signal r, r_next : TwoProcess_r;
begin
    -- output ram
    Rd_data <= Rd_data_s;
    s_ready <= r.s_ready;
    -- sequantial process
    seq_proc: process(clk)
        begin
            if rising_edge(clk) then
                if rst = '1' then
                    r <= (
                        state => IDLE_st,
                        Wr_En => '0',
                        Wr_Addr => (others => '0'),
                        Wr_Data => (others => '0')  ,
                        s_ready => '0'           
                        );
                else
                    r <= r_next;       
                end if;
            end if;
        end process seq_proc;

    -- combinatiorial process
    comb_proc: process(all)
        variable v : TwoProcess_r;
        begin
            -- stable variable
            v := r;
            -- default write 
            v.Wr_En := '0';
            -- state machine
            case(r.state) is
                when IDLE_st =>
                    v.Wr_Addr := (others => '0');
                    v.s_ready := '1';
                    if (r.s_ready = '1' and s_valid = '1') then
                        v.Wr_En := '1';
                        v.Wr_Data := s_data;
                        v.state := WRITE_MEM_st;
                    end if;
                when WRITE_MEM_st =>
                    -- ready back pressure
                    if (r.s_ready = '1' and s_valid = '1') then
                           v.s_ready := '0';
                           if (s_last = '1') then
                               v.state := IDLE_st;
                           end if;  
                           if (r.Wr_Addr <= MEMORY_DEPTH_g -2) then
                              v.s_ready := '1';
                              v.Wr_En := '1';
                              v.Wr_Data := s_data;
                              v.Wr_Addr := r.Wr_Addr + 1;
                           end if;  
                     end if;
            end case;
            r_next <= v;
        end process comb_proc;
    
    Wr_Addr <= std_logic_vector(r.Wr_Addr);
    -- instantiation of ram
    u_ram_sp : entity work.ram_sp
    generic map (
        DEPTH => MEMORY_DEPTH_g,
        WIDTH => DATA_WIDTH_g
    )
    port map (
        clk     => clk,

        -- write interface
        Wr_En   => r.Wr_En,
        Wr_Addr => Wr_Addr,
        Wr_Data => r.Wr_Data,

        -- read interface
        Rd_En   => Rd_en,
        Rd_Addr => Rd_Addr,
        Rd_Data => Rd_data_s
    );

end Behavioral;
