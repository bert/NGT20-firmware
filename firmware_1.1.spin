''***************************************
''*  TV Terminal v1.1                   *
''*  Author: Chip Gracey                *
''*  Copyright (c) 2005 Parallax, Inc.  *
''*  See end of file for terms of use.  *
''***************************************

{-----------------REVISION HISTORY-----------------
 v1.1 - Updated 5/15/2006 to use actual pin number, instead of pin group, for Start method's basepin parameter.
 V1.0 - Made into firmware for NGT15 (March 2017) by Dylan Brophy. 


 }
 
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000           
  '_stack = ($3000 + $3000 + 100) >> 2   'accomodate display memory and stack
  x_tiles = 16
  y_tiles = 12

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

  paramcount = 14          
  bitmap_base = $5000   

  
VAR

  long  x, y  'bitmap_base

  long  tv_status     '0/1/2 = off/visible/invisible           read-only
  long  tv_enable     '0/? = off/on                            write-only
  long  tv_pins       '%ppmmm = pins                           write-only
  long  tv_mode       '%ccinp = chroma,interlace,ntsc/pal,swap write-only
  long  tv_screen     'pointer to screen (words)               write-only
  long  tv_colors     'pointer to colors (longs)               write-only               
  long  tv_hc         'horizontal cells                        write-only
  long  tv_vc         'vertical cells                          write-only
  long  tv_hx         'horizontal cell expansion               write-only
  long  tv_vx         'vertical cell expansion                 write-only
  long  tv_ho         'horizontal offset                       write-only
  long  tv_vo         'vertical offset                         write-only
  long  tv_broadcast  'broadcast frequency (Hz)                write-only
  long  tv_auralcog   'aural fm cog                            write-only             
  'long  bitmap[x_tiles * y_tiles << 4 + 16]     'add 16 longs to allow for 64-byte alignment
  word  screen[x_tiles * y_tiles]
  long  colors[64]
  byte strptr[256]
  byte VRAM[1024]

OBJ

  tv    : "tv"
  gr    : "graphics"
  pst   : "Parallax Serial Terminal" 

PUB boot |mode,in, xa, xb, ya, yb, i, c, dx, dy , tmp 
  dira[7]~~   
  'start tv
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen
  tv_colors := @colors
  tv.start(@tv_status)

  'init colors
  repeat i from 0 to 63
    colors[i] := $10001010 * (i+4) & $F + $2B060C02
  'init tile screen
  i:=0
  repeat x from 0 to tv_hc - 1
    repeat y from 0 to tv_vc - 1
      screen[x + y * tv_hc] := (i/3) << 10 + bitmap_base >> 6 + x * tv_vc + y
      i:=i+1

  'start and setup graphics
  gr.start
  gr.setup(16, 12, 0, 0, bitmap_base)
  out(0)             
  pst.start(115200)    
  pst.char(48)    
  mode:=1   
  repeat
    repeat while mode==0
      in:=pst.charin
      !outa[7]          
      if in==32
        pst.str(string("NGT20",13))  
      elseif in==48
        reboot
      elseif in==49
        gr.clear
      elseif in==50
        mode:=pst.charin-48     
      elseif in==52                 
        xa:=(pst.charin<<8)|pst.charin
        ya:=187-(pst.charin<<8)|pst.charin
        xb:=(pst.charin<<8)|pst.charin
        yb:=187-(pst.charin<<8)|pst.charin
        gr.plot(xa,ya)
        gr.line(xb,yb)     
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
      pst.char(48)
      outa[7]~
    repeat while mode==1
      in:=pst.charin           
      !outa[7]
      if in==32
        pst.str(string("NGT20",13))  
      elseif in==48
        reboot
      elseif in==49 
        out(0)
      elseif in==50
        mode:=pst.charin-48      
      elseif in==51
        pst.strin(@strptr)',255)
        str(@strptr)       
      elseif in==52
        x:=pst.charin
        y:=pst.charin+1      
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
      elseif in==61
        in:=pst.charin
        tmp:=colors[in&63]&!($FF<<(8*(in>>6)))                             
        colors[in&63]:=tmp|(pst.charin<<(8*(in>>6)))                                                             
      elseif in==63
        xa:=(pst.charin<<8)|pst.charin
        if xa<1024
          VRAM[xa]:=pst.charin
      elseif in==$D
        newline
      pst.char(48)
      outa[7]~
    if mode>1
      mode:=0                 
PUB start(basepin) | i, j, k, kk, dx, dy, pp, pq, rr, numx, numchr     

'' Start terminal
''
''  basepin = first of three pins on a 4-pin boundary (0, 4, 8...) to have
''  1.1k, 560, and 270 ohm resistors connected and summed to form the 1V,
''  75 ohm DAC for baseband video   

  'init bitmap and tile screen
  'bitmap_base := (@bitmap + $3F) & $7FC0
  repeat x from 0 to x_tiles - 1
    repeat y from 0 to y_tiles - 1
      screen[y * x_tiles + x] := bitmap_base >> 6 + y + x * y_tiles
  i:=0
  repeat x from 0 to tv_hc - 1
    repeat y from 0 to tv_vc - 1
      screen[x + y * tv_hc] := i << 10 + bitmap_base >> 6 + x * tv_vc + y
      i:=i+1
  repeat dx from 0 to tv_hc - 1
    repeat dy from 0 to tv_vc - 1
      screen[dy * tv_hc + dx] := bitmap_base >> 6 + dy + dx * tv_vc + ((dy & $3F) << 10)          
  repeat i from 0 to 63
    colors[i] := $00001010 * (i+4) & $F + $2B060C02  
  'start tv
  tvparams_pins := (basepin & $38) << 1 | (basepin & 4 == 4) & %0101
  longmove(@tv_status, @tvparams, paramcount)
  tv_screen := @screen          
  tv_colors := @colors
  tv.start(@tv_status)

  'start graphics
  gr.start
  'gr.setup(x_tiles, y_tiles, 0, y_screen, bitmap_base)
  gr.setup(16, 12, 128, 96, bitmap_base)
  gr.textmode(x_scale, y_scale, x_spacing, 0)
  gr.width(width)
  gr.clear
  out(0)


PUB stop

'' Stop terminal

  tv.stop
  gr.stop


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

    $04..$07:           'color scheme?
      tv_colors := @color_schemes[c & 3]
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

tvparams                long    0               'status
                        long    1               'enable
tvparams_pins           long    %001_0101       'pins
                        long    %0000           'mode
                        long    0               'screen
                        long    0               'colors
                        long    x_tiles         'hc
                        long    y_tiles         'vc
                        long    10              'hx
                        long    1               'vx
                        long    0               'ho
                        long    0               'vo
                        long    55_250_000      'broadcast
                        long    0               'auralcog

color_schemes           long    $BC_6C_05_02
                        long    $0E_0D_0C_0A
                        long    $6E_6D_6C_6A
                        long    $BE_BD_BC_BA
pixdef2                 word                            'dog
                        byte    1,4,0,3
                        word    %%20000022
                        word    %%02222222
                        word    %%02222200
                        word    %%02000200
   
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