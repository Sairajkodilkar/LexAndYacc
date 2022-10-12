calc: calc_lex.c calc_y.c calc.h calc_y.h
	cc calc_lex.c calc_y.c -o calc

calc_y.c: calc.y
	yacc calc.y -o calc_y.c -d

calc_lex.c: calc.lex
	lex -t calc.lex > calc_lex.c
