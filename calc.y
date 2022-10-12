%{
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include "calc.h"
/* prototypes */
nodeType *opr(int oper, int nops, ...);
nodeType *id(int i);
nodeType *con(int value);
void freeNode(nodeType *p);
int ex(nodeType *p);
int yylex(void);
void yyerror(char *s);
int sym[26];
%}

%union {
	int iValue;			/* Integer value */
	char sIndex;		/* Symbol table index */
	nodeType *nptr;		/* node pointer */
};

%token <iValue> INTEGER
%token <sIndex> VARIABLE
%token WHILE IF PRINT

%nonassoc IFX
%nonassoc ELSE

%left GE EQ LE NE '<' '>'
%left '+' '-'
%left '*' '/'

%nonassoc UMINUS

%type <nptr> stmt expr stmt_list

%%

program:
	   function
	   ;

function:
		function stmt					{ex($2); freeNode($2);}
		|
		;

stmt:
	';'									{$$ = opr(';', 2, NULL, NULL);}
	| expr ';'							{$$ = $1;}
	| PRINT expr ';'					{$$ = opr(PRINT, 1, $2);}
	| VARIABLE '=' expr ';'				{$$ = opr('=', 2, id($1), $3);}
	| WHILE '(' expr ')' stmt			{$$ = opr(WHILE, 2, $3, $5);}
	| IF '(' expr ')' stmt %prec IFX	{$$ = opr(IF, 2, $3, $5);}
	| IF '(' expr ')' stmt ELSE stmt	{$$ = opr(IF, 3, $3, $5, $7);}
	| '{' stmt_list '}'					{$$ = $2;}
	;

stmt_list:
		 stmt							{ $$ = $1;}
		 | stmt_list stmt				{ $$ = opr(';', 2, $1, $2); }
		 ;
expr:
	INTEGER								{$$ = con($1);}
	| VARIABLE							{$$ = id($1);}
	| '-' expr %prec UMINUS				{$$ = opr(UMINUS, 1, $2);}
	| expr '+' expr						{$$ = opr('+', 2, $1, $3);}
	| expr '-' expr						{$$ = opr('-', 2, $1, $3);}
	| expr '*' expr						{$$ = opr('*', 2, $1, $3);}
	| expr '/' expr						{$$ = opr('/', 2, $1, $3);}
	| expr '<' expr						{$$ = opr('<', 2, $1, $3);}
	| expr '>' expr						{$$ = opr('>', 2, $1, $3);}
	| expr GE expr						{$$ = opr(GE, 2, $1, $3);}
	| expr LE expr						{$$ = opr(LE, 2, $1, $3);}
	| expr EQ expr						{$$ = opr(EQ, 2, $1, $3);}
	| expr NE expr						{$$ = opr(NE, 2, $1, $3);}
	| '(' expr ')'						{$$ = $2;}
	;
%%

#define ERROR(str) \
	fprintf(stderr, str);

nodeType* con(int value) {
	nodeType *p;

	if((p = (nodeType *) malloc(sizeof(nodeType))) == NULL)
		ERROR("OUT OF MEMORY\n");

	p->type = typeCon;
	p->con.value = value;

	return p;
}

nodeType *id(int i) {
	nodeType *p;

	if((p = (nodeType *) malloc(sizeof(nodeType))) == NULL)
		ERROR("OUT OF MEMORY\n");

	p->type = typeId;
	p->id.i = i;

	return p;
}

nodeType *opr(int opr, int nops, ...) {
	nodeType *p;
	va_list ap;

	if((p = (nodeType *) malloc(sizeof(nodeType))) == NULL)
		ERROR("OUT OF MEMORY\n");
	if((p->opr.op = (nodeType **) malloc(nops * sizeof(nodeType *))) == NULL)
		ERROR("OUT OF MEMORY\n");
	
	p->type = typeOpr;
	p->opr.oper = opr;
	p->opr.nops = nops;
	va_start(ap, nops);
	for(int i = 0; i < nops; i++) {
		p->opr.op[i] = va_arg(ap, nodeType *);
	}
	va_end(ap);
	return p;
}

void freeNode(nodeType *p) {
	int i;
	if(!p) return;
	if(p->type == typeOpr) {
		for(int i = 0; i < p->opr.nops; i++) {
			freeNode(p->opr.op[i]);
		}
		free(p->opr.op);
	}
	free(p);
}

static int lbl;

int ex(nodeType *p) {
	int lbl1, lbl2;
	
	if(!p) return 0;
	switch(p->type) {
	case typeCon:
		printf("push %d\n", p->con.value);
		break;
	case typeId:
		printf("push %c\n", p->id.i + 'a');
		break;
	case typeOpr:
		switch(p->opr.oper) {
		case WHILE:
			printf("lbl%d:\n", lbl1 = lbl++);
			ex(p->opr.op[0]);
			printf("jz lbl%d\n", lbl2 = lbl++);
			ex(p->opr.op[1]);
			printf("jmp lbl%d\n", lbl1);
			printf("lbl%d\n", lbl2);
			break;
		case IF:
			ex(p->opr.op[0]);
			if(p->opr.nops > 2) {
				printf("jz lbl%d\n", lbl1 = lbl++);
				ex(p->opr.op[1]);
				printf("jmp lbl%d\n", lbl2 = lbl++);
				printf("lbl%d\n", lbl1);
				ex(p->opr.op[2]);
				printf("lbl%d\n", lbl2);
			}
			else {
				printf("jz lbl%d\n", lbl1 = lbl++);
				ex(p->opr.op[1]);
				printf("lbl%d\n", lbl1);
			}
			break;
		case PRINT:
			ex(p->opr.op[1]);
			printf("print\n");
			break;
		case '=':
			ex(p->opr.op[1]);
			printf("pop %c\n", p->opr.op[0]->id.i + 'a');
			break;
		case UMINUS:
			ex(p->opr.op[0]);
			printf("neg\n");
			break;
		default:
			ex(p->opr.op[0]);
			ex(p->opr.op[1]);
			switch(p->opr.oper) {
			case '+':
				printf("add\n");
				break;
			case '-':
				printf("sub\n");
				break;
			case '*':
				printf("mul\n");
				break;
			case '/':
				printf("div\n");
				break;
			case '<':
				printf("compLT\n");
				break;
			case '>':
				printf("compGT\n");
				break;
			case GE:
				printf("compGE\n");
				break;
			case LE:
				printf("compLE\n");
				break;
			case EQ:
				printf("compEQ\n");
				break;
			case NE:
				printf("compNE\n");
				break;
			}
		}
	}
}


void yyerror(char *s) {
	fprintf(stderr, "%s\n", s);
}

int main(void) {
	yyparse();
	return 0;
}
