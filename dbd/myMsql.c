/*
 *  myMsql.c - Connect function for use in msql/mysql sources
 *
 *
 *  Copyright (c) 1997  Jochen Wiedmann
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
 *  $Id: myMsql.c 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
 */

/*
 *  Header files we use
 */
#include <stdlib.h>
#include <string.h>
#include <EXTERN.h>
#include <perl.h>
#include "myMsql.h"

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE (!FALSE)
#endif


/***************************************************************************
 *
 *  Name:    MyConnect
 *
 *  Purpose: Replacement for mysql_connect or msqlConnect; the
 *           difference is, that it supports "host:port".
 *
 *  Input:   sock - pointer where to store the MYSQL pointer being
 *               initialized (mysql) or to an integer where to store
 *               a socket number (msql)
 *           host - the host to connect to, a value "host:port" is
 *               valid
 *           port - port number (as string)
 *           user - user name to connect as; ignored for msql
 *           password - passwort to connect with; ignored for mysql
 *
 *  Returns: TRUE for success, FALSE otherwise; you have to call
 *           do_error in the latter case.
 *
 *  Bugs:    The msql version needs to set the environment
 *           variable MSQL_TCP_PORT. There's absolutely no
 *           portable way of setting environment variables
 *           from within C: Neither setenv() nor putenv()
 *           are guaranteed to work. I have decided to use
 *           the internal perl functions setenv_getix()
 *           and my_setenv() instead, let's hope, this is safe.
 *
 *           Another problem was pointed out by Andreas:
 *           This isn't thread safe. We'll have fun with perl
 *           5.005 ... :-)
 *
 **************************************************************************/

typedef struct pArg {
    char* argName;
    char** argPtr;
} pArg_t;


static int OdbcParse(char* dsn, char** copy, pArg_t* args) {
    char* ptr;
    char* arg;
    pArg_t* argPtr;

    *copy = NULL;
    if (!dsn) {
        return TRUE;  /*  No parsing required  */
    }

    /*
     *  Parse the DSN
     */
    for (ptr = dsn;  *ptr;  ++ptr) {
        if (*ptr == '='  ||  *ptr == ':'  ||  *ptr == ';') {
	    if (!(*copy = (char*) malloc(strlen(dsn)+1))) {
	        return FALSE;
	    }
	    strcpy(*copy, dsn);
	    break;
	}
    }

    if (!*copy) {
        return TRUE;  /*  No parsing required  */
    }

    for (argPtr = args;  argPtr->argName;  ++argPtr) {
        *argPtr->argPtr = NULL;
    }

    arg = *copy;
    while (*arg) {
        char* var = NULL;
	char* val = arg;
	while (*arg  &&  *arg != ';'  &&  *arg != ':') {
	    if (*arg == '=') {
	        var = val;
		*arg++ = '\0';
		val = arg;
	    } else {
	        ++arg;
	    }
	}
	if (*arg) {
	    *arg++ = '\0';
	}
	
	for (argPtr = args;  argPtr->argName;  ++argPtr) {
	    if ((!var  &&  !(*argPtr->argPtr))  ||
		(var  &&  strEQ(var, argPtr->argName))) {
	        *argPtr->argPtr = val;
	    }
	    break;
	}
    }
    return TRUE;
}
		     

static int MyInternalConnect(dbh_connect_t sock, char* host, char* port,
			     char* user, char* password) {
    int portNr;

    if (host && !*host) host = NULL;
    if (port && *port) {
        portNr = atoi(port);
    } else {
        portNr = 0;
    }
    if (user && !*user) user = NULL;
    if (password && !*password) password = NULL;

#ifdef DBD_MYSQL
    {
#ifndef HAVE_MYSQL_REAL_CONNECT
        /*
	 *  Setting a port for mysql's client is ugly: We have to use
	 *  the not documented variable mysql_port.
	 */
        mysql_port = portNr;
        return mysql_connect(sock, host, user, password) ? TRUE : FALSE;
#else
#if defined(MYSQL_VERSION_ID)  &&  MYSQL_VERSION_ID >= 032115
	return mysql_real_connect(sock, host, user, password, portNr, NULL,
				  0) ?
	    TRUE : FALSE;
#else
	return mysql_real_connect(sock, host, user, password, portNr, NULL) ?
	    TRUE : FALSE;
#endif
#endif
    }
#else
    {
        /*
	 *  Setting a port for msql's client is extremely ugly: We have
	 *  to set an environment variable. Even worse, we cannot trust
	 *  in setenv or putenv being present, thus we need to use
	 *  internal, not documented, perl functions. :-(
	 */
        char buffer[32];
	char* oldPort = NULL;

	sprintf(buffer, "%d", portNr);
	if (portNr) {
	    oldPort = environ[setenv_getix("MSQL_TCP_PORT")];
	    if (oldPort) {
	        char* copy = (char*) malloc(strlen(oldPort)+1);
		if (!copy) {
		    return FALSE;
		}
		strcpy(copy, oldPort);
		oldPort = copy;
	    }
	    my_setenv("MSQL_TCP_PORT", buffer);
	}
	*sock = msqlConnect(host);
	if (oldPort) {
	    my_setenv("MSQL_TCP_PORT", oldPort);
	    if (oldPort) { free(oldPort); }
	}
	return (*sock == -1) ? FALSE : TRUE;
    }
#endif
}


static pArg_t myConnectArgs[] = {
    { "hostname", NULL },
    { "port", NULL },
    { NULL, NULL }
};


int MyConnect(dbh_connect_t sock, char* host, char* user, char* password) {
    char* copy = NULL;
    char* port = NULL;

    myConnectArgs[0].argPtr = &host;
    myConnectArgs[1].argPtr = &port;
    if (!OdbcParse(host, &copy, myConnectArgs)) {
        return FALSE;
    }

    /*
     *  Try to connect
     */
    if (!MyInternalConnect(sock, host, port, user, password)) {
        if (copy) {
	    free(copy);
	}
	return FALSE;
    }

    return TRUE;
}


/***************************************************************************
 *
 *  Name:    MyLogin
 *
 *  Purpose: Called from the DBI driver for connecting to a database;
 *           the main difference to MyConnect is that it includes
 *           selecting a database
 *
 *  Input:   sock - pointer where to store the MYSQL pointer being
 *               initialized (mysql) or to an integer where to store
 *               a socket number (msql)
 *           dsn - DSN string; preferrably ODBC syntax
 *           user - user name to connect as; ignored for msql
 *           password - passwort to connect with; ignored for mysql
 *
 *  Returns: TRUE for success, FALSE otherwise; you have to call
 *           do_error in the latter case.
 *
 **************************************************************************/

static pArg_t myLoginArgs[] = {
    { "database", NULL },
    { "hostname", NULL },
    { "port", NULL },
    { NULL, NULL }
};


int MyLogin(dbh_connect_t sock, char* dbname, char* user, char* password) {
    char* copy = NULL;
    char* host = NULL;
    char* port = NULL;

    myLoginArgs[0].argPtr = &dbname;
    myLoginArgs[1].argPtr = &host;
    myLoginArgs[2].argPtr = &port;
    if (!OdbcParse(dbname, &copy, myLoginArgs)) {
        return FALSE;
    }
    if (!dbname) {
        dbname = "";
    }

    /*
     *  Try to connect
     */
    if (!MyInternalConnect(sock, host, port, user, password)) {
        if (copy) {
	    free(copy);
	}
    }

    /*
     *  Connected, now try to login
     */
#xtract Mysql
    if (MySelectDb(sock, dbname)) {
        if (copy) {
	    free(copy);
	}
	MyClose(sock);
	return FALSE;
    }
#xtract Msql
    if (MySelectDb(*sock, dbname)) {
        if (copy) {
	    free(copy);
	}
	MyClose(*sock);
	return FALSE;
    }
#endxtract

    if (copy) {
        free(copy);
    }
    return TRUE;
}
