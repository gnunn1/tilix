#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([Terminix], [1.0.0], [https://github.com/gnunn1/terminix/issues], [terminix], [https://github.com/gnunn1/terminix])
AC_CONFIG_SRCDIR([source/gx/terminix/application.d])
AC_CONFIG_AUX_DIR([acaux])

AC_ARG_VAR([DC], [D compiler executable])
AC_ARG_VAR([DEPS_CFLAGS], [pkg-config CFLAGS for dependencies])
AC_ARG_VAR([DEPS_LIBS], [pkg-config LIBS for dependencies])
AC_ARG_VAR([DCFLAGS], [flags for dmd compiler])

# Full optimization flags
#DCFLAGS='-O -inline -release -version=StdLoggerDisableTrace'
DCFLAGS='-O'
AC_SUBST([DCFLAGS])

# Checks for programs.
AC_PROG_INSTALL
AC_PATH_PROG([DC], [dmd])
AC_PATH_PROG([GLIB_COMPILE_RES], [glib-compile-resources])
PKG_PROG_PKG_CONFIG
AM_GNU_GETTEXT([external])
AM_GNU_GETTEXT_VERSION([0.19.7])

# Checks for libraries.
PKG_CHECK_MODULES([DEPS], [gtkd-3-dmd >= 3.3.0 vted-3-dmd >= 3.3.0],,
				  [PKG_CHECK_MODULES([DEPS], [gtkd-3 >= 3.3.0 vted-3 >= 3.3.0])])
# TODO: test if library was compiled with @DC@?

AM_INIT_AUTOMAKE([1.15 foreign])
AC_CONFIG_FILES([Makefile data/appdata/Makefile data/icons/Makefile data/pkg/desktop/Makefile data/resources/Makefile po/Makefile.in])
AC_OUTPUT
