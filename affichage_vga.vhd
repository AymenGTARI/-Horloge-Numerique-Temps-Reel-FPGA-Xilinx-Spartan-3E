library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_affichage is
  port(
    clk_25  : in  std_logic;
    rst     : in  std_logic;
    min     : in  std_logic_vector(5 downto 0);
    heure   : in  std_logic_vector(4 downto 0);
    hsync   : out std_logic;
    vsync   : out std_logic;
    vga_r   : out std_logic_vector(2 downto 0);
    vga_g   : out std_logic_vector(2 downto 0);
    vga_b   : out std_logic_vector(2 downto 0)
  );
end vga_affichage;

architecture Behavioral of vga_affichage is

  -- -- Timings VGA 640×480 @ 60 Hz --
  constant H_DISP  : integer := 640;
  constant H_FP    : integer := 16;
  constant H_SYNC  : integer := 96;
  constant H_BP    : integer := 48;
  constant H_TOTAL : integer := 800;

  constant V_DISP  : integer := 480;
  constant V_FP    : integer := 10;
  constant V_SYNC  : integer := 2;
  constant V_BP    : integer := 33;
  constant V_TOTAL : integer := 525;

  signal h_cnt : integer range 0 to H_TOTAL - 1 := 0;
  signal v_cnt : integer range 0 to V_TOTAL - 1 := 0;

  signal visible : std_logic;

  -- -- Police bitmap 8×16, échelle ×8 ? chiffre 64×128 px --
  -- SCALE=8 est une puissance de 2 : division = décalage de 3 bits
  -- CHAR_W=64, CHAR_H=128, N_CHARS=5, TOTAL_W=320
  constant CHAR_W  : integer := 64;   -- 8 cols × 8
  constant CHAR_H  : integer := 128;  -- 16 rows × 8
  constant TOTAL_W : integer := 320;  -- 5 chars × 64

  -- Centrage : START_X=160, START_Y=176
  constant START_X : integer := 160;
  constant START_Y : integer := 176;

  -- -- ROM fonte 8×16 (chiffres 0-9 + ':') --
  type font_char is array(0 to 15) of std_logic_vector(7 downto 0);
  type font_rom  is array(0 to 10) of font_char;

  constant FONT : font_rom := (
    0  => ("00111100","01100110","01100110","01101110",
           "01110110","01100110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    1  => ("00011000","00111000","00011000","00011000",
           "00011000","00011000","00011000","01111110",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    2  => ("00111100","01100110","00000110","00001100",
           "00011000","00110000","01100000","01111110",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    3  => ("00111100","01100110","00000110","00011100",
           "00000110","00000110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    4  => ("00001100","00011100","00110100","01100100",
           "01111110","00000100","00000100","00000100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    5  => ("01111110","01100000","01100000","01111100",
           "00000110","00000110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    6  => ("00111100","01100110","01100000","01111100",
           "01100110","01100110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    7  => ("01111110","00000110","00000110","00001100",
           "00011000","00011000","00011000","00011000",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    8  => ("00111100","01100110","01100110","00111100",
           "01100110","01100110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    9  => ("00111100","01100110","01100110","00111110",
           "00000110","00000110","01100110","00111100",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000"),
    10 => ("00000000","00000000","00011000","00011000",
           "00000000","00000000","00011000","00011000",
           "00000000","00000000","00000000","00000000",
           "00000000","00000000","00000000","00000000")
  );

  -- -- Décodage hh:mm en 4 chiffres (sans division) --
  signal hd, hu, md, mu : integer range 0 to 9 := 0;
  signal h_int          : integer range 0 to 23;
  signal m_int          : integer range 0 to 59;

  -- -- Pixel courant --
  signal on_text : std_logic := '0';

begin

  -- -- Décodage heure --
  h_int <= to_integer(unsigned(heure));
  m_int <= to_integer(unsigned(min));

  -- Dizaines/unités sans opérateur divise
  process(h_int)
  begin
    if    h_int >= 20 then hd <= 2; hu <= h_int - 20;
    elsif h_int >= 10 then hd <= 1; hu <= h_int - 10;
    else                   hd <= 0; hu <= h_int;
    end if;
  end process;

  process(m_int)
  begin
    if    m_int >= 50 then md <= 5; mu <= m_int - 50;
    elsif m_int >= 40 then md <= 4; mu <= m_int - 40;
    elsif m_int >= 30 then md <= 3; mu <= m_int - 30;
    elsif m_int >= 20 then md <= 2; mu <= m_int - 20;
    elsif m_int >= 10 then md <= 1; mu <= m_int - 10;
    else                   md <= 0; mu <= m_int;
    end if;
  end process;

  -- -- Compteurs de balayage --
  process(clk_25)
  begin
    if rising_edge(clk_25) then
      if rst = '1' then
        h_cnt <= 0; v_cnt <= 0;
      else
        if h_cnt = H_TOTAL - 1 then
          h_cnt <= 0;
          if v_cnt = V_TOTAL - 1 then v_cnt <= 0;
          else v_cnt <= v_cnt + 1;
          end if;
        else
          h_cnt <= h_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  -- -- Synchros (polarité négative) --
  hsync <= '0' when (h_cnt >= H_DISP + H_FP and
                     h_cnt <  H_DISP + H_FP + H_SYNC) else '1';
  vsync <= '0' when (v_cnt >= V_DISP + V_FP and
                     v_cnt <  V_DISP + V_FP + V_SYNC) else '1';

  visible <= '1' when (h_cnt < H_DISP and v_cnt < V_DISP) else '0';

  -- ----------------------------------------------------------------
  -- Génération pixel texte
  -- SCALE=8 (puissance de 2) ? décalage de 3 bits à droite
  --   char_no  = cx >> 6   (CHAR_W=64=2^6)
  --   fx       = (cx & 63) >> 3  (SCALE=8=2^3 ? bits [5:3])
  --   fy       = cy >> 3          (SCALE=8=2^3)
  -- ----------------------------------------------------------------
  process(h_cnt, v_cnt, visible, hd, hu, md, mu)
    variable cx      : integer range -640 to 1280;
    variable cy      : integer range -480 to 960;
    variable char_no : integer range 0 to 7;
    variable fx      : integer range 0 to 7;
    variable fy      : integer range 0 to 15;
    variable font_id : integer range 0 to 10;
    variable row     : std_logic_vector(7 downto 0);
    variable cx_u    : unsigned(9 downto 0);
    variable cy_u    : unsigned(9 downto 0);
  begin
    on_text <= '0';
    if visible = '1' then
      cx := h_cnt - START_X;
      cy := v_cnt - START_Y;
      if cx >= 0 and cx < TOTAL_W and cy >= 0 and cy < CHAR_H then
        cx_u    := to_unsigned(cx, 10);
        cy_u    := to_unsigned(cy, 10);
        -- Décalages (CHAR_W=64=2^6, SCALE=8=2^3)
        char_no := to_integer(cx_u(8 downto 6));  -- cx / 64
        fx      := to_integer(cx_u(5 downto 3));  -- (cx mod 64) / 8
        fy      := to_integer(cy_u(6 downto 3));  -- cy / 8  ? ligne fonte 0..15
        case char_no is
          when 0      => font_id := hd;
          when 1      => font_id := hu;
          when 2      => font_id := 10;
          when 3      => font_id := md;
          when 4      => font_id := mu;
          when others => font_id := 10;
        end case;
        row := FONT(font_id)(fy);
        on_text <= row(7 - fx);
      end if;
    end if;
  end process;

  -- -- Couleurs --
  process(visible, on_text)
  begin
    if visible = '0' then
      vga_r <= "000"; vga_g <= "000"; vga_b <= "000";
    elsif on_text = '1' then
      vga_r <= "111"; vga_g <= "111"; vga_b <= "111";  -- blanc
    else
      vga_r <= "000"; vga_g <= "000"; vga_b <= "010";  -- fond bleu foncé
    end if;
  end process;

end Behavioral;