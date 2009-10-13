set term postscript enhanced solid color lw 2 "Times" 21
set output "ferror.eps"

set grid

set xlabel "Temperature Index"
set ylabel "Frequency Error"
set title "Estimated Frequency Error"
plot 'node6.log' using 2:4 with linespoints title "Node 6",\
     'node7.log' using 2:4 with linespoints title "Node 7",\
     'node8.log' using 2:4 with linespoints title "Node 8"
