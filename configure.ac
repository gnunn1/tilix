#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([Tilix], [1.5.4], [https://github.com/gnunn1/tilix/issues], [tilix], [https://github.com/gnunn1/tilix])
AC_CONFIG_SRCDIR([source/gx/tilix/application.d])
AC_CONFIG_AUX_DIR([acaux])

AC_ARG_VAR([DC], [D compiler executable])
AC_ARG_VAR([DEPS_CFLAGS], [pkg-config CFLAGS for dependencies])
AC_ARG_VAR([DEPS_LIBS], [pkg-config LIBS for dependencies])
AC_ARG_VAR([DCFLAGS], [flags for dmd compiler])

# Full optimization flags
#DCFLAGS='-O -inline -release -version=StdLoggerDisableTrace'
: ${DCFLAGS='-O'}
AC_SUBST([DCFLAGS])

# Checks for programs.
AC_PROG_INSTALL
# Look for D compiler. Use dmd-compatible wrapper for ldc and gdc.
# NOTE: Tilix cannot be compiled with gdc currently.
AC_PATH_PROGS([DC], [ldmd ldmd2 dmd gdmd], NOT_FOUND)
AC_PATH_PROG([GLIB_COMPILE_RES], [glib-compile-resources])
PKG_PROG_PKG_CONFIG
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.19.7])
AC_PATH_PROG([PO4A_TRANS], [po4a-translate])

if test -z $PO4A_TRANS; then
	AC_MSG_ERROR([cannot find po4a-translate])
fi

DC_SUFFIX=
case $(basename $DC) in
	dmd) DC_SUFFIX=-dmd ;;
	ldmd,ldmd2) DC_SUFFIX=-ldc ;;
	gdmd) DC_SUFFIX=-gdc ;;
	NOT_FOUND) AC_MSG_ERROR(Could not find any compatible D compiler, 1)
esac

# Checks for libraries.
GTKDVER=3.8.5
# Use pkg-config to look for gtkd. Tries to find a compiler specific suffix, then falls back to suffix-less
PKG_CHECK_MODULES([GTKD], [gtkd-3$DC_SUFFIX >= $GTKDVER vted-3$DC_SUFFIX >= $GTKDVER],,
				  [PKG_CHECK_MODULES([GTKD], [gtkd-3 >= $GTKDVER vted-3 >= $GTKDVER])])
# TODO: test if library was compiled with @DC@?

# libx11 is a C library, so no need of suffix
PKG_CHECK_MODULES([X11], [x11])

AM_INIT_AUTOMAKE([1.15 foreign])
AC_CONFIG_FILES([Makefile data/appdata/Makefile data/icons/Makefile data/pkg/desktop/Makefile data/resources/Makefile data/man/Makefile po/Makefile.in])
AC_OUTPUT
