convert +append ./figures/o.png ./figures/p1.png ./figures/top.png
convert +append ./figures/cart.png ./figures/p2.png ./figures/bottom.png
convert -append ./figures/top.png ./figures/bottom.png ./figures/cart.png
rm ./figures/o.png
rm ./figures/p*.png
rm ./figures/top.png
rm ./figures/bottom.png
