/*
 *  DBD::mysql - DBI driver for the mysql database
 *
 *  Copyright (c) 1997  Jochen Wiedmann
 *
 *  Based on DBD::Oracle; DBD::Oracle is
 *
 *  Copyright (c) 1994,1995  Tim Bunce
 *
 *  You may distribute this under the terms of either the GNU General Public
 *  License or the Artistic License, as specified in the Perl README file,
 *  with the exception that it cannot be placed on a CD-ROM or similar media
 *  for commercial distribution without the prior approval of the author.
 *
 *  Author:  Jochen Wiedmann
 *           Am Eisteich 9
 *           72555 Metzingen
 *           Germany
 *
 *           Email: joe@ispsoft.de
 *           Fax: +49 7123 / 14892
 *
 *
 *  $Id: dbdimp.c 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
 */


#include "dbdimp.h"

#include "bindparam.h"


DBISTATE_DECLARE;

#if defined(DBD_MYSQL)  &&  defined(mysql_errno)
#define DO_ERROR(h, c, s) do_error(h, (int) mysql_errno(s), mysql_error(s))
#else
#define DO_ERROR(h, c, s) do_error(h, c, MyError(s))
#endif



/***************************************************************************
 *
 *  Name:    dbd_init
 *
 *  Purpose: Called when the driver is installed by DBI
 *
 *  Input:   dbistate - pointer to the DBIS variable, used for some
 *               DBI internal things
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_init(dbistate_t* dbistate) {
    DBIS = dbistate;
}


/***************************************************************************
 *
 *  Name:    do_error, do_warn
 *
 *  Purpose: Called to associate an error code and an error message
 *           to some handle
 *
 *  Input:   h - the handle in error condition
 *           rc - the error code
 *           what - the error message
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void do_error(SV* h, int rc, char* what) {
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    sv_setiv(DBIc_ERR(imp_xxh), (IV)rc);	/* set err early	*/
    sv_setpv(errstr, what);
    DBIh_EVENT2(h, ERROR_event, DBIc_ERR(imp_xxh), errstr);
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "%s error %d recorded: %s\n",
		what, rc, SvPV(errstr,na));
}
void do_warn(SV* h, int rc, char* what) {
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    sv_setiv(DBIc_ERR(imp_xxh), (IV)rc);	/* set err early	*/
    sv_setpv(errstr, what);
    DBIh_EVENT2(h, WARN_event, DBIc_ERR(imp_xxh), errstr);
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "%s warning %d recorded: %s\n",
		what, rc, SvPV(errstr,na));
    warn("%s", what);
}


/***************************************************************************
 *
 *  Name:    dbd_db_login
 *
 *  Purpose: Called for connecting to a database and logging in.
 *
 *  Input:   dbh - database handle being initialized
 *           imp_dbh - drivers private database handle data
 *           dbname - the database we want to log into; may be like
 *               "dbname:host" or "dbname:host:port"
 *           user - user name to connect as
 *           password - passwort to connect with
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/
int dbd_db_login(SV* dbh, imp_dbh_t* imp_dbh, char* dbname, char* user,
		 char* password) {
    char* copy = NULL;
    char* host = NULL;
    char* ptr;

    if (dbis->debug >= 2)
        fprintf(DBILOGFP, "imp_dbh->connect: dsn = %s, uid = %s, pwd = %s\n",
	       dbname ? dbname : "NULL",
	       user ? user : "NULL",
	       password ? password : "NULL");

    /*
     *  dbname may be "db:host" or "db;host"
     */
    if ((ptr = strchr(dbname, ':'))  ||  (ptr = strchr(dbname, ';'))) {
        int len = ptr-dbname;
	copy = (char*) malloc(strlen(dbname)+1);
	strcpy(copy, dbname);
	dbname = copy;
	host = dbname + len;
	*host++ = '\0';
    }

    /*
     *  Try to connect
     */
    if (!dbd_db_connect(&imp_dbh->svsock, host, user, password)) {
	DO_ERROR(dbh, JW_ERR_CONNECT, imp_dbh->svsock);
	if (copy) free(copy);
	return FALSE;
    }

    /*
     *  Connected, now try to login
     */
    if (MySelectDb(imp_dbh->svsock, dbname)) {
        if (copy) free(copy);
	DO_ERROR(dbh, JW_ERR_SELECT_DB, imp_dbh->svsock);
	MyClose(imp_dbh->svsock);
	return FALSE;
    }

    if (copy) free(copy);

    /*
     *  Tell DBI, that dbh->disconnect should be called for this handle
     */
    DBIc_on(imp_dbh, DBIcf_ACTIVE);

    /*
     *  Tell DBI, that dbh->destroy should be called for this handle
     */
    DBIc_on(imp_dbh, DBIcf_IMPSET);

    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_commit
 *           dbd_db_rollback
 *
 *  Purpose: You guess what they should do. Unfortunately mysql doesn't
 *           support transactions so far. (Most important lack of
 *           feature, Monty! :-) So we stub commit to return OK
 *           and rollback to return ERROR in any case.
 *
 *  Input:   dbh - database handle being commited or rolled back
 *           imp_dbh - drivers private database handle data
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/

int dbd_db_commit(SV* dbh, imp_dbh_t* imp_dbh) {
    do_warn(dbh, JW_ERR_NOT_IMPLEMENTED,
	    "Commmit ineffective while AutoCommit is on");
    return TRUE;
}

int dbd_db_rollback(SV* dbh, imp_dbh_t* imp_dbh) {
    do_error(dbh, JW_ERR_NOT_IMPLEMENTED,
	    "Rollback ineffective while AutoCommit is on");
    return FALSE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_disconnect
 *
 *  Purpose: Disconnect a database handle from its database
 *
 *  Input:   dbh - database handle being disconnected
 *           imp_dbh - drivers private database handle data
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/

int dbd_db_disconnect(SV* dbh, imp_dbh_t* imp_dbh) {
    /* We assume that disconnect will always work       */
    /* since most errors imply already disconnected.    */
    DBIc_off(imp_dbh, DBIcf_ACTIVE);
    if (dbis->debug >= 2)
        fprintf(DBILOGFP, "imp_dbh->svsock: %lx\n", (long) &imp_dbh->svsock);
    MyClose(imp_dbh->svsock );

    /* We don't free imp_dbh since a reference still exists    */
    /* The DESTROY method is the only one to 'free' memory.    */
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_discon_all
 *
 *  Purpose: Disconnect all database handles at shutdown time
 *
 *  Input:   dbh - database handle being disconnected
 *           imp_dbh - drivers private database handle data
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/

int dbd_discon_all (SV *drh, imp_drh_t *imp_drh) {
    /* The disconnect_all concept is flawed and needs more work */
    if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
	sv_setiv(DBIc_ERR(imp_drh), (IV)1);
	sv_setpv(DBIc_ERRSTR(imp_drh),
		(char*)"disconnect_all not implemented");
	DBIh_EVENT2(drh, ERROR_event,
		    DBIc_ERR(imp_drh), DBIc_ERRSTR(imp_drh));
	return FALSE;
    }
    if (perl_destruct_level)
	perl_destruct_level = 0;
    return FALSE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_destroy
 *
 *  Purpose: Our part of the dbh destructor
 *
 *  Input:   dbh - database handle being destroyed
 *           imp_dbh - drivers private database handle data
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_db_destroy(SV* dbh, imp_dbh_t* imp_dbh) {

    /*
     *  Being on the safe side never hurts ...
     */
    if (DBIc_ACTIVE(imp_dbh))
        dbd_db_disconnect(dbh, imp_dbh);

    /*
     *  Tell DBI, that dbh->destroy must no longer be called
     */
    DBIc_off(imp_dbh, DBIcf_IMPSET);
}


/***************************************************************************
 *
 *  Name:    dbd_db_STORE_attrib
 *
 *  Purpose: Function for storing dbh attributes; we currently support
 *           just nothing. :-)
 *
 *  Input:   dbh - database handle being modified
 *           imp_dbh - drivers private database handle data
 *           keysv - the attribute name
 *           valuesv - the attribute value
 *
 *  Returns: TRUE for success, FALSE otherwise
 *
 **************************************************************************/

int dbd_db_STORE_attrib(SV* dbh, imp_dbh_t* imp_dbh, SV* keysv, SV* valuesv) {
    STRLEN kl;
    char *key = SvPV(keysv, kl);
    SV *cachesv = Nullsv;
    int cacheit = FALSE;

    if (kl==10 && strEQ(key, "AutoCommit")){
        /*
	 *  We do support neither transactions nor "AutoCommit".
	 *  But we stub it. :-)
	 */
        if (!SvTRUE(valuesv)) {
	    do_error(dbh, JW_ERR_NOT_IMPLEMENTED,
			   "Transactions not supported by database");
	    croak("Transactions not supported by database");
	}
    } else {
        return FALSE;
    }

    if (cacheit) /* cache value for later DBI 'quick' fetch? */
        hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_FETCH_attrib
 *
 *  Purpose: Function for fetching dbh attributes; we currently support
 *           just nothing. :-)
 *
 *  Input:   dbh - database handle being queried
 *           imp_dbh - drivers private database handle data
 *           keysv - the attribute name
 *
 *  Returns: An SV*, if sucessfull; NULL otherwise
 *
 *  Notes:   Do not forget to call sv_2mortal in the former case!
 *
 **************************************************************************/

SV* dbd_db_FETCH_attrib(SV* dbh, imp_dbh_t* imp_dbh, SV* keysv) {
    STRLEN kl;
    char *key = SvPV(keysv, kl);

    if (kl==10 && strEQ(key, "AutoCommit")){
        /*
	 *  We do support neither transactions nor "AutoCommit".
	 *  But we stub it. :-)
	 */
        return &sv_yes;
    }
        
    if (kl == 5  &&  strEQ(key, "errno")) {
#if defined(DBD_MYSQL)  &&  defined(mysql_errno)
	return sv_2mortal(newSViv((IV)mysql_errno(imp_dbh->svsock)));
#else
	return sv_2mortal(newSViv(-1));
#endif
    } else if (kl == 6  &&  strEQ(key, "errmsg")) {
	char* msg = MyError(imp_dbh->svsock);
	return sv_2mortal(newSVpv(msg, strlen(msg)));
    }
    return Nullsv;
}


/***************************************************************************
 *
 *  Name:    dbd_st_prepare
 *
 *  Purpose: Called for preparing an SQL statement; our part of the
 *           statement handle constructor
 *
 *  Input:   sth - statement handle being initialized
 *           imp_sth - drivers private statement handle data
 *           statement - pointer to string with SQL statement
 *           attribs - statement attributes, currently not in use
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_prepare(SV* sth, imp_sth_t* imp_sth, char* statement, SV* attribs) {
    int i;


    /*
     *  Count the number of parameters
     */
    DBIc_NUM_PARAMS(imp_sth) = CountParam(statement);

    /*
     *  Initialize our data
     */
    imp_sth->done_desc = 0;
    imp_sth->cda = NULL;
    imp_sth->currow = 0;
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	imp_sth->av_attr[i] = Nullav;
    }


    /*
     *  Allocate memory for parameters
     */
    imp_sth->params = AllocParam(DBIc_NUM_PARAMS(imp_sth));
    DBIc_IMPSET_on(imp_sth);

    return 1;
}


/***************************************************************************
 *
 *  Name:    dbd_st_internal_execute
 *
 *  Purpose: Internal version for executing a statement, called both from
 *           within the "do" and the "execute" method.
 *
 *  Inputs:  h - object handle, for storing error messages
 *           statement - query being executed
 *           attribs - statement attributes, currently ignored
 *           numParams - number of parameters being bound
 *           params - parameter array
 *           cdaPtr - where to store results, if any
 *           svsock - socket connected to the database
 *
 **************************************************************************/

int dbd_st_internal_execute(SV* h, SV* statement, SV* attribs, int numParams,
			    imp_sth_ph_t* params, result_t* cdaPtr,
			    dbh_t svsock, int use_mysql_use_result) {
    STRLEN slen;
    char* sbuf = SvPV(statement, slen);
    char* salloc = ParseParam(sbuf, &slen, params, numParams);

    if (salloc) {
        sbuf = salloc;
        if (dbis->debug >= 2) {
	    fprintf(DBILOGFP, "      Binding parameters: %s\n", sbuf);
	}
    }

    if (slen >= 10
	&&  tolower(sbuf[0]) == 'l'
	&&  tolower(sbuf[1]) == 'i'
	&&  tolower(sbuf[2]) == 's'
	&&  tolower(sbuf[3]) == 't'
	&&  tolower(sbuf[4]) == 'f'
	&&  tolower(sbuf[5]) == 'i'
	&&  tolower(sbuf[6]) == 'e'
	&&  tolower(sbuf[7]) == 'l'
	&&  tolower(sbuf[8]) == 'd'
	&&  tolower(sbuf[9]) == 's') {
	char* table;

	while (slen && !isspace(*sbuf)) { --slen;  ++sbuf; }
	while (slen && isspace(*sbuf)) { --slen;  ++sbuf; }

	if (!slen) {
	    do_error(h, JW_ERR_QUERY, "Missing table name");
	    return -2;
	}

	if (!(table = malloc(slen+1))) {
	    do_error(h, JW_ERR_MEM, "Out of memory");
	    return -2;
	}
	strncpy(table, sbuf, slen);
	table[slen] = '\0';
	*cdaPtr = MyListFields(svsock, sbuf);
	free(table);

	if (!(*cdaPtr)) {
	    DO_ERROR(h, JW_ERR_LIST_FIELDS, svsock);
	    return -2;
	}

	return 0;
    } else {
	if (MyQuery(svsock, sbuf, slen) == -1) {
	    Safefree(salloc);
	    DO_ERROR(h, JW_ERR_QUERY, svsock);
	    return -2;
	}
	Safefree(salloc);

	/** Store the result from the Query */
	if (!(*cdaPtr = MyStoreResult(svsock))) {
	    return -1;
	}

	return MyNumRows((*cdaPtr));
    }
}


/***************************************************************************
 *
 *  Name:    dbd_st_execute
 *
 *  Purpose: Called for preparing an SQL statement; our part of the
 *           statement handle constructor
 *
 *  Input:   sth - statement handle being initialized
 *           imp_sth - drivers private statement handle data
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_execute(SV* sth, imp_sth_t* imp_sth) {
    D_imp_dbh_from_sth;
    SV** statement;
    int i;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    -> dbd_st_execute for %08lx\n", (u_long) sth);
    }

    if (!SvROK(sth)  ||  SvTYPE(SvRV(sth)) != SVt_PVHV) {
        croak("Expected hash array");
    }

    /*
     *  Free cached array attributes
     */
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	if (imp_sth->av_attr[i]) {
	    SvREFCNT_dec(imp_sth->av_attr[i]);
	}
	imp_sth->av_attr[i] = Nullav;
    }

    statement = hv_fetch((HV*) SvRV(sth), "Statement", 9, FALSE);
    if ((imp_sth->row_num =
	     dbd_st_internal_execute(sth, *statement, NULL,
				     DBIc_NUM_PARAMS(imp_sth),
				     imp_sth->params,
				     &imp_sth->cda,
				     imp_dbh->svsock,
				     imp_sth->use_mysql_use_result))
	!= -2) {
	if (!imp_sth->cda) {
	} else {
	    /** Store the result in the current statement handle */
	    DBIc_ACTIVE_on(imp_sth);
	    DBIc_NUM_FIELDS(imp_sth) = MyNumFields(imp_sth->cda);
	    imp_sth->done_desc = 0;
	}
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    <- dbd_st_execute %d rows\n",
		imp_sth->row_num);
    }

    return imp_sth->row_num;
}


/***************************************************************************
 *
 *  Name:    dbd_describe
 *
 *  Purpose: Called from within the fetch method to describe the result
 *
 *  Input:   sth - statement handle being initialized
 *           imp_sth - our part of the statement handle, there's no
 *               need for supplying both; Tim just doesn't remove it
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_describe(SV* sth, imp_sth_t* imp_sth) {
    imp_sth->done_desc = 1;
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_st_fetch
 *
 *  Purpose: Called for fetching a result row
 *
 *  Input:   sth - statement handle being initialized
 *           imp_sth - drivers private statement handle data
 *
 *  Returns: array of columns; the array is allocated by DBI via
 *           DBIS->get_fbav(imp_sth), even the values of the array
 *           are prepared, we just need to modify them appropriately
 *
 **************************************************************************/

AV* dbd_st_fetch(SV* sth, imp_sth_t* imp_sth) {
    int num_fields;
    int ChopBlanks;
    int i;
    AV *av;
    row_t cols;

    ChopBlanks = DBIc_is(imp_sth, DBIcf_ChopBlanks);
    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    -> dbd_st_fetch for %08lx, chopblanks %d\n",
		(u_long) sth, ChopBlanks);
    }

    if (!imp_sth->cda) {
        return Nullav;
    }

    imp_sth->currow++;
    if (!(cols = MyFetchRow(imp_sth->cda))) {
	return Nullav;
    }
    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    for(i=0; i < num_fields; ++i) {
        char* col = cols[i];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/

	if (col) {
	    STRLEN len = strlen(col);
	    if (ChopBlanks) {
		while(len && isspace(col[len-1])) {
		    --len;
		}
	    }

	    if (dbis->debug >= 2) {
		fprintf(DBILOGFP, "      Storing row %d (%s) in %08lx\n",
			i, col, (u_long) sv);
	    }
	    sv_setpvn(sv, col, len);
	} else {
	    (void) SvOK_off(sv);  /*  Field is NULL, return undef  */
	}
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    <- dbd_st_fetch, %d cols\n", num_fields);
    }
    return av;
}


/***************************************************************************
 *
 *  Name:    dbd_st_finish
 *
 *  Purpose: Called for freeing a mysql result
 *
 *  Input:   sth - statement handle being finished
 *           imp_sth - drivers private statement handle data
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error() will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_finish(SV* sth, imp_sth_t* imp_sth) {
    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY.                  */
    /* The application may re execute it.                       */
    if (imp_sth && imp_sth->cda) {
        MyFreeResult(imp_sth->cda);
	imp_sth->cda = NULL;
    }
    DBIc_ACTIVE_off(imp_sth);
    return 1;
}


/***************************************************************************
 *
 *  Name:    dbd_st_destroy
 *
 *  Purpose: Our part of the statement handles destructor
 *
 *  Input:   sth - statement handle being destroyed
 *           imp_sth - drivers private statement handle data
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_st_destroy(SV* sth, imp_sth_t* imp_sth) {
    int i;

    /* dbd_st_finish has already been called by .xs code if needed.	*/

    /*
     *  Free values allocated by dbd_bind_ph
     */
    FreeParam(imp_sth->params, DBIc_NUM_PARAMS(imp_sth));
    imp_sth->params = NULL;

    /*
     *  Free cached array attributes
     */
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	if (imp_sth->av_attr[i]) {
	    SvREFCNT_dec(imp_sth->av_attr[i]);
	}
	imp_sth->av_attr[i] = Nullav;
    }

    DBIc_IMPSET_off(imp_sth);           /* let DBI know we've done it   */
}


/***************************************************************************
 *
 *  Name:    dbd_st_STORE_attrib
 *
 *  Purpose: Modifies a statement handles attributes; we currently
 *           support just nothing
 *
 *  Input:   sth - statement handle being destroyed
 *           imp_sth - drivers private statement handle data
 *           keysv - attribute name
 *           valuesv - attribute value
 *
 *  Returns: TRUE for success, FALSE otrherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_STORE_attrib(SV* sth, imp_sth_t* imp_sth, SV* keysv, SV* valuesv) {
    STRLEN(kl);
    char* key = SvPV(keysv, kl);
    int result = FALSE;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    -> dbd_st_STORE_attrib for %08lx, key %s\n",
		(u_long) sth, key);
    }


    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    <- dbd_st_STORE_attrib for %08lx, result %d\n",
		(u_long) sth, result);
    }

    return result;
}


/***************************************************************************
 *
 *  Name:    dbd_st_FETCH_internal
 *
 *  Purpose: Retrieves a statement handles array attributes; we use
 *           a separate function, because creating the array
 *           attributes shares much code and it aids in supporting
 *           enhanced features like caching.
 *
 *  Input:   sth - statement handle; may even be a database handle,
 *               in which case this will be used for storing error
 *               messages only. This is only valid, if cacheit (the
 *               last argument) is set to TRUE.
 *           what - internal attribute number
 *           res - pointer to a DBMS result
 *           cacheit - TRUE, if results may be cached in the sth.
 *
 *  Returns: RV pointing to result array in case of success, NULL
 *           otherwise; do_error has already been called in the latter
 *           case.
 *
 **************************************************************************/

#ifndef IS_KEY
#define IS_KEY(A) (((A) & (PRI_KEY_FLAG | UNIQUE_KEY_FLAG | MULTIPLE_KEY_FLAG)) != 0)
#endif
#ifndef IS_NUM
#ifdef UINT_TYPE
#define IS_NUM(A) ((A) == INT_TYPE || (A) == REAL_TYPE || (A) == UINT_TYPE)
#else
#define IS_NUM(A) ((A) == INT_TYPE || (A) == REAL_TYPE)
#endif
#endif

SV* dbd_st_FETCH_internal(SV* sth, int what, result_t res, int cacheit) {
    imp_sth_t* imp_sth;
    AV *av = Nullav;
    field_t curField;

    /*
     *  Are we asking for a legal value?
     */
    if (what < 0 ||  what >= AV_ATTRIB_LAST) {
	do_error(sth, JW_ERR_NOT_IMPLEMENTED, "Not implemented");

    /*
     *  Return cached value, if possible
     */
    } else if (cacheit  &&
	       (imp_sth = (imp_sth_t*) DBIh_COM(sth))->av_attr[what]) {
	av = imp_sth->av_attr[what];

    /*
     *  Does this sth really have a result?
     */
    } else if (!res) {
	do_error(sth, JW_ERR_NOT_ACTIVE,
		 "statement contains no result");

    /*
     *  Do the real work.
     */
    } else {
	av = newAV();
	MyFieldSeek(res, 0);
	while ((curField = MyFetchField(res))) {
	    SV* sv;

	    switch(what) {
	      case AV_ATTRIB_NAME:
		sv = newSVpv(curField->name, strlen(curField->name));
		break;
	      case AV_ATTRIB_TABLE:
		sv = newSVpv(curField->table, strlen(curField->table));
		break;
	      case AV_ATTRIB_TYPE:
		sv = newSViv((int) curField->type);
		break;
	      case AV_ATTRIB_IS_PRI_KEY:
		sv = boolSV(IS_PRI_KEY(curField->flags));
		break;
	      case AV_ATTRIB_IS_NOT_NULL:
		sv = boolSV(IS_NOT_NULL(curField->flags));
		break;
	      case AV_ATTRIB_NULLABLE:
		sv = boolSV(!IS_NOT_NULL(curField->flags));
		break;
	      case AV_ATTRIB_LENGTH:
		sv = newSViv((int) curField->length);
		break;
	      case AV_ATTRIB_IS_NUM:
		sv = boolSV(IS_NUM(curField->flags));
		break;
	      case AV_ATTRIB_TYPE_NAME:
	        {
		    static struct db_types {
			int id;
			const char* name;
		    } types [] = {
			{ INT_TYPE, "int" },
			{ CHAR_TYPE, "char" },
			{ REAL_TYPE, "real" },
			{ IDENT_TYPE, "ident" },
#ifdef IDX_TYPE
			{ IDX_TYPE, "index" },
#endif
#ifdef TEXT_TYPE
			{ TEXT_TYPE, "text" },
#endif
#ifdef DATE_TYPE
			{ DATE_TYPE, "date" },
#endif
#ifdef UINT_TYPE
			{ UINT_TYPE, "uint" },
#endif
#ifdef MONEY_TYPE
			{ MONEY_TYPE, "money" },
#endif
#ifdef TIME_TYPE
			{ TIME_TYPE, "time" },
#endif
#ifdef SYSVAR_TYPE
			{ SYSVAR_TYPE, "sys" }
#endif
		    };
		    int i, found = FALSE;
		    for (i = 0;  i < sizeof(types) / sizeof(struct db_types);
			 i++) {
			if (curField->type == types[i].id) {
			    sv = newSVpv((char*) types[i].name,
					 strlen(types[i].name));
			    found = TRUE;
			    break;
			}
		    }
		    if (!found) {
			sv = newSVpv((char*) "unknown", 7);
		    }
		}
	        break;
	    }

	    av_push(av, sv);
	}

	/*
	 *  Ensure that this value is kept, decremented in
	 *  dbd_st_destroy and dbd_st_execute.
	 */
	if (cacheit) {
	    imp_sth->av_attr[what] = av;
	} else {
	    return sv_2mortal(newRV_noinc((SV*) av));
	}
    }

    if (av == Nullav) {
	return &sv_undef;
    }
    return sv_2mortal(newRV((SV*)av));
}


/***************************************************************************
 *
 *  Name:    dbd_st_FETCH_attrib
 *
 *  Purpose: Retrieves a statement handles attributes
 *
 *  Input:   sth - statement handle being destroyed
 *           imp_sth - drivers private statement handle data
 *           keysv - attribute name
 *
 *  Returns: NULL for an unknown attribute, "undef" for error,
 *           attribute value otherwise.
 *
 **************************************************************************/

#define ST_FETCH_AV(what) \
    dbd_st_FETCH_internal(sth, (what), imp_sth->cda, TRUE)

SV* dbd_st_FETCH_attrib(SV* sth, imp_sth_t* imp_sth, SV* keysv) {
    STRLEN(kl);
    char* key = SvPV(keysv, kl);
    SV* retsv = Nullsv;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    -> dbd_st_FETCH_attrib for %08lx, key %s\n",
		(u_long) sth, key);
    }

    switch (*key) {
      case 'I':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "IS_PRI_KEY")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_PRI_KEY);
	} else if (strEQ(key, "IS_NOT_NULL")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NOT_NULL);
	} else if (strEQ(key, "IS_NUM")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	}
	break;
      case 'L':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "LENGTH")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
	}
	break;
      case 'N':
	if (strEQ(key, "NAME")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_NAME);
	} else if (strEQ(key, "NULLABLE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_NULLABLE);
	} else if (strEQ(key, "NUMROWS")) {
	    retsv = sv_2mortal(newSViv((IV)imp_sth->row_num));
	} else if (strEQ(key, "NUMFIELDS")) {
	    retsv = sv_2mortal(newSViv((IV) DBIc_NUM_FIELDS(imp_sth)));
	}
	break;
      case 'R':
	/*
	 * Deprecated, use 'result'
	 */
	if (strEQ(key, "RESULT")) {
	    retsv = sv_2mortal(newSViv((IV) imp_sth->cda));
	}
	break;
      case 'T':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "TABLE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TABLE);
	} else if (strEQ(key, "TYPE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE);
	}
      case 'f':
	if (strEQ(key, "format_max_size")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
	} else if (strEQ(key, "format_right_justify")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	} else if (strEQ(key, "format_type_name")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE_NAME);
	}
	break;
      case 'i':
	if (strEQ(key, "insertid")) {
	    retsv = sv_2mortal(newSViv(imp_sth->insertid));
	} else if (strEQ(key, "is_pri_key")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_PRI_KEY);
	} else if (strEQ(key, "is_not_null")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NOT_NULL);
	} else if (strEQ(key, "is_num")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	}
	break;
      case 'l':
	if (strEQ(key, "length")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
	}
	break;
      case 'r':
	/*
	 * Deprecated, use 'result'
	 */
	if (strEQ(key, "result")) {
	    retsv = sv_2mortal(newSViv((IV) imp_sth->cda));
	}
	break;
      case 't':
	if (strEQ(key, "table")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TABLE);
	} else if (strEQ(key, "type")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE);
	}
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    <- dbd_st_FETCH_attrib for %08lx, key %s: result %s\n",
		(u_long) sth, key, retsv ? SvPV(retsv, na) : "NULL");
    }

    return retsv;
}


/***************************************************************************
 *
 *  Name:    dbd_st_blob_read
 *
 *  Purpose: Used for blob reads if the statement handles "LongTruncOk"
 *           attribute (currently not supported by DBD::mysql)
 *
 *  Input:   SV* - statement handle from which a blob will be fetched
 *           imp_sth - drivers private statement handle data
 *           field - field number of the blob (note, that a row may
 *               contain more than one blob)
 *           offset - the offset of the field, where to start reading
 *           len - maximum number of bytes to read
 *           destrv - RV* that tells us where to store
 *           destoffset - destination offset
 *
 *  Returns: TRUE for success, FALSE otrherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_blob_read (SV *sth, imp_sth_t *imp_sth, int field, long offset,
		      long len, SV *destrv, long destoffset) {
    return FALSE;
}


/***************************************************************************
 *
 *  Name:    dbd_st_rows
 *
 *  Purpose: Reads number of result rows
 *
 *  Input:   sth - statement handle
 *           imp_sth - drivers private statement handle data
 *
 *  Returns: Number of rows returned or affected by executing the
 *           statement
 *
 **************************************************************************/

int dbd_st_rows(SV* sth, imp_sth_t* imp_sth) {
    return imp_sth->row_num;
}


/***************************************************************************
 *
 *  Name:    dbd_bind_ph
 *
 *  Purpose: Binds a statement value to a parameter
 *
 *  Input:   sth - statement handle
 *           imp_sth - drivers private statement handle data
 *           param - parameter number, counting starts with 1
 *           value - value being inserted for parameter "param"
 *           sql_type - SQL type of the value
 *           attribs - bind parameter attributes, currently this must be
 *               one of the values SQL_CHAR, ...
 *           inout - TRUE, if parameter is an output variable (currently
 *               this is not supported)
 *           maxlen - ???
 *
 *  Returns: TRUE for success, FALSE otherwise
 *
 **************************************************************************/

int dbd_bind_ph (SV *sth, imp_sth_t *imp_sth, SV *param, SV *value,
		 IV sql_type, SV *attribs, int is_inout, IV maxlen) {
    int paramNum = SvIV(param);

    if (paramNum <= 0  ||  paramNum > DBIc_NUM_PARAMS(imp_sth)) {
        do_error(sth, JW_ERR_ILLEGAL_PARAM_NUM,
		       "Illegal parameter number");
	return FALSE;
    }

    if (is_inout) {
        do_error(sth, JW_ERR_NOT_IMPLEMENTED,
		       "Output parameters not implemented");
	return FALSE;
    }

    return BindParam(&imp_sth->params[paramNum - 1], value, sql_type);
}
