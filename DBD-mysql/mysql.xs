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
            do_error(drh, JW_ERR_LIST_DB, MyError(sock));
        } else {
            EXTEND(sp, MyNumRows(res));
	    while ((cur = MyFetchRow(res))) {
	        PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	    }
	    MyFreeResult(res);
        }
        MyClose(sock);
    }


void
_CreateDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
        if (!MyCreateDb(sock,dbname)) {
            XPUSHs(sv_2mortal((SV*)newSVpv("OK", 2)));
        } else {
            do_error(drh, JW_ERR_CREATE_DB, MyError(sock));
        }
        MyClose(sock);
    } else {
        do_error(drh, JW_ERR_CONNECT, MyError(sock));
    }


void
_DropDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
        if (MyDropDb(sock,dbname) != -1) {
            XPUSHs(sv_2mortal((SV*)newSVpv("OK", 2)));
        } else {
            do_error(drh, JW_ERR_DROP_DB, MyError(sock));
        }
        MyClose(sock);
    } else {
        do_error(drh, JW_ERR_CONNECT, MyError(sock));
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
    if (!res) {
        do_error(dbh, JW_ERR_LIST_DB, MyError(imp_dbh->svsock));
    } else {
        EXTEND(sp, MyNumRows(res));
	while ((cur = MyFetchRow(res))) {
	    PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	}
	MyFreeResult(res);
    }
    MyClose(imp_dbh->svsock);

void
_SelectDB(dbh, dbname)
    SV *	dbh
    char *	dbname
    PPCODE:
    D_imp_dbh(dbh);
    if (imp_dbh->svsock->net.fd != -1) {
        if (MySelectDb(imp_dbh->svsock, dbname) == -1) {
            do_error(dbh, JW_ERR_SELECT_DB, 
			   MyError(imp_dbh->svsock));
        }
    }


void
_ListTables(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    row_t cur;
    res = MyListTables(imp_dbh->svsock);
    if (!res) {
        do_error(dbh, JW_ERR_LIST_TABLES, MyError(imp_dbh->svsock));
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
				     params, &cda, imp_dbh->svsock);
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


MODULE = DBD::mysql    PACKAGE = DBD::mysql::st

void
_NumRows(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    EXTEND( sp, 1 );
    PUSHs( sv_2mortal((SV*)newSViv(imp_sth->row_num)));

# end of mysql.xs
