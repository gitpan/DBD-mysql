/* Hej, Emacs, this is -*- C -*- mode!

   $Id: mysql.xs 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $

   Copyright (c) 1997 Jochen Wiedmann

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "dbdimp.h"
#include "../nodbd/constants.h"


/* --- Variables --- */


DBISTATE_DECLARE;


MODULE = DBD::mysql	PACKAGE = DBD::mysql

INCLUDE: mysql.xsi

MODULE = DBD::mysql	PACKAGE = DBD::mysql

double
constant(name, arg)
    char* name
    char* arg
  CODE:
    RETVAL = mymsql_constant(name, arg);
  OUTPUT:
    RETVAL

MODULE = DBD::mysql	PACKAGE = DBD::mysql::dr

void
_ListDBs(drh, host)
    SV *        drh
    char *	host
  PPCODE:
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
        result_t res;
        row_t cur;
        res = MyListDbs(sock);
        if (!res) {
            do_error(drh, MyErrno(sock, JW_ERR_LIST_DB), MyError(sock));
        } else {
            EXTEND(sp, MyNumRows(res));
	    while ((cur = MyFetchRow(res))) {
	        PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	    }
	    MyFreeResult(res);
        }
        MyClose(sock);
    }


SV*
_admin_internal(drh,dbh,command,dbname=NULL,host=NULL,user=NULL,password=NULL)
    SV* drh
    SV* dbh
    char* command
    char* dbname
    char* host
    char* user
    char* password
  PPCODE:
    {
        dbh_t sock;
	MYSQL mysql;
	int result;

	/*
	 *  Connect to the database, if required.
	 */
	if (SvOK(dbh)) {
	    D_imp_dbh(dbh);
	    sock = imp_dbh->svsock;
	} else {
	    sock = &mysql;
	    if (!dbd_db_connect(sock,host,user,password)) {
	        do_error(drh, MyErrno(sock, JW_ERR_CONNECT), MyError(sock));
		XPUSHs(&sv_no);
	    }
       }
 
       if (strEQ(command, "shutdown")) {
	   result = MyShutdown(sock);
       } else if (strEQ(command, "reload")) {
	   result = MyReload(sock);
       } else if (strEQ(command, "createdb")) {
	   result = MyCreateDb(sock, dbname);
       } else if (strEQ(command, "dropdb")) {
          result = MyDropDb(sock, dbname);
       } else {
	  croak("Unknown command: %s", command);
       }
       if (result) {
	   do_error(SvOK(dbh) ? dbh : drh, MyErrno(sock, JW_ERR_LIST_DB),
		    MyError(sock));
	   result = 0;
       } else {
	   result = 1;
       }
       if (SvOK(dbh)) {
	   MyClose(sock);
       }
       XPUSHs(boolSV(result));
   }


MODULE = DBD::mysql    PACKAGE = DBD::mysql::db




int
_InsertID(dbh)
    SV *	dbh
  CODE:
    D_imp_dbh(dbh);
    int id;
    MYSQL *sock = (MYSQL*) imp_dbh->svsock;
    EXTEND( sp, 1 );
    RETVAL = mysql_insert_id(sock);
  OUTPUT:
    RETVAL


void
_ListDBs(dbh)
    SV*	dbh
  PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    row_t cur;
    res = MyListDbs(imp_dbh->svsock);
    if (!res  &&  (!MyReconnect(imp_dbh->svsock, dbh)
		   ||  !(res = MyListDbs(imp_dbh->svsock)))) {
        do_error(dbh, MyErrno(imp_dbh->svsock, JW_ERR_LIST_DB),
		 MyError(imp_dbh->svsock));
    } else {
        EXTEND(sp, MyNumRows(res));
	while ((cur = MyFetchRow(res))) {
	    PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	}
	MyFreeResult(res);
    }
    MyClose(imp_dbh->svsock);


void
_ListTables(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    row_t cur;
    res = MyListTables(imp_dbh->svsock);
    if (!res  &&  (!MyReconnect(imp_dbh->svsock, dbh)
		   ||  !(res = MyListTables(imp_dbh->svsock)))) {
        do_error(dbh, MyErrno(imp_dbh->svsock, JW_ERR_LIST_TABLES),
		 MyError(imp_dbh->svsock));
    } else {
        while ((cur = MyFetchRow(res))) {
            XPUSHs(sv_2mortal((SV*)newSVpv( cur[0], strlen(cur[0]))));
        }
        MyFreeResult(res);
    }
 

void
do(dbh, statement, attr=Nullsv, ...)
    SV *        dbh
    SV *	statement
    SV *        attr
  PROTOTYPE: $$;$@      
  CODE:
{
    D_imp_dbh(dbh);
    struct imp_sth_ph_st* params = NULL;
    int numParams = 0;
    result_t cda = NULL;
    int retval;

    if (items > 3) {
       	/*  Handle binding supplied values to placeholders	     */
	/*  Assume user has passed the correct number of parameters  */
	int i;
	numParams = items-3;
	Newz(0, params, sizeof(*params)*numParams, struct imp_sth_ph_st);
	for (i = 0;  i < numParams;  i++) {
	    params[i].value = ST(i+3);
	    params[i].type = SQL_VARCHAR;
	}
    }
    retval = dbd_st_internal_execute(dbh, statement, attr, numParams,
				     params, &cda, imp_dbh->svsock, 0);
    Safefree(params);
    if (cda) {
	MyFreeResult(cda);
    }
    /* remember that dbd_st_execute must return <= -2 for error	*/
    if (retval == 0)		/* ok with no rows affected	*/
	XST_mPV(0, "0E0");	/* (true but zero)		*/
    else if (retval < -1)	/* -1 == unknown number of rows	*/
	XST_mUNDEF(0);		/* <= -2 means error   		*/
    else
	XST_mIV(0, retval);	/* typically 1, rowcount or -1	*/
}


SV*
ping(dbh)
    SV* dbh;
  PROTOTYPE: $
  CODE:
    {
        int result;
	D_imp_dbh(dbh);
	char* ptr = mysql_stat(imp_dbh->svsock);
	result = (mysql_errno(imp_dbh->svsock) == 0);
	if (!result  &&  MyReconnect(imp_dbh->svsock, dbh)) {
	    ptr = mysql_stat(imp_dbh->svsock);
	    result = (mysql_errno(imp_dbh->svsock) == 0);
	}
	RETVAL = boolSV(result);
    }
  OUTPUT:
    RETVAL



void
_SelectDB(dbh, dbname)
    SV *	dbh
    char *	dbname
  PPCODE:
    croak("_SelectDB is removed from this module; use DBI->connect instead.");


SV*
quote(dbh, str)
    SV* dbh
    SV* str
  PROTOTYPE: $$
  PPCODE:
    {
        SV* result;
        char* ptr;
	char* sptr;
	int len;

        if (!SvOK(str)) {
	    XSRETURN_UNDEF;
	}

	ptr = SvPV(str, len);
	result = sv_2mortal(newSV(len*2+3));
	sptr = SvPVX(result);

	*sptr++ = '\'';
	while (len--) {
	    switch (*ptr) {
	      case '\'':
		*sptr++ = '\\';
		*sptr++ = '\'';
		break;
	      case '\\':
		*sptr++ = '\\';
		*sptr++ = '\\';
		break;
	      case '\n':
		*sptr++ = '\\';
		*sptr++ = 'n';
		break;
	      case '\r':
		*sptr++ = '\\';
		*sptr++ = 'r';
		break;
	      case '\0':
		*sptr++ = '\\';
		*sptr++ = '0';
		break;
	      default:
		*sptr++ = *ptr;
		break;
	    }
	    ++ptr;
	}
	*sptr++ = '\'';
	SvPOK_on(result);
	SvCUR_set(result, sptr - SvPVX(result));
	*sptr++ = '\0';  /*  Never hurts NUL terminating a Perl string ... */
	EXTEND(sp, 1);
	PUSHs(result);
    }
