/* A Bison parser, made by GNU Bison 3.7.4.  */

/* Bison implementation for Yacc-like parsers in C

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

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output, and Bison version.  */
#define YYBISON 30704

/* Bison version string.  */
#define YYBISON_VERSION "3.7.4"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Push parsers.  */
#define YYPUSH 0

/* Pull parsers.  */
#define YYPULL 1




/* First part of user prologue.  */
#line 1 "./tpcds-gen/target/tools/qgen.y"

/* 
 * Legal Notice 
 * 
 * This document and associated source code (the "Work") is a part of a 
 * benchmark specification maintained by the TPC. 
 * 
 * The TPC reserves all right, title, and interest to the Work as provided 
 * under U.S. and international laws, including without limitation all patent 
 * and trademark rights therein. 
 * 
 * No Warranty 
 * 
 * 1.1 TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, THE INFORMATION 
 *     CONTAINED HEREIN IS PROVIDED "AS IS" AND WITH ALL FAULTS, AND THE 
 *     AUTHORS AND DEVELOPERS OF THE WORK HEREBY DISCLAIM ALL OTHER 
 *     WARRANTIES AND CONDITIONS, EITHER EXPRESS, IMPLIED OR STATUTORY, 
 *     INCLUDING, BUT NOT LIMITED TO, ANY (IF ANY) IMPLIED WARRANTIES, 
 *     DUTIES OR CONDITIONS OF MERCHANTABILITY, OF FITNESS FOR A PARTICULAR 
 *     PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OF 
 *     WORKMANLIKE EFFORT, OF LACK OF VIRUSES, AND OF LACK OF NEGLIGENCE. 
 *     ALSO, THERE IS NO WARRANTY OR CONDITION OF TITLE, QUIET ENJOYMENT, 
 *     QUIET POSSESSION, CORRESPONDENCE TO DESCRIPTION OR NON-INFRINGEMENT 
 *     WITH REGARD TO THE WORK. 
 * 1.2 IN NO EVENT WILL ANY AUTHOR OR DEVELOPER OF THE WORK BE LIABLE TO 
 *     ANY OTHER PARTY FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO THE 
 *     COST OF PROCURING SUBSTITUTE GOODS OR SERVICES, LOST PROFITS, LOSS 
 *     OF USE, LOSS OF DATA, OR ANY INCIDENTAL, CONSEQUENTIAL, DIRECT, 
 *     INDIRECT, OR SPECIAL DAMAGES WHETHER UNDER CONTRACT, TORT, WARRANTY,
 *     OR OTHERWISE, ARISING IN ANY WAY OUT OF THIS OR ANY OTHER AGREEMENT 
 *     RELATING TO THE WORK, WHETHER OR NOT SUCH AUTHOR OR DEVELOPER HAD 
 *     ADVANCE NOTICE OF THE POSSIBILITY OF SUCH DAMAGES. 
 * 
 * Contributors:
 * Gradient Systems
 */
#include "config.h"
#include "porting.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifdef WIN32
#include <io.h>
#pragma warning(disable: 4305)
#endif

#include "StringBuffer.h"
#include "expr.h"
#include "grammar_support.h"
#include "keywords.h"
#include "substitution.h"
#include "error_msg.h"
#include "tables.h"
#include "qgen_params.h"
#include "tdefs.h"
#include "query_handler.h"
#include "list.h"
#include "dist.h"
#include "scaling.h"


#define DEBUG0(l, fmt) 				if (l <= verbose) printf(fmt)
#define DEBUG1(l, fmt, arg)			if (l <= verbose) printf(fmt, arg)
#define DEBUG2(l, fmt, arg, arg2)	if (l <= verbose) printf(fmt, arg, arg2)

extern file_ref_t file_stack[];

int yylex(void);

#ifdef WIN32
int yyparse(void);
#endif

/* GLOBAL VARIABLES */
int verbose = 0,
	j,
	nRetCode;
ds_key_t i;
char tmpstr[128];
segment_t *pSegment;
substitution_t *pSub;

#line 157 "y.tab.c"

# ifndef YY_CAST
#  ifdef __cplusplus
#   define YY_CAST(Type, Val) static_cast<Type> (Val)
#   define YY_REINTERPRET_CAST(Type, Val) reinterpret_cast<Type> (Val)
#  else
#   define YY_CAST(Type, Val) ((Type) (Val))
#   define YY_REINTERPRET_CAST(Type, Val) ((Type) (Val))
#  endif
# endif
# ifndef YY_NULLPTR
#  if defined __cplusplus
#   if 201103L <= __cplusplus
#    define YY_NULLPTR nullptr
#   else
#    define YY_NULLPTR 0
#   endif
#  else
#   define YY_NULLPTR ((void*)0)
#  endif
# endif

/* Use api.header.include to #include this header
   instead of duplicating it here.  */
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
    

#line 310 "y.tab.c"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;

int yyparse (void);

#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
/* Symbol kind.  */
enum yysymbol_kind_t
{
  YYSYMBOL_YYEMPTY = -2,
  YYSYMBOL_YYEOF = 0,                      /* "end of file"  */
  YYSYMBOL_YYerror = 1,                    /* error  */
  YYSYMBOL_YYUNDEF = 2,                    /* "invalid token"  */
  YYSYMBOL_TOK_INT = 3,                    /* TOK_INT  */
  YYSYMBOL_TOK_LITERAL = 4,                /* TOK_LITERAL  */
  YYSYMBOL_TOK_PATH = 5,                   /* TOK_PATH  */
  YYSYMBOL_TOK_DECIMAL = 6,                /* TOK_DECIMAL  */
  YYSYMBOL_TOK_ID = 7,                     /* TOK_ID  */
  YYSYMBOL_TOK_SQL = 8,                    /* TOK_SQL  */
  YYSYMBOL_KW_DEFINE = 9,                  /* KW_DEFINE  */
  YYSYMBOL_KW_RANDOM = 10,                 /* KW_RANDOM  */
  YYSYMBOL_KW_UNIFORM = 11,                /* KW_UNIFORM  */
  YYSYMBOL_KW_RANGE = 12,                  /* KW_RANGE  */
  YYSYMBOL_KW_DATE = 13,                   /* KW_DATE  */
  YYSYMBOL_KW_INCLUDE = 14,                /* KW_INCLUDE  */
  YYSYMBOL_KW_TEXT = 15,                   /* KW_TEXT  */
  YYSYMBOL_KW_DIST = 16,                   /* KW_DIST  */
  YYSYMBOL_KW_LIST = 17,                   /* KW_LIST  */
  YYSYMBOL_KW_ROWCOUNT = 18,               /* KW_ROWCOUNT  */
  YYSYMBOL_KW_BEGIN = 19,                  /* KW_BEGIN  */
  YYSYMBOL_KW_END = 20,                    /* KW_END  */
  YYSYMBOL_KW_SALES = 21,                  /* KW_SALES  */
  YYSYMBOL_KW_RETURNS = 22,                /* KW_RETURNS  */
  YYSYMBOL_KW_DISTMEMBER = 23,             /* KW_DISTMEMBER  */
  YYSYMBOL_KW_DISTWEIGHT = 24,             /* KW_DISTWEIGHT  */
  YYSYMBOL_KW_QUERY = 25,                  /* KW_QUERY  */
  YYSYMBOL_KW_STREAM = 26,                 /* KW_STREAM  */
  YYSYMBOL_KW_TEMPLATE = 27,               /* KW_TEMPLATE  */
  YYSYMBOL_KW_SEED = 28,                   /* KW_SEED  */
  YYSYMBOL_KW_SCALE = 29,                  /* KW_SCALE  */
  YYSYMBOL_KW_SCALE_STEP = 30,             /* KW_SCALE_STEP  */
  YYSYMBOL_KW_SET = 31,                    /* KW_SET  */
  YYSYMBOL_KW_ADD = 32,                    /* KW_ADD  */
  YYSYMBOL_KW_NAMES = 33,                  /* KW_NAMES  */
  YYSYMBOL_KW_TYPES = 34,                  /* KW_TYPES  */
  YYSYMBOL_KW_WEIGHTS = 35,                /* KW_WEIGHTS  */
  YYSYMBOL_KW_INT = 36,                    /* KW_INT  */
  YYSYMBOL_KW_VARCHAR = 37,                /* KW_VARCHAR  */
  YYSYMBOL_KW_DECIMAL = 38,                /* KW_DECIMAL  */
  YYSYMBOL_KW_LIMIT = 39,                  /* KW_LIMIT  */
  YYSYMBOL_KW_LIMITA = 40,                 /* KW_LIMITA  */
  YYSYMBOL_KW_LIMITB = 41,                 /* KW_LIMITB  */
  YYSYMBOL_KW_LIMITC = 42,                 /* KW_LIMITC  */
  YYSYMBOL_KW_ULIST = 43,                  /* KW_ULIST  */
  YYSYMBOL_WITH = 44,                      /* WITH  */
  YYSYMBOL_45_ = 45,                       /* '+'  */
  YYSYMBOL_46_ = 46,                       /* '-'  */
  YYSYMBOL_47_ = 47,                       /* '%'  */
  YYSYMBOL_48_ = 48,                       /* '*'  */
  YYSYMBOL_49_ = 49,                       /* '/'  */
  YYSYMBOL_50_ = 50,                       /* '^'  */
  YYSYMBOL_51_ = 51,                       /* '['  */
  YYSYMBOL_UMINUS = 52,                    /* UMINUS  */
  YYSYMBOL_TCAST = 53,                     /* TCAST  */
  YYSYMBOL_54_ = 54,                       /* '#'  */
  YYSYMBOL_55_ = 55,                       /* '<'  */
  YYSYMBOL_56_ = 56,                       /* '>'  */
  YYSYMBOL_57_ = 57,                       /* ';'  */
  YYSYMBOL_58_ = 58,                       /* '='  */
  YYSYMBOL_59_ = 59,                       /* '('  */
  YYSYMBOL_60_ = 60,                       /* ')'  */
  YYSYMBOL_61_ = 61,                       /* ':'  */
  YYSYMBOL_62_ = 62,                       /* ','  */
  YYSYMBOL_63_ = 63,                       /* ']'  */
  YYSYMBOL_64_ = 64,                       /* '{'  */
  YYSYMBOL_65_ = 65,                       /* '}'  */
  YYSYMBOL_66_ = 66,                       /* '.'  */
  YYSYMBOL_YYACCEPT = 67,                  /* $accept  */
  YYSYMBOL_workload_spec = 68,             /* workload_spec  */
  YYSYMBOL_statement_list = 69,            /* statement_list  */
  YYSYMBOL_statement = 70,                 /* statement  */
  YYSYMBOL_include_statement = 71,         /* include_statement  */
  YYSYMBOL_dist_statement = 72,            /* dist_statement  */
  YYSYMBOL_dist_argument_list = 73,        /* dist_argument_list  */
  YYSYMBOL_dist_argument = 74,             /* dist_argument  */
  YYSYMBOL_dist_type = 75,                 /* dist_type  */
  YYSYMBOL_dist_type_list = 76,            /* dist_type_list  */
  YYSYMBOL_dist_name_list = 77,            /* dist_name_list  */
  YYSYMBOL_dist_members_list = 78,         /* dist_members_list  */
  YYSYMBOL_dist_member = 79,               /* dist_member  */
  YYSYMBOL_dist_value = 80,                /* dist_value  */
  YYSYMBOL_dist_value_list = 81,           /* dist_value_list  */
  YYSYMBOL_dist_weight_list = 82,          /* dist_weight_list  */
  YYSYMBOL_define_statement = 83,          /* define_statement  */
  YYSYMBOL_comma_expr_list = 84,           /* comma_expr_list  */
  YYSYMBOL_expr = 85,                      /* expr  */
  YYSYMBOL_function_call = 86,             /* function_call  */
  YYSYMBOL_arithmetic_expr = 87,           /* arithmetic_expr  */
  YYSYMBOL_dist_expr_list = 88,            /* dist_expr_list  */
  YYSYMBOL_function_name = 89,             /* function_name  */
  YYSYMBOL_dist_function_name = 90,        /* dist_function_name  */
  YYSYMBOL_keyword_expr = 91,              /* keyword_expr  */
  YYSYMBOL_keyword_value = 92,             /* keyword_value  */
  YYSYMBOL_replacement_list = 93,          /* replacement_list  */
  YYSYMBOL_replacement = 94,               /* replacement  */
  YYSYMBOL_query_statement = 95,           /* query_statement  */
  YYSYMBOL_query_component_list = 96,      /* query_component_list  */
  YYSYMBOL_substitution = 97,              /* substitution  */
  YYSYMBOL_opt_substitution_suffix = 98,   /* opt_substitution_suffix  */
  YYSYMBOL_path = 99                       /* path  */
};
typedef enum yysymbol_kind_t yysymbol_kind_t;




#ifdef short
# undef short
#endif

/* On compilers that do not define __PTRDIFF_MAX__ etc., make sure
   <limits.h> and (if available) <stdint.h> are included
   so that the code can choose integer types of a good width.  */

#ifndef __PTRDIFF_MAX__
# include <limits.h> /* INFRINGES ON USER NAME SPACE */
# if defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stdint.h> /* INFRINGES ON USER NAME SPACE */
#  define YY_STDINT_H
# endif
#endif

/* Narrow types that promote to a signed type and that can represent a
   signed or unsigned integer of at least N bits.  In tables they can
   save space and decrease cache pressure.  Promoting to a signed type
   helps avoid bugs in integer arithmetic.  */

#ifdef __INT_LEAST8_MAX__
typedef __INT_LEAST8_TYPE__ yytype_int8;
#elif defined YY_STDINT_H
typedef int_least8_t yytype_int8;
#else
typedef signed char yytype_int8;
#endif

#ifdef __INT_LEAST16_MAX__
typedef __INT_LEAST16_TYPE__ yytype_int16;
#elif defined YY_STDINT_H
typedef int_least16_t yytype_int16;
#else
typedef short yytype_int16;
#endif

#if defined __UINT_LEAST8_MAX__ && __UINT_LEAST8_MAX__ <= __INT_MAX__
typedef __UINT_LEAST8_TYPE__ yytype_uint8;
#elif (!defined __UINT_LEAST8_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST8_MAX <= INT_MAX)
typedef uint_least8_t yytype_uint8;
#elif !defined __UINT_LEAST8_MAX__ && UCHAR_MAX <= INT_MAX
typedef unsigned char yytype_uint8;
#else
typedef short yytype_uint8;
#endif

#if defined __UINT_LEAST16_MAX__ && __UINT_LEAST16_MAX__ <= __INT_MAX__
typedef __UINT_LEAST16_TYPE__ yytype_uint16;
#elif (!defined __UINT_LEAST16_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST16_MAX <= INT_MAX)
typedef uint_least16_t yytype_uint16;
#elif !defined __UINT_LEAST16_MAX__ && USHRT_MAX <= INT_MAX
typedef unsigned short yytype_uint16;
#else
typedef int yytype_uint16;
#endif

#ifndef YYPTRDIFF_T
# if defined __PTRDIFF_TYPE__ && defined __PTRDIFF_MAX__
#  define YYPTRDIFF_T __PTRDIFF_TYPE__
#  define YYPTRDIFF_MAXIMUM __PTRDIFF_MAX__
# elif defined PTRDIFF_MAX
#  ifndef ptrdiff_t
#   include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  endif
#  define YYPTRDIFF_T ptrdiff_t
#  define YYPTRDIFF_MAXIMUM PTRDIFF_MAX
# else
#  define YYPTRDIFF_T long
#  define YYPTRDIFF_MAXIMUM LONG_MAX
# endif
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned
# endif
#endif

#define YYSIZE_MAXIMUM                                  \
  YY_CAST (YYPTRDIFF_T,                                 \
           (YYPTRDIFF_MAXIMUM < YY_CAST (YYSIZE_T, -1)  \
            ? YYPTRDIFF_MAXIMUM                         \
            : YY_CAST (YYSIZE_T, -1)))

#define YYSIZEOF(X) YY_CAST (YYPTRDIFF_T, sizeof (X))


/* Stored state numbers (used for stacks). */
typedef yytype_uint8 yy_state_t;

/* State numbers in computations.  */
typedef int yy_state_fast_t;

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(Msgid) dgettext ("bison-runtime", Msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(Msgid) Msgid
# endif
#endif


#ifndef YY_ATTRIBUTE_PURE
# if defined __GNUC__ && 2 < __GNUC__ + (96 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_PURE __attribute__ ((__pure__))
# else
#  define YY_ATTRIBUTE_PURE
# endif
#endif

#ifndef YY_ATTRIBUTE_UNUSED
# if defined __GNUC__ && 2 < __GNUC__ + (7 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
# else
#  define YY_ATTRIBUTE_UNUSED
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YYUSE(E) ((void) (E))
#else
# define YYUSE(E) /* empty */
#endif

#if defined __GNUC__ && ! defined __ICC && 407 <= __GNUC__ * 100 + __GNUC_MINOR__
/* Suppress an incorrect diagnostic about yylval being uninitialized.  */
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                            \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")              \
    _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"")
# define YY_IGNORE_MAYBE_UNINITIALIZED_END      \
    _Pragma ("GCC diagnostic pop")
#else
# define YY_INITIAL_VALUE(Value) Value
#endif
#ifndef YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_END
#endif
#ifndef YY_INITIAL_VALUE
# define YY_INITIAL_VALUE(Value) /* Nothing. */
#endif

#if defined __cplusplus && defined __GNUC__ && ! defined __ICC && 6 <= __GNUC__
# define YY_IGNORE_USELESS_CAST_BEGIN                          \
    _Pragma ("GCC diagnostic push")                            \
    _Pragma ("GCC diagnostic ignored \"-Wuseless-cast\"")
# define YY_IGNORE_USELESS_CAST_END            \
    _Pragma ("GCC diagnostic pop")
#endif
#ifndef YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_END
#endif


#define YY_ASSERT(E) ((void) (0 && (E)))

#if !defined yyoverflow

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined EXIT_SUCCESS
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
      /* Use EXIT_SUCCESS as a witness for stdlib.h.  */
#     ifndef EXIT_SUCCESS
#      define EXIT_SUCCESS 0
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's 'empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined EXIT_SUCCESS \
       && ! ((defined YYMALLOC || defined malloc) \
             && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef EXIT_SUCCESS
#    define EXIT_SUCCESS 0
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined EXIT_SUCCESS
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined EXIT_SUCCESS
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* !defined yyoverflow */

#if (! defined yyoverflow \
     && (! defined __cplusplus \
         || (defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yy_state_t yyss_alloc;
  YYSTYPE yyvs_alloc;
};

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (YYSIZEOF (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (YYSIZEOF (yy_state_t) + YYSIZEOF (YYSTYPE)) \
      + YYSTACK_GAP_MAXIMUM)

# define YYCOPY_NEEDED 1

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack_alloc, Stack)                           \
    do                                                                  \
      {                                                                 \
        YYPTRDIFF_T yynewbytes;                                         \
        YYCOPY (&yyptr->Stack_alloc, Stack, yysize);                    \
        Stack = &yyptr->Stack_alloc;                                    \
        yynewbytes = yystacksize * YYSIZEOF (*Stack) + YYSTACK_GAP_MAXIMUM; \
        yyptr += yynewbytes / YYSIZEOF (*yyptr);                        \
      }                                                                 \
    while (0)

#endif

#if defined YYCOPY_NEEDED && YYCOPY_NEEDED
/* Copy COUNT objects from SRC to DST.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(Dst, Src, Count) \
      __builtin_memcpy (Dst, Src, YY_CAST (YYSIZE_T, (Count)) * sizeof (*(Src)))
#  else
#   define YYCOPY(Dst, Src, Count)              \
      do                                        \
        {                                       \
          YYPTRDIFF_T yyi;                      \
          for (yyi = 0; yyi < (Count); yyi++)   \
            (Dst)[yyi] = (Src)[yyi];            \
        }                                       \
      while (0)
#  endif
# endif
#endif /* !YYCOPY_NEEDED */

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  27
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   236

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  67
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  33
/* YYNRULES -- Number of rules.  */
#define YYNRULES  98
/* YYNSTATES -- Number of states.  */
#define YYNSTATES  202

/* YYMAXUTOK -- Last valid token kind.  */
#define YYMAXUTOK   301


/* YYTRANSLATE(TOKEN-NUM) -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex, with out-of-bounds checking.  */
#define YYTRANSLATE(YYX)                                \
  (0 <= (YYX) && (YYX) <= YYMAXUTOK                     \
   ? YY_CAST (yysymbol_kind_t, yytranslate[YYX])        \
   : YYSYMBOL_YYUNDEF)

/* YYTRANSLATE[TOKEN-NUM] -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex.  */
static const yytype_int8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,    54,     2,    47,     2,     2,
      59,    60,    48,    45,    62,    46,    66,    49,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,    61,    57,
      55,    58,    56,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,    51,     2,    63,    50,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    64,     2,    65,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
      52,    53
};

#if YYDEBUG
  /* YYRLINE[YYN] -- Source line where rule number YYN was defined.  */
static const yytype_int16 yyrline[] =
{
       0,   159,   159,   167,   168,   181,   182,   183,   184,   192,
     197,   208,   211,   212,   215,   216,   217,   220,   221,   222,
     225,   226,   227,   230,   231,   234,   235,   238,   241,   242,
     243,   246,   247,   250,   251,   258,   264,   276,   281,   288,
     292,   296,   297,   302,   306,   310,   314,   318,   321,   325,
     329,   333,   346,   363,   367,   371,   375,   381,   385,   389,
     393,   398,   403,   408,   413,   420,   421,   424,   425,   426,
     429,   430,   431,   434,   435,   436,   437,   440,   445,   452,
     465,   473,   474,   480,   481,   488,   496,   504,   511,   518,
     525,   532,   539,   546,   555,   556,   557,   558,   566
};
#endif

/** Accessing symbol of state STATE.  */
#define YY_ACCESSING_SYMBOL(State) YY_CAST (yysymbol_kind_t, yystos[State])

#if YYDEBUG || 0
/* The user-facing name of the symbol whose (internal) number is
   YYSYMBOL.  No bounds checking.  */
static const char *yysymbol_name (yysymbol_kind_t yysymbol) YY_ATTRIBUTE_UNUSED;

/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "\"end of file\"", "error", "\"invalid token\"", "TOK_INT",
  "TOK_LITERAL", "TOK_PATH", "TOK_DECIMAL", "TOK_ID", "TOK_SQL",
  "KW_DEFINE", "KW_RANDOM", "KW_UNIFORM", "KW_RANGE", "KW_DATE",
  "KW_INCLUDE", "KW_TEXT", "KW_DIST", "KW_LIST", "KW_ROWCOUNT", "KW_BEGIN",
  "KW_END", "KW_SALES", "KW_RETURNS", "KW_DISTMEMBER", "KW_DISTWEIGHT",
  "KW_QUERY", "KW_STREAM", "KW_TEMPLATE", "KW_SEED", "KW_SCALE",
  "KW_SCALE_STEP", "KW_SET", "KW_ADD", "KW_NAMES", "KW_TYPES",
  "KW_WEIGHTS", "KW_INT", "KW_VARCHAR", "KW_DECIMAL", "KW_LIMIT",
  "KW_LIMITA", "KW_LIMITB", "KW_LIMITC", "KW_ULIST", "WITH", "'+'", "'-'",
  "'%'", "'*'", "'/'", "'^'", "'['", "UMINUS", "TCAST", "'#'", "'<'",
  "'>'", "';'", "'='", "'('", "')'", "':'", "','", "']'", "'{'", "'}'",
  "'.'", "$accept", "workload_spec", "statement_list", "statement",
  "include_statement", "dist_statement", "dist_argument_list",
  "dist_argument", "dist_type", "dist_type_list", "dist_name_list",
  "dist_members_list", "dist_member", "dist_value", "dist_value_list",
  "dist_weight_list", "define_statement", "comma_expr_list", "expr",
  "function_call", "arithmetic_expr", "dist_expr_list", "function_name",
  "dist_function_name", "keyword_expr", "keyword_value",
  "replacement_list", "replacement", "query_statement",
  "query_component_list", "substitution", "opt_substitution_suffix",
  "path", YY_NULLPTR
};

static const char *
yysymbol_name (yysymbol_kind_t yysymbol)
{
  return yytname[yysymbol];
}
#endif

#ifdef YYPRINT
/* YYTOKNUM[NUM] -- (External) token number corresponding to the
   (internal) symbol number NUM (which must be that of a token).  */
static const yytype_int16 yytoknum[] =
{
       0,   256,   257,   258,   259,   260,   261,   262,   263,   264,
     265,   266,   267,   268,   269,   270,   271,   272,   273,   274,
     275,   276,   277,   278,   279,   280,   281,   282,   283,   284,
     285,   286,   287,   288,   289,   290,   291,   292,   293,   294,
     295,   296,   297,   298,   299,    43,    45,    37,    42,    47,
      94,    91,   300,   301,    35,    60,    62,    59,    61,    40,
      41,    58,    44,    93,   123,   125,    46
};
#endif

#define YYPACT_NINF (-169)

#define yypact_value_is_default(Yyn) \
  ((Yyn) == YYPACT_NINF)

#define YYTABLE_NINF (-35)

#define yytable_value_is_error(Yyn) \
  0

  /* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
     STATE-NUM.  */
static const yytype_int16 yypact[] =
{
     110,  -169,    13,    10,   105,    -6,    34,   110,  -169,  -169,
    -169,  -169,  -169,    -3,  -169,   -11,    -7,    -2,    -1,    16,
      32,    35,    38,    39,    44,    61,     3,  -169,  -169,  -169,
    -169,  -169,    93,   131,    94,    76,    26,    80,  -169,  -169,
    -169,  -169,  -169,  -169,  -169,  -169,   146,  -169,  -169,  -169,
    -169,  -169,    96,  -169,    99,  -169,   107,   124,  -169,  -169,
    -169,  -169,  -169,   130,   132,   113,   123,  -169,  -169,   133,
     134,  -169,   116,   -23,   -10,  -169,   104,  -169,  -169,  -169,
    -169,   118,    93,   135,    93,   174,   136,    93,     1,  -169,
    -169,  -169,  -169,   127,    93,    93,    93,    93,  -169,    93,
      20,  -169,   137,   139,   140,   141,  -169,   162,  -169,  -169,
    -169,   103,   197,    75,  -169,   108,   115,  -169,   114,    76,
     142,  -169,    -9,    -9,  -169,  -169,   119,    11,  -169,    11,
     122,   143,   144,   201,    58,  -169,   203,   145,  -169,   135,
     205,  -169,   206,   208,   149,  -169,  -169,    93,  -169,    70,
     202,    91,   156,  -169,  -169,  -169,  -169,   -36,   154,   212,
    -169,   157,   158,   159,  -169,    11,  -169,    11,  -169,    28,
    -169,  -169,  -169,  -169,   125,  -169,    66,    58,  -169,   151,
    -169,  -169,  -169,   202,   213,   164,    91,   163,   160,   165,
    -169,  -169,   126,  -169,  -169,  -169,    72,   167,   169,   168,
    -169,  -169
};

  /* YYDEFACT[STATE-NUM] -- Default reduction number in state STATE-NUM.
     Performed when YYTABLE does not specify something else to do.  Zero
     means the default is an error.  */
static const yytype_int8 yydefact[] =
{
       0,    82,     0,     0,     0,     0,     0,     2,     3,     5,
       8,     6,     7,     0,    81,     0,     0,     0,    94,     0,
       0,     0,     0,     0,     0,     0,     0,     1,     4,    84,
      80,    83,     0,     0,     0,    94,     0,     0,    87,    88,
      89,    90,    91,    92,    93,    98,     0,     9,    40,    39,
      66,    70,     0,    65,     0,    67,     0,     0,    71,    72,
      68,    69,    46,     0,     0,     0,     0,    41,    47,     0,
       0,    42,     0,     0,     0,    12,     0,    97,    95,    96,
      85,     0,     0,     0,     0,     0,     0,     0,    94,    73,
      75,    74,    76,     0,     0,     0,     0,     0,    35,     0,
       0,    36,     0,     0,     0,     0,    13,    11,    25,    86,
      10,     0,     0,     0,    77,     0,     0,    53,     0,    94,
       0,    43,    57,    58,    59,    60,     0,    37,    62,    61,
       0,     0,     0,     0,     0,    26,     0,     0,    50,     0,
       0,    51,     0,     0,     0,    45,    48,     0,    49,     0,
       0,    20,     0,    28,    29,    30,    31,     0,     0,     0,
      78,     0,     0,     0,    44,    38,    64,    63,    23,     0,
      17,    18,    19,    21,     0,    14,     0,     0,    56,     0,
      55,    52,    54,     0,     0,     0,     0,    28,     0,     0,
      32,    79,     0,    24,    15,    22,     0,     0,     0,    28,
      27,    16
};

  /* YYPGOTO[NTERM-NUM].  */
static const yytype_int16 yypgoto[] =
{
    -169,  -169,  -169,   220,  -169,  -169,  -169,   155,    45,  -169,
      47,  -169,   128,  -168,    56,  -169,  -169,  -169,   -81,  -169,
    -169,  -169,  -169,  -169,  -169,  -169,  -169,    95,  -169,  -169,
     223,   -35,   187
};

  /* YYDEFGOTO[NTERM-NUM].  */
static const yytype_int16 yydefgoto[] =
{
      -1,     6,     7,     8,     9,    10,    74,    75,   173,   174,
     169,   107,   108,   156,   157,   189,    11,   126,    66,    67,
      68,   130,    69,    70,    71,    93,   113,   114,    12,    13,
      14,    37,    47
};

  /* YYTABLE[YYPACT[STATE-NUM]] -- What to do in state STATE-NUM.  If
     positive, shift that token.  If negative, reduce the rule whose
     number is the opposite.  If YYTABLE_NINF, syntax error.  */
static const yytype_int16 yytable[] =
{
      76,   111,    35,   115,   119,    29,   118,    45,    26,   190,
     102,   103,   104,   122,   123,   124,   125,    17,   127,   129,
      15,    73,   105,    48,    49,   176,   177,   128,   190,    77,
      50,    51,    52,    53,    27,    54,    55,    56,    57,    96,
      97,    58,    59,    60,    61,    78,    79,    32,     4,    62,
      63,    33,    16,   120,    30,    34,    94,    95,    46,    96,
      97,   153,   154,    64,   155,    36,   165,    36,   167,   187,
     154,    65,   155,    48,    49,   199,   154,   166,   155,    38,
      50,    51,    52,    53,   144,    54,    55,    56,    57,   183,
     184,    58,    59,    60,    61,    39,    48,    49,    40,    62,
      63,    41,    42,    50,    51,    52,    53,    43,    54,    55,
      56,    57,    18,    64,    58,    59,    60,    61,     1,     2,
      88,    65,    62,    63,    44,    73,     3,   170,   171,   172,
      19,    20,    21,    22,    72,   138,    64,   139,    89,    90,
      91,    92,    36,    80,    65,    23,    24,    25,    94,    95,
      45,    96,    97,    94,    95,    82,    96,    97,    83,    94,
      95,     4,    96,    97,     5,   136,    84,   109,    94,    95,
     140,    96,    97,   101,   110,   141,   143,   142,   116,   146,
      98,   147,   148,    85,   149,   185,   198,   186,   184,    86,
     121,    87,    99,   100,   105,   131,   117,   132,   133,   112,
     134,   137,   150,   151,   152,   145,   158,   159,   161,   168,
     162,   163,   164,   175,   178,   179,   191,   180,   181,   182,
     193,   194,   196,   -33,   200,   197,   201,    28,   -34,   106,
     192,   195,   188,    81,   160,   135,    31
};

static const yytype_uint8 yycheck[] =
{
      35,    82,     3,    84,     3,     8,    87,     4,    14,   177,
      33,    34,    35,    94,    95,    96,    97,     7,    99,   100,
       7,    31,    32,     3,     4,    61,    62,     7,   196,     3,
      10,    11,    12,    13,     0,    15,    16,    17,    18,    48,
      49,    21,    22,    23,    24,    19,    20,    58,    51,    29,
      30,    58,    39,    88,    57,    57,    45,    46,    55,    48,
      49,     3,     4,    43,     6,    66,   147,    66,   149,     3,
       4,    51,     6,     3,     4,     3,     4,     7,     6,    63,
      10,    11,    12,    13,   119,    15,    16,    17,    18,    61,
      62,    21,    22,    23,    24,    63,     3,     4,    63,    29,
      30,    63,    63,    10,    11,    12,    13,    63,    15,    16,
      17,    18,     7,    43,    21,    22,    23,    24,     8,     9,
       7,    51,    29,    30,    63,    31,    16,    36,    37,    38,
      25,    26,    27,    28,     3,    60,    43,    62,    25,    26,
      27,    28,    66,    63,    51,    40,    41,    42,    45,    46,
       4,    48,    49,    45,    46,    59,    48,    49,    59,    45,
      46,    51,    48,    49,    54,    62,    59,    63,    45,    46,
      62,    48,    49,    57,    56,    60,    62,    62,     4,    60,
      57,    62,    60,    59,    62,    60,    60,    62,    62,    59,
      63,    59,    59,    59,    32,    58,    60,    58,    58,    64,
      59,     4,    59,    59,     3,    63,     3,    62,     3,     7,
       4,     3,    63,    57,    60,     3,    65,    60,    60,    60,
       7,    57,    62,    60,    57,    60,    57,     7,    60,    74,
     183,   186,   176,    46,   139,   107,    13
};

  /* YYSTOS[STATE-NUM] -- The (internal number of the) accessing
     symbol of state STATE-NUM.  */
static const yytype_int8 yystos[] =
{
       0,     8,     9,    16,    51,    54,    68,    69,    70,    71,
      72,    83,    95,    96,    97,     7,    39,     7,     7,    25,
      26,    27,    28,    40,    41,    42,    14,     0,    70,     8,
      57,    97,    58,    58,    57,     3,    66,    98,    63,    63,
      63,    63,    63,    63,    63,     4,    55,    99,     3,     4,
      10,    11,    12,    13,    15,    16,    17,    18,    21,    22,
      23,    24,    29,    30,    43,    51,    85,    86,    87,    89,
      90,    91,     3,    31,    73,    74,    98,     3,    19,    20,
      63,    99,    59,    59,    59,    59,    59,    59,     7,    25,
      26,    27,    28,    92,    45,    46,    48,    49,    57,    59,
      59,    57,    33,    34,    35,    32,    74,    78,    79,    63,
      56,    85,    64,    93,    94,    85,     4,    60,    85,     3,
      98,    63,    85,    85,    85,    85,    84,    85,     7,    85,
      88,    58,    58,    58,    59,    79,    62,     4,    60,    62,
      62,    60,    62,    62,    98,    63,    60,    62,    60,    62,
      59,    59,     3,     3,     4,     6,    80,    81,     3,    62,
      94,     3,     4,     3,    63,    85,     7,    85,     7,    77,
      36,    37,    38,    75,    76,    57,    61,    62,    60,     3,
      60,    60,    60,    61,    62,    60,    62,     3,    81,    82,
      80,    65,    77,     7,    57,    75,    62,    60,    60,     3,
      57,    57
};

  /* YYR1[YYN] -- Symbol number of symbol that rule YYN derives.  */
static const yytype_int8 yyr1[] =
{
       0,    67,    68,    69,    69,    70,    70,    70,    70,    71,
      71,    72,    73,    73,    74,    74,    74,    75,    75,    75,
      76,    76,    76,    77,    77,    78,    78,    79,    80,    80,
      80,    81,    81,    82,    82,    83,    83,    84,    84,    85,
      85,    85,    85,    85,    85,    85,    85,    85,    86,    86,
      86,    86,    86,    86,    86,    86,    86,    87,    87,    87,
      87,    88,    88,    88,    88,    89,    89,    90,    90,    90,
      91,    91,    91,    92,    92,    92,    92,    93,    93,    94,
      95,    96,    96,    96,    96,    97,    97,    97,    97,    97,
      97,    97,    97,    97,    98,    98,    98,    98,    99
};

  /* YYR2[YYN] -- Number of symbols on the right hand side of rule YYN.  */
static const yytype_int8 yyr2[] =
{
       0,     2,     1,     1,     2,     1,     1,     1,     1,     3,
       5,     5,     1,     2,     5,     7,     9,     1,     1,     1,
       0,     1,     3,     1,     3,     1,     2,     7,     1,     1,
       1,     1,     3,     1,     3,     5,     5,     1,     3,     1,
       1,     1,     1,     3,     5,     4,     1,     1,     4,     4,
       4,     4,     6,     3,     6,     6,     6,     3,     3,     3,
       3,     1,     1,     3,     3,     1,     1,     1,     1,     1,
       1,     1,     1,     1,     1,     1,     1,     1,     3,     5,
       2,     1,     1,     2,     2,     4,     5,     3,     3,     3,
       3,     3,     3,     3,     0,     2,     2,     2,     1
};


enum { YYENOMEM = -2 };

#define yyerrok         (yyerrstatus = 0)
#define yyclearin       (yychar = YYEMPTY)

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab


#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)                                    \
  do                                                              \
    if (yychar == YYEMPTY)                                        \
      {                                                           \
        yychar = (Token);                                         \
        yylval = (Value);                                         \
        YYPOPSTACK (yylen);                                       \
        yystate = *yyssp;                                         \
        goto yybackup;                                            \
      }                                                           \
    else                                                          \
      {                                                           \
        yyerror (YY_("syntax error: cannot back up")); \
        YYERROR;                                                  \
      }                                                           \
  while (0)

/* Backward compatibility with an undocumented macro.
   Use YYerror or YYUNDEF. */
#define YYERRCODE YYUNDEF


/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)                        \
do {                                            \
  if (yydebug)                                  \
    YYFPRINTF Args;                             \
} while (0)

/* This macro is provided for backward compatibility. */
# ifndef YY_LOCATION_PRINT
#  define YY_LOCATION_PRINT(File, Loc) ((void) 0)
# endif


# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)                    \
do {                                                                      \
  if (yydebug)                                                            \
    {                                                                     \
      YYFPRINTF (stderr, "%s ", Title);                                   \
      yy_symbol_print (stderr,                                            \
                  Kind, Value); \
      YYFPRINTF (stderr, "\n");                                           \
    }                                                                     \
} while (0)


/*-----------------------------------.
| Print this symbol's value on YYO.  |
`-----------------------------------*/

static void
yy_symbol_value_print (FILE *yyo,
                       yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  FILE *yyoutput = yyo;
  YYUSE (yyoutput);
  if (!yyvaluep)
    return;
# ifdef YYPRINT
  if (yykind < YYNTOKENS)
    YYPRINT (yyo, yytoknum[yykind], *yyvaluep);
# endif
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YYUSE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/*---------------------------.
| Print this symbol on YYO.  |
`---------------------------*/

static void
yy_symbol_print (FILE *yyo,
                 yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  YYFPRINTF (yyo, "%s %s (",
             yykind < YYNTOKENS ? "token" : "nterm", yysymbol_name (yykind));

  yy_symbol_value_print (yyo, yykind, yyvaluep);
  YYFPRINTF (yyo, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

static void
yy_stack_print (yy_state_t *yybottom, yy_state_t *yytop)
{
  YYFPRINTF (stderr, "Stack now");
  for (; yybottom <= yytop; yybottom++)
    {
      int yybot = *yybottom;
      YYFPRINTF (stderr, " %d", yybot);
    }
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)                            \
do {                                                            \
  if (yydebug)                                                  \
    yy_stack_print ((Bottom), (Top));                           \
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

static void
yy_reduce_print (yy_state_t *yyssp, YYSTYPE *yyvsp,
                 int yyrule)
{
  int yylno = yyrline[yyrule];
  int yynrhs = yyr2[yyrule];
  int yyi;
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %d):\n",
             yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      YYFPRINTF (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr,
                       YY_ACCESSING_SYMBOL (+yyssp[yyi + 1 - yynrhs]),
                       &yyvsp[(yyi + 1) - (yynrhs)]);
      YYFPRINTF (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)          \
do {                                    \
  if (yydebug)                          \
    yy_reduce_print (yyssp, yyvsp, Rule); \
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args) ((void) 0)
# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif






/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

static void
yydestruct (const char *yymsg,
            yysymbol_kind_t yykind, YYSTYPE *yyvaluep)
{
  YYUSE (yyvaluep);
  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yykind, yyvaluep, yylocationp);

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YYUSE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/* Lookahead token kind.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;
/* Number of syntax errors so far.  */
int yynerrs;




/*----------.
| yyparse.  |
`----------*/

int
yyparse (void)
{
    yy_state_fast_t yystate = 0;
    /* Number of tokens to shift before error messages enabled.  */
    int yyerrstatus = 0;

    /* Refer to the stacks through separate pointers, to allow yyoverflow
       to reallocate them elsewhere.  */

    /* Their size.  */
    YYPTRDIFF_T yystacksize = YYINITDEPTH;

    /* The state stack: array, bottom, top.  */
    yy_state_t yyssa[YYINITDEPTH];
    yy_state_t *yyss = yyssa;
    yy_state_t *yyssp = yyss;

    /* The semantic value stack: array, bottom, top.  */
    YYSTYPE yyvsa[YYINITDEPTH];
    YYSTYPE *yyvs = yyvsa;
    YYSTYPE *yyvsp = yyvs;

  int yyn;
  /* The return value of yyparse.  */
  int yyresult;
  /* Lookahead symbol kind.  */
  yysymbol_kind_t yytoken = YYSYMBOL_YYEMPTY;
  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N))

  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yychar = YYEMPTY; /* Cause a token to be read.  */
  goto yysetstate;


/*------------------------------------------------------------.
| yynewstate -- push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;


/*--------------------------------------------------------------------.
| yysetstate -- set current state (the top of the stack) to yystate.  |
`--------------------------------------------------------------------*/
yysetstate:
  YYDPRINTF ((stderr, "Entering state %d\n", yystate));
  YY_ASSERT (0 <= yystate && yystate < YYNSTATES);
  YY_IGNORE_USELESS_CAST_BEGIN
  *yyssp = YY_CAST (yy_state_t, yystate);
  YY_IGNORE_USELESS_CAST_END
  YY_STACK_PRINT (yyss, yyssp);

  if (yyss + yystacksize - 1 <= yyssp)
#if !defined yyoverflow && !defined YYSTACK_RELOCATE
    goto yyexhaustedlab;
#else
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYPTRDIFF_T yysize = yyssp - yyss + 1;

# if defined yyoverflow
      {
        /* Give user a chance to reallocate the stack.  Use copies of
           these so that the &'s don't force the real ones into
           memory.  */
        yy_state_t *yyss1 = yyss;
        YYSTYPE *yyvs1 = yyvs;

        /* Each stack pointer address is followed by the size of the
           data in use in that stack, in bytes.  This used to be a
           conditional around just the two extra args, but that might
           be undefined if yyoverflow is a macro.  */
        yyoverflow (YY_("memory exhausted"),
                    &yyss1, yysize * YYSIZEOF (*yyssp),
                    &yyvs1, yysize * YYSIZEOF (*yyvsp),
                    &yystacksize);
        yyss = yyss1;
        yyvs = yyvs1;
      }
# else /* defined YYSTACK_RELOCATE */
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
        goto yyexhaustedlab;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
        yystacksize = YYMAXDEPTH;

      {
        yy_state_t *yyss1 = yyss;
        union yyalloc *yyptr =
          YY_CAST (union yyalloc *,
                   YYSTACK_ALLOC (YY_CAST (YYSIZE_T, YYSTACK_BYTES (yystacksize))));
        if (! yyptr)
          goto yyexhaustedlab;
        YYSTACK_RELOCATE (yyss_alloc, yyss);
        YYSTACK_RELOCATE (yyvs_alloc, yyvs);
#  undef YYSTACK_RELOCATE
        if (yyss1 != yyssa)
          YYSTACK_FREE (yyss1);
      }
# endif

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;

      YY_IGNORE_USELESS_CAST_BEGIN
      YYDPRINTF ((stderr, "Stack size increased to %ld\n",
                  YY_CAST (long, yystacksize)));
      YY_IGNORE_USELESS_CAST_END

      if (yyss + yystacksize - 1 <= yyssp)
        YYABORT;
    }
#endif /* !defined yyoverflow && !defined YYSTACK_RELOCATE */

  if (yystate == YYFINAL)
    YYACCEPT;

  goto yybackup;


/*-----------.
| yybackup.  |
`-----------*/
yybackup:
  /* Do appropriate processing given the current state.  Read a
     lookahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to lookahead token.  */
  yyn = yypact[yystate];
  if (yypact_value_is_default (yyn))
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either empty, or end-of-input, or a valid lookahead.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token\n"));
      yychar = yylex ();
    }

  if (yychar <= YYEOF)
    {
      yychar = YYEOF;
      yytoken = YYSYMBOL_YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else if (yychar == YYerror)
    {
      /* The scanner already issued an error message, process directly
         to error recovery.  But do not keep the error token as
         lookahead, it is too special and may lead us to an endless
         loop in error recovery. */
      yychar = YYUNDEF;
      yytoken = YYSYMBOL_YYerror;
      goto yyerrlab1;
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yytable_value_is_error (yyn))
        goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the lookahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);
  yystate = yyn;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END

  /* Discard the shifted token.  */
  yychar = YYEMPTY;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     '$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
  case 2: /* workload_spec: statement_list  */
#line 160 "./tpcds-gen/target/tools/qgen.y"
                                                {
							AddQuerySegment(pCurrentQuery, "\n");
							AddQuerySubstitution(pCurrentQuery, "_END", 0, 0);
							AddQuerySegment(pCurrentQuery, "\n");
						}
#line 1540 "y.tab.c"
    break;

  case 4: /* statement_list: statement_list statement  */
#line 169 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if (is_set("DEBUG"))
							{
								if ((yyvsp[0].intval) != KW_DEFINE)
								{
									printf("STATUS: parsed %s statement at line %d\n", 
										((yyvsp[0].intval) == TOK_SQL)?"SQL":KeywordText((yyvsp[0].intval)), pCurrentFile->line_number);
								}
							}
						}
#line 1555 "y.tab.c"
    break;

  case 5: /* statement: include_statement  */
#line 181 "./tpcds-gen/target/tools/qgen.y"
                                        {(yyval.intval) = KW_INCLUDE; }
#line 1561 "y.tab.c"
    break;

  case 6: /* statement: define_statement  */
#line 182 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_DEFINE; }
#line 1567 "y.tab.c"
    break;

  case 7: /* statement: query_statement  */
#line 183 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = TOK_SQL; }
#line 1573 "y.tab.c"
    break;

  case 8: /* statement: dist_statement  */
#line 184 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_DIST; }
#line 1579 "y.tab.c"
    break;

  case 9: /* include_statement: '#' KW_INCLUDE path  */
#line 193 "./tpcds-gen/target/tools/qgen.y"
                                        {
					if (include_file((yyvsp[0].strval), pCurrentQuery) < 0)
						yyerror("File include failed");
					}
#line 1588 "y.tab.c"
    break;

  case 10: /* include_statement: '#' KW_INCLUDE '<' path '>'  */
#line 198 "./tpcds-gen/target/tools/qgen.y"
                                        {
					yywarn("System include not supported; using relative pathing");
					if (include_file((yyvsp[-1].strval), pCurrentQuery) < 0)
						yyerror("File include failed");
					}
#line 1598 "y.tab.c"
    break;

  case 35: /* define_statement: KW_DEFINE TOK_ID '=' expr ';'  */
#line 259 "./tpcds-gen/target/tools/qgen.y"
                                                {
						defineSubstitution(pCurrentQuery, (yyvsp[-3].strval), (yyvsp[-1].exprval));
						if (is_set("DEBUG"))
							printf("STATUS: DEFINED %s\n", (yyvsp[-3].strval));
						}
#line 1608 "y.tab.c"
    break;

  case 36: /* define_statement: KW_DEFINE KW_LIMIT '=' TOK_INT ';'  */
#line 265 "./tpcds-gen/target/tools/qgen.y"
                                                {
						pSub = findSubstitution(pCurrentQuery, "_LIMIT", 0);
						sprintf(tmpstr, "%d", (yyvsp[-1].intval));
						ResetBuffer(pSub->pAssignment->Value.pBuf);
						AddBuffer(pSub->pAssignment->Value.pBuf, tmpstr);
						if (is_set("DEBUG"))
							printf("STATUS: SET LIMIT\n");
						}
#line 1621 "y.tab.c"
    break;

  case 37: /* comma_expr_list: expr  */
#line 277 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.list) = makeList(L_FL_TAIL, NULL);
						addList((yyval.list), (yyvsp[0].exprval));
						}
#line 1630 "y.tab.c"
    break;

  case 38: /* comma_expr_list: comma_expr_list ',' expr  */
#line 282 "./tpcds-gen/target/tools/qgen.y"
                                                {
						addList((yyvsp[-2].list), (yyvsp[0].exprval));
						(yyval.list) = (yyvsp[-2].list);
						}
#line 1639 "y.tab.c"
    break;

  case 39: /* expr: TOK_LITERAL  */
#line 289 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeStringConstant((yyvsp[0].strval));
						}
#line 1647 "y.tab.c"
    break;

  case 40: /* expr: TOK_INT  */
#line 293 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeIntConstant((yyvsp[0].intval));
						}
#line 1655 "y.tab.c"
    break;

  case 42: /* expr: keyword_expr  */
#line 298 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeIntConstant((yyvsp[0].intval));
						(yyval.exprval)->nFlags |= EXPR_FL_KEYWORD;
						}
#line 1664 "y.tab.c"
    break;

  case 43: /* expr: '[' keyword_value ']'  */
#line 303 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = getKeywordValue((yyvsp[-1].intval));
						}
#line 1672 "y.tab.c"
    break;

  case 44: /* expr: '[' TOK_ID TOK_INT opt_substitution_suffix ']'  */
#line 307 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeVariableReference((yyvsp[-3].strval), (yyvsp[-2].intval));
						}
#line 1680 "y.tab.c"
    break;

  case 45: /* expr: '[' TOK_ID opt_substitution_suffix ']'  */
#line 311 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeVariableReference((yyvsp[-2].strval), (yyvsp[-1].intval));
						}
#line 1688 "y.tab.c"
    break;

  case 46: /* expr: KW_SCALE  */
#line 315 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeIntConstant(get_int("SCALE"));
						}
#line 1696 "y.tab.c"
    break;

  case 48: /* function_call: function_name '(' comma_expr_list ')'  */
#line 322 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeFunctionCall((yyvsp[-3].intval), (yyvsp[-1].list));
						}
#line 1704 "y.tab.c"
    break;

  case 49: /* function_call: dist_function_name '(' dist_expr_list ')'  */
#line 326 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeFunctionCall((yyvsp[-3].intval), (yyvsp[-1].list));
						}
#line 1712 "y.tab.c"
    break;

  case 50: /* function_call: KW_TEXT '(' replacement_list ')'  */
#line 330 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeFunctionCall(KW_TEXT, (yyvsp[-1].list));
						}
#line 1720 "y.tab.c"
    break;

  case 51: /* function_call: KW_ROWCOUNT '(' TOK_LITERAL ')'  */
#line 334 "./tpcds-gen/target/tools/qgen.y"
                                                {
						i = GetTableNumber((yyvsp[-1].strval));
						if (i == -1)
						{
							i = distsize((yyvsp[-1].strval));
							if (i == -1)
								ReportError(QERR_BAD_NAME, (yyvsp[-1].strval), 1);
						}
						else
							i = getIDCount(i);
						(yyval.exprval) = MakeIntConstant(i);
						}
#line 1737 "y.tab.c"
    break;

  case 52: /* function_call: KW_ROWCOUNT '(' TOK_LITERAL ',' TOK_LITERAL ')'  */
#line 347 "./tpcds-gen/target/tools/qgen.y"
                                                {
						/* TODO: Need to convert this to DSS_HUGE */
						i = GetTableNumber((yyvsp[-3].strval));
						if (i == -1)
						{
							i = distsize((yyvsp[-3].strval));
							if (i == -1)
								ReportError(QERR_BAD_NAME, (yyvsp[-3].strval), 1);
						}
						j = GetTableNumber((yyvsp[-1].strval));
						if (i == -1)
							ReportError(QERR_BAD_NAME, (yyvsp[-1].strval), 1);
						i = (int)getIDCount(i);
						j = (int)getIDCount(j);
						(yyval.exprval) = MakeIntConstant((i>j)?j:i);
						}
#line 1758 "y.tab.c"
    break;

  case 53: /* function_call: KW_SCALE_STEP '(' ')'  */
#line 364 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeIntConstant(getScaleSlot(get_int("SCALE")) + 1);
						}
#line 1766 "y.tab.c"
    break;

  case 54: /* function_call: KW_ULIST '(' expr ',' TOK_INT ')'  */
#line 368 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeListExpr(KW_ULIST, (yyvsp[-3].exprval), (yyvsp[-1].intval));
						}
#line 1774 "y.tab.c"
    break;

  case 55: /* function_call: KW_LIST '(' expr ',' TOK_INT ')'  */
#line 372 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeListExpr(KW_LIST, (yyvsp[-3].exprval), (yyvsp[-1].intval));
						}
#line 1782 "y.tab.c"
    break;

  case 56: /* function_call: KW_RANGE '(' expr ',' TOK_INT ')'  */
#line 376 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeListExpr(KW_RANGE, (yyvsp[-3].exprval), (yyvsp[-1].intval));
						}
#line 1790 "y.tab.c"
    break;

  case 57: /* arithmetic_expr: expr '+' expr  */
#line 382 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = makeArithmeticExpr(OP_ADD, (yyvsp[-2].exprval), (yyvsp[0].exprval));
						}
#line 1798 "y.tab.c"
    break;

  case 58: /* arithmetic_expr: expr '-' expr  */
#line 386 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = makeArithmeticExpr(OP_SUBTRACT, (yyvsp[-2].exprval), (yyvsp[0].exprval));
						}
#line 1806 "y.tab.c"
    break;

  case 59: /* arithmetic_expr: expr '*' expr  */
#line 390 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = makeArithmeticExpr(OP_MULTIPLY, (yyvsp[-2].exprval), (yyvsp[0].exprval));
						}
#line 1814 "y.tab.c"
    break;

  case 60: /* arithmetic_expr: expr '/' expr  */
#line 394 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = makeArithmeticExpr(OP_DIVIDE, (yyvsp[-2].exprval), (yyvsp[0].exprval));
						}
#line 1822 "y.tab.c"
    break;

  case 61: /* dist_expr_list: expr  */
#line 399 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.list) = makeList(L_FL_TAIL, NULL);
						addList((yyval.list), (yyvsp[0].exprval));
						}
#line 1831 "y.tab.c"
    break;

  case 62: /* dist_expr_list: TOK_ID  */
#line 404 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.list) = makeList(L_FL_TAIL, NULL);
						addList((yyval.list), MakeStringConstant((yyvsp[0].strval)));
						}
#line 1840 "y.tab.c"
    break;

  case 63: /* dist_expr_list: dist_expr_list ',' expr  */
#line 409 "./tpcds-gen/target/tools/qgen.y"
                                                {
						addList((yyvsp[-2].list), (yyvsp[0].exprval));
						(yyval.list) = (yyvsp[-2].list);
						}
#line 1849 "y.tab.c"
    break;

  case 64: /* dist_expr_list: dist_expr_list ',' TOK_ID  */
#line 414 "./tpcds-gen/target/tools/qgen.y"
                                                {
						addList((yyvsp[-2].list), MakeStringConstant((yyvsp[0].strval)));
						(yyval.list) = (yyvsp[-2].list);
						}
#line 1858 "y.tab.c"
    break;

  case 65: /* function_name: KW_DATE  */
#line 420 "./tpcds-gen/target/tools/qgen.y"
                                        {(yyval.intval) = KW_DATE;}
#line 1864 "y.tab.c"
    break;

  case 66: /* function_name: KW_RANDOM  */
#line 421 "./tpcds-gen/target/tools/qgen.y"
                                                                {(yyval.intval) = KW_RANDOM;}
#line 1870 "y.tab.c"
    break;

  case 67: /* dist_function_name: KW_DIST  */
#line 424 "./tpcds-gen/target/tools/qgen.y"
                                        {(yyval.intval) = KW_DIST;}
#line 1876 "y.tab.c"
    break;

  case 68: /* dist_function_name: KW_DISTMEMBER  */
#line 425 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_DISTMEMBER;}
#line 1882 "y.tab.c"
    break;

  case 69: /* dist_function_name: KW_DISTWEIGHT  */
#line 426 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_DISTWEIGHT;}
#line 1888 "y.tab.c"
    break;

  case 70: /* keyword_expr: KW_UNIFORM  */
#line 429 "./tpcds-gen/target/tools/qgen.y"
                                        {(yyval.intval) = KW_UNIFORM;}
#line 1894 "y.tab.c"
    break;

  case 71: /* keyword_expr: KW_SALES  */
#line 430 "./tpcds-gen/target/tools/qgen.y"
                                                                        {(yyval.intval) = KW_SALES;}
#line 1900 "y.tab.c"
    break;

  case 72: /* keyword_expr: KW_RETURNS  */
#line 431 "./tpcds-gen/target/tools/qgen.y"
                                                                        {(yyval.intval) = KW_RETURNS;}
#line 1906 "y.tab.c"
    break;

  case 73: /* keyword_value: KW_QUERY  */
#line 434 "./tpcds-gen/target/tools/qgen.y"
                                                                {(yyval.intval) = KW_QUERY;}
#line 1912 "y.tab.c"
    break;

  case 74: /* keyword_value: KW_TEMPLATE  */
#line 435 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_TEMPLATE;}
#line 1918 "y.tab.c"
    break;

  case 75: /* keyword_value: KW_STREAM  */
#line 436 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_STREAM;}
#line 1924 "y.tab.c"
    break;

  case 76: /* keyword_value: KW_SEED  */
#line 437 "./tpcds-gen/target/tools/qgen.y"
                                                {(yyval.intval) = KW_SEED;}
#line 1930 "y.tab.c"
    break;

  case 77: /* replacement_list: replacement  */
#line 441 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.list) = makeList(L_FL_TAIL, NULL);
						addList((yyval.list), (yyvsp[0].exprval));
						}
#line 1939 "y.tab.c"
    break;

  case 78: /* replacement_list: replacement_list ',' replacement  */
#line 446 "./tpcds-gen/target/tools/qgen.y"
                                                {
						addList((yyval.list), (yyvsp[0].exprval));
						(yyval.list) = (yyvsp[-2].list);
						}
#line 1948 "y.tab.c"
    break;

  case 79: /* replacement: '{' TOK_LITERAL ',' TOK_INT '}'  */
#line 453 "./tpcds-gen/target/tools/qgen.y"
                                                {
						(yyval.exprval) = MakeReplacement((yyvsp[-3].strval), (yyvsp[-1].intval));
						}
#line 1956 "y.tab.c"
    break;

  case 80: /* query_statement: query_component_list ';'  */
#line 466 "./tpcds-gen/target/tools/qgen.y"
                                                        {
							pSegment = getTail(pCurrentQuery->SegmentList);
							pSegment->flags |= QS_EOS;
							}
#line 1965 "y.tab.c"
    break;

  case 82: /* query_component_list: TOK_SQL  */
#line 475 "./tpcds-gen/target/tools/qgen.y"
                                                        {
							if ((nRetCode = AddQuerySegment(pCurrentQuery, (yyvsp[0].strval))) != 0)
								yyerror("SQL parse failed");
							}
#line 1974 "y.tab.c"
    break;

  case 84: /* query_component_list: query_component_list TOK_SQL  */
#line 482 "./tpcds-gen/target/tools/qgen.y"
                                                        {
							if ((nRetCode = AddQuerySegment(pCurrentQuery, (yyvsp[0].strval))) != 0)
								yyerror("SQL parse failed");
							}
#line 1983 "y.tab.c"
    break;

  case 85: /* substitution: '[' TOK_ID opt_substitution_suffix ']'  */
#line 489 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, (yyvsp[-2].strval), 0, (yyvsp[-1].intval))) < 0)
								{
								sprintf(tmpstr, "Substitution match failed on %s", (yyvsp[-2].strval));
								yyerror(tmpstr);
								}
						}
#line 1995 "y.tab.c"
    break;

  case 86: /* substitution: '[' TOK_ID TOK_INT opt_substitution_suffix ']'  */
#line 497 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, (yyvsp[-3].strval), (yyvsp[-2].intval), (yyvsp[-1].intval))) < 0)
								{
								sprintf(tmpstr, "Substitution match failed on %s", (yyvsp[-3].strval));
								yyerror(tmpstr);
								}
						}
#line 2007 "y.tab.c"
    break;

  case 87: /* substitution: '[' KW_QUERY ']'  */
#line 505 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_QUERY", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2018 "y.tab.c"
    break;

  case 88: /* substitution: '[' KW_STREAM ']'  */
#line 512 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_STREAM", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2029 "y.tab.c"
    break;

  case 89: /* substitution: '[' KW_TEMPLATE ']'  */
#line 519 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_TEMPLATE", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2040 "y.tab.c"
    break;

  case 90: /* substitution: '[' KW_SEED ']'  */
#line 526 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_SEED", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2051 "y.tab.c"
    break;

  case 91: /* substitution: '[' KW_LIMITA ']'  */
#line 533 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_LIMITA", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2062 "y.tab.c"
    break;

  case 92: /* substitution: '[' KW_LIMITB ']'  */
#line 540 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_LIMITB", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2073 "y.tab.c"
    break;

  case 93: /* substitution: '[' KW_LIMITC ']'  */
#line 547 "./tpcds-gen/target/tools/qgen.y"
                                                {
							if ((nRetCode = AddQuerySubstitution(pCurrentQuery, "_LIMITC", 0, 0)) < 0)
								{
								yyerror("Lookup of predefined constant failed");
								}
						}
#line 2084 "y.tab.c"
    break;

  case 94: /* opt_substitution_suffix: %empty  */
#line 555 "./tpcds-gen/target/tools/qgen.y"
                                                        {(yyval.intval) = 0;}
#line 2090 "y.tab.c"
    break;

  case 95: /* opt_substitution_suffix: '.' KW_BEGIN  */
#line 556 "./tpcds-gen/target/tools/qgen.y"
                                                                        {(yyval.intval) = 0;}
#line 2096 "y.tab.c"
    break;

  case 96: /* opt_substitution_suffix: '.' KW_END  */
#line 557 "./tpcds-gen/target/tools/qgen.y"
                                                                                {(yyval.intval) = 1;}
#line 2102 "y.tab.c"
    break;

  case 97: /* opt_substitution_suffix: '.' TOK_INT  */
#line 558 "./tpcds-gen/target/tools/qgen.y"
                                                                                {(yyval.intval) = (yyvsp[0].intval);}
#line 2108 "y.tab.c"
    break;

  case 98: /* path: TOK_LITERAL  */
#line 566 "./tpcds-gen/target/tools/qgen.y"
                                { (yyval.strval) = (yyvsp[0].strval); }
#line 2114 "y.tab.c"
    break;


#line 2118 "y.tab.c"

      default: break;
    }
  /* User semantic actions sometimes alter yychar, and that requires
     that yytoken be updated with the new translation.  We take the
     approach of translating immediately before every use of yytoken.
     One alternative is translating here after every semantic action,
     but that translation would be missed if the semantic action invokes
     YYABORT, YYACCEPT, or YYERROR immediately after altering yychar or
     if it invokes YYBACKUP.  In the case of YYABORT or YYACCEPT, an
     incorrect destructor might then be invoked immediately.  In the
     case of YYERROR or YYBACKUP, subsequent parser actions might lead
     to an incorrect destructor call or verbose syntax error message
     before the lookahead is translated.  */
  YY_SYMBOL_PRINT ("-> $$ =", YY_CAST (yysymbol_kind_t, yyr1[yyn]), &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;

  *++yyvsp = yyval;

  /* Now 'shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */
  {
    const int yylhs = yyr1[yyn] - YYNTOKENS;
    const int yyi = yypgoto[yylhs] + *yyssp;
    yystate = (0 <= yyi && yyi <= YYLAST && yycheck[yyi] == *yyssp
               ? yytable[yyi]
               : yydefgoto[yylhs]);
  }

  goto yynewstate;


/*--------------------------------------.
| yyerrlab -- here on detecting error.  |
`--------------------------------------*/
yyerrlab:
  /* Make sure we have latest lookahead translation.  See comments at
     user semantic actions for why this is necessary.  */
  yytoken = yychar == YYEMPTY ? YYSYMBOL_YYEMPTY : YYTRANSLATE (yychar);
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
      yyerror (YY_("syntax error"));
    }

  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
         error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* Return failure if at end of input.  */
          if (yychar == YYEOF)
            YYABORT;
        }
      else
        {
          yydestruct ("Error: discarding",
                      yytoken, &yylval);
          yychar = YYEMPTY;
        }
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:
  /* Pacify compilers when the user code never invokes YYERROR and the
     label yyerrorlab therefore never appears in user code.  */
  if (0)
    YYERROR;

  /* Do not reclaim the symbols of the rule whose action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;      /* Each real token shifted decrements this.  */

  /* Pop stack until we find a state that shifts the error token.  */
  for (;;)
    {
      yyn = yypact[yystate];
      if (!yypact_value_is_default (yyn))
        {
          yyn += YYSYMBOL_YYerror;
          if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYSYMBOL_YYerror)
            {
              yyn = yytable[yyn];
              if (0 < yyn)
                break;
            }
        }

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
        YYABORT;


      yydestruct ("Error: popping",
                  YY_ACCESSING_SYMBOL (yystate), yyvsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END


  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", YY_ACCESSING_SYMBOL (yyn), yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturn;


/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturn;


#if !defined yyoverflow
/*-------------------------------------------------.
| yyexhaustedlab -- memory exhaustion comes here.  |
`-------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  goto yyreturn;
#endif


/*-------------------------------------------------------.
| yyreturn -- parsing is finished, clean up and return.  |
`-------------------------------------------------------*/
yyreturn:
  if (yychar != YYEMPTY)
    {
      /* Make sure we have latest lookahead translation.  See comments at
         user semantic actions for why this is necessary.  */
      yytoken = YYTRANSLATE (yychar);
      yydestruct ("Cleanup: discarding lookahead",
                  yytoken, &yylval);
    }
  /* Do not reclaim the symbols of the rule whose action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
                  YY_ACCESSING_SYMBOL (+*yyssp), yyvsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif

  return yyresult;
}

#line 570 "./tpcds-gen/target/tools/qgen.y"



