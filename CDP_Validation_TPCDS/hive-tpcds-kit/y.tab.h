/* A Bison parser, made by GNU Bison 3.7.4.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2020 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_Y_TAB_H_INCLUDED
# define YY_YY_Y_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    TOK_INT = 258,                 /* TOK_INT  */
    TOK_LITERAL = 259,             /* TOK_LITERAL  */
    TOK_PATH = 260,                /* TOK_PATH  */
    TOK_DECIMAL = 261,             /* TOK_DECIMAL  */
    TOK_ID = 262,                  /* TOK_ID  */
    TOK_SQL = 263,                 /* TOK_SQL  */
    KW_DEFINE = 264,               /* KW_DEFINE  */
    KW_RANDOM = 265,               /* KW_RANDOM  */
    KW_UNIFORM = 266,              /* KW_UNIFORM  */
    KW_RANGE = 267,                /* KW_RANGE  */
    KW_DATE = 268,                 /* KW_DATE  */
    KW_INCLUDE = 269,              /* KW_INCLUDE  */
    KW_TEXT = 270,                 /* KW_TEXT  */
    KW_DIST = 271,                 /* KW_DIST  */
    KW_LIST = 272,                 /* KW_LIST  */
    KW_ROWCOUNT = 273,             /* KW_ROWCOUNT  */
    KW_BEGIN = 274,                /* KW_BEGIN  */
    KW_END = 275,                  /* KW_END  */
    KW_SALES = 276,                /* KW_SALES  */
    KW_RETURNS = 277,              /* KW_RETURNS  */
    KW_DISTMEMBER = 278,           /* KW_DISTMEMBER  */
    KW_DISTWEIGHT = 279,           /* KW_DISTWEIGHT  */
    KW_QUERY = 280,                /* KW_QUERY  */
    KW_STREAM = 281,               /* KW_STREAM  */
    KW_TEMPLATE = 282,             /* KW_TEMPLATE  */
    KW_SEED = 283,                 /* KW_SEED  */
    KW_SCALE = 284,                /* KW_SCALE  */
    KW_SCALE_STEP = 285,           /* KW_SCALE_STEP  */
    KW_SET = 286,                  /* KW_SET  */
    KW_ADD = 287,                  /* KW_ADD  */
    KW_NAMES = 288,                /* KW_NAMES  */
    KW_TYPES = 289,                /* KW_TYPES  */
    KW_WEIGHTS = 290,              /* KW_WEIGHTS  */
    KW_INT = 291,                  /* KW_INT  */
    KW_VARCHAR = 292,              /* KW_VARCHAR  */
    KW_DECIMAL = 293,              /* KW_DECIMAL  */
    KW_LIMIT = 294,                /* KW_LIMIT  */
    KW_LIMITA = 295,               /* KW_LIMITA  */
    KW_LIMITB = 296,               /* KW_LIMITB  */
    KW_LIMITC = 297,               /* KW_LIMITC  */
    KW_ULIST = 298,                /* KW_ULIST  */
    WITH = 299,                    /* WITH  */
    UMINUS = 300,                  /* UMINUS  */
    TCAST = 301                    /* TCAST  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif
/* Token kinds.  */
#define YYEMPTY -2
#define YYEOF 0
#define YYerror 256
#define YYUNDEF 257
#define TOK_INT 258
#define TOK_LITERAL 259
#define TOK_PATH 260
#define TOK_DECIMAL 261
#define TOK_ID 262
#define TOK_SQL 263
#define KW_DEFINE 264
#define KW_RANDOM 265
#define KW_UNIFORM 266
#define KW_RANGE 267
#define KW_DATE 268
#define KW_INCLUDE 269
#define KW_TEXT 270
#define KW_DIST 271
#define KW_LIST 272
#define KW_ROWCOUNT 273
#define KW_BEGIN 274
#define KW_END 275
#define KW_SALES 276
#define KW_RETURNS 277
#define KW_DISTMEMBER 278
#define KW_DISTWEIGHT 279
#define KW_QUERY 280
#define KW_STREAM 281
#define KW_TEMPLATE 282
#define KW_SEED 283
#define KW_SCALE 284
#define KW_SCALE_STEP 285
#define KW_SET 286
#define KW_ADD 287
#define KW_NAMES 288
#define KW_TYPES 289
#define KW_WEIGHTS 290
#define KW_INT 291
#define KW_VARCHAR 292
#define KW_DECIMAL 293
#define KW_LIMIT 294
#define KW_LIMITA 295
#define KW_LIMITB 296
#define KW_LIMITC 297
#define KW_ULIST 298
#define WITH 299
#define UMINUS 300
#define TCAST 301

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 87 "./tpcds-gen/target/tools/qgen.y"

    int		intval;
    char	*strval;
	expr_t	*exprval;
	list_t  *list;
    

#line 167 "y.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
