library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_div_vga is
  port(clk : in std_logic; clk_25 : out std_logic);
end clk_div_vga;

architecture behav of clk_div_vga is
  signal toggle : std_logic := '0';
begin
  process(clk)
  begin
    if rising_edge(clk) then
      toggle <= not toggle;
    end if;
  end process;
  clk_25 <= toggle;
end behav;