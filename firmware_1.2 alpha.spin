''***************************************
''*  VGA Terminal 40x15 v1.0            *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2006 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

CON

  _clkmode = xtal1+pll16x
  _clkfreq = 80_000_000

  vga_params = 21
  x_tiles = 24
  y_tiles = 15

  x_screen = x_tiles << 4
  y_screen = y_tiles << 4

  width = 0             '0 = minimum
  x_scale = 1           '1 = minimum
  y_scale = 1           '1 = minimum
  x_spacing = 6         '6 = normal
  y_spacing = 13        '13 = normal

  x_chr = x_scale * x_spacing
  y_chr = y_scale * y_spacing

  y_offset = y_spacing / 6 + y_chr - 1

  x_limit = x_screen / (x_scale * x_spacing)
  y_limit = y_screen / (y_scale * y_spacing)
  y_max = y_limit - 1

  y_screen_bytes = y_screen << 2
  y_scroll = y_chr << 2
  y_scroll_longs = y_chr * y_max
  y_clear = y_scroll_longs << 2
  y_clear_longs = y_screen - y_scroll_longs       
  'bitmap_base = $5000 

VAR

  long  vga_status      'status: off/visible/invisible  read-only       (21 contiguous longs)
  long  vga_enable      'enable: off/on                 write-only
  long  vga_pins        'pins: byte(2),topbit(3)        write-only
  long  vga_mode        'mode: interlace,hpol,vpol      write-only
  long  vga_videobase   'video base @word               write-only
  long  vga_colorbase   'color base @long               write-only              
  long  vga_hc          'horizontal cells               write-only
  long  vga_vc          'vertical cells                 write-only
  long  vga_hx          'horizontal cell expansion      write-only
  long  vga_vx          'vertical cell expansion        write-only
  long  vga_ho          'horizontal offset              write-only
  long  vga_vo          'vertical offset                write-only
  long  vga_hd          'horizontal display pixels      write-only
  long  vga_hf          'horizontal front-porch pixels  write-only
  long  vga_hs          'horizontal sync pixels         write-only
  long  vga_hb          'horizontal back-porch pixels   write-only
  long  vga_vd          'vertical display lines         write-only
  long  vga_vf          'vertical front-porch lines     write-only
  long  vga_vs          'vertical sync lines            write-only
  long  vga_vb          'vertical back-porch lines      write-only
  long  vga_rate        'pixel rate (Hz)                write-only

  'word  screen[screensize]         
  word  screen[x_tiles * y_tiles+16]                                                          
  long  bitmap[x_tiles * y_tiles << 4 + 16]     'add 16 longs to allow for 64-byte alignment
  long  colors[64]
  byte strptr[256]
  byte VRAM[1024]
  long  x, y, bitmap_base   

OBJ

  vga   : "vga"
  gr    : "graphics"
  pst   : "Parallax Serial Terminal"

PUB boot |mode,in, xa, xb, ya, yb, i, c, dx, dy , tmp 
  dira[7]~~   
  'start tv
  bitmap_base := (@bitmap + $3F) & $7FC0
  repeat x from 0 to x_tiles - 1
    repeat y from 0 to y_tiles - 1
      screen[y * x_tiles + x] := bitmap_base >> 6 + y + x * y_tiles
  longmove(@vga_status, @vgaparams, vga_params)
  vga_videobase := @screen
  vga_colorbase := @colors
  vga.start(@vga_status)

  'init colors
  repeat i from 0 to 63
    colors[i] := %00100000100000001111110000000000    
  'init tile screen
  i:=0
  repeat x from 0 to vga_hc - 1
    repeat y from 0 to vga_vc - 1
      screen[x + y * vga_hc] := (i/3) << 10 + bitmap_base >> 6 + x * vga_vc + y
      i:=i+1

  'start and setup graphics
  gr.start
  gr.setup(x_tiles, y_tiles, 0, 0, bitmap_base)
  out(0)             
  pst.start(115200)    
  pst.char(48)    
  mode:=1   
  repeat                  
    in:=pst.charin
    !outa[7]          
    if in==32
      pst.str(string("NGT20",13))  
    elseif in==48
      reboot
    elseif in==49  
      out(0)          
    elseif in==51
      pst.strin(@strptr)',255)
      str(@strptr)   
    elseif in==52                 
      xa:=(pst.charin<<8)|pst.charin
      ya:=187-(pst.charin<<8)|pst.charin
      xb:=(pst.charin<<8)|pst.charin
      yb:=187-(pst.charin<<8)|pst.charin
      gr.plot(xa,ya)
      gr.line(xb,yb)      
    elseif in==53
      out(0)
      in:=pst.charin     
      gr.color(in&3)                         
      repeat x_screen*y_screen
        out(32)   
        x :=0
        y:=1     
    elseif in==57
      in:=pst.charin                             
      gr.color(in&3) 
    elseif in==60
      gr.finish   
    elseif in==61
      in:=pst.charin
      tmp:=colors[in&63]&!($FF<<(8*(in>>6)))                             
      colors[in&63]:=tmp|(pst.charin<<(8*(in>>6)))
    elseif in==62                
      gr.pix((pst.charin<<8)|pst.charin, (pst.charin<<8)|pst.charin, pst.charin,(pst.charin<<8)|pst.charin+@VRAM)
    elseif in==63
      xa:=(pst.charin<<8)|pst.charin
      if xa<1024
        VRAM[xa]:=pst.charin               
    elseif in==65
      x:=pst.charin
      y:=pst.charin+1 
    elseif in==$D
      newline
    pst.char(48)
    outa[7]~ 
PUB out(c)

'' Print a character
''
''       $00 = home
''  $01..$03 = color
''  $04..$07 = color schemes
''       $09 = tab
''       $0D = return
''  $20..$7E = character

  case c

    $00:                'home?
      gr.clear
      x :=0
      y:=1

    $01..$03:           'color?
      gr.color(c)
    $08:
      --x
      if x<=0
        x:=x+x_limit-1
        --y
        if y<=0
          y:=1
    $09:                'tab?
      repeat
        out($20)
      while x & 7

    $0D:                'return?
      newline

    $20..$7E:           'character?
      gr.text(x * x_chr, 196 - (y*y_spacing+y_offset), @c)
      gr.finish
      if ++x == x_limit
        newline


PUB str(string_ptr)

'' Print a zero-terminated string

  repeat strsize(string_ptr)
    out(byte[string_ptr++])


PUB dec(value) | i

'' Print a decimal number

  if value < 0
    -value
    out("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      out(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      out("0")
    i /= 10


PUB hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    out(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


PUB bin(value, digits)

'' Print a binary number

  value <<= 32 - digits
  repeat digits
    out((value <-= 1) & 1 + "0")


PRI newline

  if ++y == y_limit
    gr.finish
    repeat x from 0 to x_tiles - 1
      y := bitmap_base + x * y_screen_bytes
      longmove(y, y + y_scroll, y_scroll_longs)
      longfill(y + y_clear, 0, y_clear_longs)
    y := y_max
  x := 0

DAT

vgaparams               long    0               'status
                        long    1               'enable
                        long    %010_111        'pins
                        long    %011            'mode
                        long    0               'videobase
                        long    0               'colorbase
                        long    x_tiles            'hc
                        long    y_tiles            'vc
                        long    1               'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    512             'hd
                        long    16              'hf
                        long    96              'hs
                        long    48              'hb
                        long    380             'vd
                        long    11              'vf
                        long    2               'vs
                        long    31              'vb
                        long    20_000_000      'rate
vgacolors               long
                        long    $C000C000       'red
                        long    $C0C00000
                        long    $08A808A8       'green
                        long    $0808A8A8
                        long    $50005000       'blue
                        long    $50500000
                        long    $FC00FC00       'white
                        long    $FCFC0000
                        long    $FF80FF80       'red/white
                        long    $FFFF8080
                        long    $FF20FF20       'green/white
                        long    $FFFF2020
                        long    $FF28FF28       'cyan/white
                        long    $FFFF2828
                        long    $00A800A8       'grey/black
                        long    $0000A8A8
                        long    $C0408080       'redbox
spcl                    long    $30100020       'greenbox
                        long    $3C142828       'cyanbox
                        long    $FC54A8A8       'greybox
                        long    $3C14FF28       'cyanbox+underscore
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
 }}                        