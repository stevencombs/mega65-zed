10 rem basic 2.0 sample
20 print "{clr}{wht}hello {rght}"
30 for i=1 to 10 step 2
40 print i;"{red}"
50 next i
60 if a<>1 then goto 20
70 data 1,2,"a:b"
80 a$="x":b%=1
90 let n=1.5e+3
100 poke 53280,peek(53281) and 15
110 print chr$(147);left$("ab",1)
120 go to 10
130 total=1
140 ?"shortcut"
