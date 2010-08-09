/*-
 * Copyright (c) 2006 Joseph Koshy
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id$
 */

#include <sys/errno.h>

#include <fcntl.h>
#include <libelf.h>
#include <string.h>
#include <unistd.h>

#include "tet_api.h"

#include "elfts.h"

include(`elfts.m4')

define(`TP_SET_VERSION',`do {
		if (elf_version(EV_CURRENT) != EV_CURRENT) {
			TP_UNRESOLVED("elf_version() failed: \"%s\".",
			    elf_errmsg(-1));
			goto done;
		}
	} while (0)')

define(`TS_ARFILE',`"a.ar"')

/*
 * Test the `elf_begin' entry point.
 */

/*
 * Calling elf_begin() before elf_version() results in ELF_E_SEQUENCE.
 * Note that these test cases should run as a separate invocation than
 * the others since they need to be run before elf_version() is called.
 */
undefine(`FN')
define(`FN',`
void
tcSequence_tpUninitialized$1(void)
{
	Elf *e;
	int error, result;

	TP_ANNOUNCE("elf_version() needs to be set before "
	    "using the elf_begin($1) API.");

	result = TET_PASS;
	if ((e = elf_begin(-1, ELF_C_$1, NULL)) != NULL ||
	    (error = elf_errno()) != ELF_E_SEQUENCE)
		TP_FAIL("ELF_C_$1: e=%p error=%d \"%s\".", (void *) e, error,
		    elf_errmsg(error));

	tet_result(result);
}')

FN(`NULL')
FN(`READ')
FN(`WRITE')
FN(`RDWR')

void
tcCmd_tpInvalid(void)
{
	Elf *e;
	int c, error, result;

	TP_ANNOUNCE("An invalid cmd value returns ELF_E_ARGUMENT.");

	TP_SET_VERSION();

	result = TET_PASS;
	for (c = ELF_C_NULL-1; c <= ELF_C_NUM; c++) {
		if (c == ELF_C_READ || c == ELF_C_WRITE || c == ELF_C_RDWR ||
		    c == ELF_C_NULL)
			continue;
		if ((e = elf_begin(-1, c, NULL)) != NULL ||
		    (error = elf_errno()) != ELF_E_ARGUMENT) {
			TP_FAIL("cmd=%d: e=%p error=%d .", c,
			    (void *) e, error);
			break;
		}
	}

 done:
	tet_result(result);
}

void
tcCmd_tpNull(void)
{
	Elf *e;
	int result;

	TP_ANNOUNCE("cmd == ELF_C_NULL returns NULL.");

	TP_SET_VERSION();

	result = (e = elf_begin(-1, ELF_C_NULL, NULL)) != NULL ? TET_FAIL :
	    TET_PASS;

 done:
	tet_result(result);
}


#define	TEMPLATE	"TCXXXXXX"
#define	FILENAME_SIZE	16
char	filename[FILENAME_SIZE];

int
setup_tempfile(void)
{
	int fd;

	(void) strncpy(filename, TEMPLATE, sizeof(filename));
	filename[sizeof(filename) - 1] = '\0';

	if ((fd = mkstemp(filename)) < 0 ||
	    write(fd, TEMPLATE, sizeof(TEMPLATE)) < 0)
		return 0;

	(void) close(fd);

	return 1;

}

void
cleanup_tempfile(void)
{
	(void) unlink(filename);
}


void
tcCmd_tpWriteFdRead(void)
{
	Elf *e;
	int error, fd, result;

	TP_ANNOUNCE("cmd == ELF_C_WRITE on non-writable FD is rejected.");

	TP_SET_VERSION();

	if (setup_tempfile() == 0 ||
	    (fd = open(filename, O_RDONLY, 0)) < 0) {
		TP_UNRESOLVED("setup failed: %s", strerror(errno));
		goto done;
	}

	result = TET_PASS;
	error = -1;
	if ((e = elf_begin(fd, ELF_C_WRITE, NULL)) != NULL ||
	    (error = elf_errno()) != ELF_E_IO)
		TP_FAIL("fn=%s e = %p, error = %d", filename,
		    (void *) e, error);

 done:
	cleanup_tempfile();
	tet_result(result);
}

void
tcCmd_tpWriteFdRdwr(void)
{
	Elf *e;
	int error, fd, result;

	TP_ANNOUNCE("cmd == ELF_C_WRITE on an 'rdwr' FD passes.");

	if (setup_tempfile() == 0 ||
	    (fd = open(filename, O_RDWR, 0)) < 0) {
		TP_UNRESOLVED("setup failed: %s", strerror(errno));
		goto done;
	}

	result = TET_PASS;
	error = -1;
	if ((e = elf_begin(fd, ELF_C_WRITE, NULL)) == NULL)
		TP_FAIL("fn=%s e = %p, error = %d", filename,
		    (void *) e, error);

 done:
	cleanup_tempfile();
	tet_result(result);
}

void
tcCmd_tpWriteFdWrite(void)
{
	Elf *e;
	int error, fd, result;

	TP_ANNOUNCE("cmd == ELF_C_WRITE on write-only FD passes.");

	if (setup_tempfile() == 0 ||
	    (fd = open(filename, O_WRONLY, 0)) < 0) {
		TP_UNRESOLVED("setup failed: %s", strerror(errno));
		goto done;
	}

	result = TET_PASS;
	error = -1;
	if ((e = elf_begin(fd, ELF_C_WRITE, NULL)) == NULL)
		TP_FAIL("fn=%s e = %p, error = %d", filename,
		    (void *) e, error);

 done:
	cleanup_tempfile();
	tet_result(result);
}


/*
 * Check that opening various classes/endianness of ELF files
 * passes.
 */
undefine(`FN')
define(`FN',`
void
tcElf_tp$1$2(void)
{
	Elf *e;
	int fd, result;
	char *p;

	TP_ANNOUNCE("open(ELFCLASS$1,ELFDATA2`'TOUPPER($2)) succeeds.");

	TP_SET_VERSION();

	fd = -1;
	e = NULL;
	result = TET_UNRESOLVED;

	if ((fd = open ("check_elf.$2$1", O_RDONLY)) < 0) {
		TP_UNRESOLVED("open() failed: %s.", strerror(errno));
		goto done;
	}

	if ((e = elf_begin(fd, ELF_C_READ, NULL)) == NULL) {
		TP_FAIL("elf_begin() failed: %s.", elf_errmsg(-1));
		goto done;
	}

	if ((p = elf_getident(e, NULL)) == NULL) {
		TP_FAIL("elf_getident() failed: \"%s\".", elf_errmsg(-1));
		goto done;
	}

	if (p[EI_CLASS] != ELFCLASS$1 ||
	    p[EI_DATA] != ELFDATA2`'TOUPPER($2))
		TP_FAIL("class %d expected %d, data %d expected %d.",
		    p[EI_CLASS], ELFCLASS$1, p[EI_DATA], ELFDATA2`'TOUPPER($2));
	else
		result = TET_PASS;

 done:
	if (e)
		(void) elf_end(e);
	if (fd != -1)
		(void) close(fd);
	tet_result(result);
}')

FN(32,`lsb')
FN(32,`msb')
FN(64,`lsb')
FN(64,`msb')

/*
 * Check that an AR archive detects a cmd mismatch.
 */
undefine(`FN')
define(`FN',`
void
tcAr_tpCmdMismatch$1(void)
{
	Elf *e, *e2;
	int error, fd, result;

	TP_ANNOUNCE("a cmd mismatch is detected.");

	TP_SET_VERSION();

	result = TET_UNRESOLVED;
	e = e2 = NULL;
	fd = -1;

	_TS_OPEN_FILE(e, TS_ARFILE, ELF_C_READ, fd, goto done;);

	result = TET_PASS;
	if ((e2 = elf_begin(fd, ELF_C_$1, e)) != NULL ||
	    (error = elf_errno()) != ELF_E_ARGUMENT)
		TP_FAIL("e2=%p error=%d \"%s\".", (void *) e2,
		    error, elf_errmsg(error));
 done:
	if (e)
		(void) elf_end(e);
	if (e2)
		(void) elf_end(e2);
	if (fd >= 0)
		(void) close(fd);
	tet_result(result);
}')

FN(WRITE)
FN(RDWR)

/*
 * Check that an AR archive allows valid cmd values.
 */
undefine(`FN')
define(`FN',`
void
tcAr_tpCmdMatch$1(void)
{
	Elf *e, *e2;
	int fd, result;

	TP_ANNOUNCE("a cmd match is allowed.");

	TP_SET_VERSION();

	result = TET_UNRESOLVED;
	e = e2 = NULL;
	fd = -1;

	TS_OPEN_FILE(e, TS_ARFILE, ELF_C_READ, fd);

	result = TET_PASS;
	if ((e2 = elf_begin(fd, ELF_C_$1, e)) == NULL)
		TP_FAIL("error=\"%s\".", elf_errmsg(-1));

 done:
	if (e)
		(void) elf_end(e);
	if (e2)
		(void) elf_end(e2);
	if (fd >= 0)
		(void) close(fd);
	tet_result(result);
}')

FN(READ)

/*
 * Check that a member is correctly retrieved.
 */
void
tcAr_tpRetrieval(void)
{
	Elf *e, *e1;
	int fd, result;
	Elf_Kind k;

	TP_ANNOUNCE("an archive member is correctly retrieved.");

	TP_SET_VERSION();

	e = e1 = NULL;
	fd = -1;

	_TS_OPEN_FILE(e, TS_ARFILE, ELF_C_READ, fd, goto done;);

	result = TET_PASS;
	if ((e1 = elf_begin(fd, ELF_C_READ, e)) == NULL) {
		TP_FAIL("elf_begin() failed: \"%s\".", elf_errmsg(-1));
		goto done;
	}

	if ((k = elf_kind(e1)) != ELF_K_ELF)
		TP_FAIL("kind %d, expected %d.", k, ELF_K_ELF);

 done:
	if (e1)
		(void) elf_end(e1);
	if (e)
		(void) elf_end(e);
	if (fd != -1)
		(void) close(fd);
	tet_result(result);
}

/*
 * Check an `fd' mismatch is detected.
 */
void
tcFd_tpMismatch(void)
{
	Elf *e, *e2;
	int error, fd, result;

	TP_ANNOUNCE("an fd mismatch is detected.");

	TP_SET_VERSION();

	e = e2 = NULL;
	fd = -1;

	if ((fd = open("check_elf.msb32", O_RDONLY)) < 0 ||
	    (e = elf_begin(fd, ELF_C_READ, NULL)) == NULL) {
		TP_UNRESOLVED("open(check_elf) failed: fd=%d.", fd);
		goto done;
	}

	result = TET_PASS;

	if ((e2 = elf_begin(fd+1, ELF_C_READ, e)) != NULL ||
	    (error = elf_errno()) != ELF_E_ARGUMENT)
		TP_FAIL("elf_begin(%d+1) -> %p, error=%d \"%s\".", fd,
		    (void *) e2, error, elf_errmsg(error));
 done:
	if (e)
		(void) elf_end(e);
	if (e2)
		(void) elf_end(e2);
	if (fd >= 0)
		(void) close(fd);
	tet_result(result);
}

#if	defined(LIBELF_TEST_HOOKS)

#define	ERRORNUM		0xFF	/* any non-zero value will do */

void
tcCmd_tpNullError(void)
{
	Elf *e;
	int result;

	TP_ANNOUNCE("cmd == NULL does not reset elf_errno.");

	TP_SET_VERSION();

	_libelf_set_error(ERRORNUM);

	result = TET_PASS;
	if ((e = elf_begin(-1, ELF_C_NULL, NULL)) != NULL) {
		TP_UNRESOLVED("cmd == ELF_C_NULL failed to "
		    "return NULL.");
		goto done;
	}

	if (elf_errno() != ERRORNUM)
		result = TET_FAIL;

 done:
	tet_result(result);

}
#endif	/* LIBELF_TEST_HOOKS */
