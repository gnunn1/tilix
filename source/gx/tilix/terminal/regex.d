/*
 * Copyright © 2015 Egmont Koblinger
 *
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Mini style-guide:
 *
 * #define'd fragments should preferably have an outermost group, for the
 * exact same reason as why usually in C/C++ #define's the values are enclosed
 * in parentheses: that is, so that you don't get surprised when you use the
 * macro and append a quantifier.
 *
 * For repeated fragments prefer regex-style (?(DEFINE)(?<NAME>(...))) and use
 * as (?&NAME), so that the regex string and the compiled regex object is
 * smaller.
 *
 * Build small blocks, comment and unittest them heavily.
 *
 * Use free-spacing mode for improved readability. The hardest to read is
 * which additional characters belong to a "(?" prefix. To improve
 * readability, place a space after this, and for symmetry, before the closing
 * parenthesis. Also place a space around "|" characters. No space before
 * quantifiers. Try to be consistent with the existing style (yes I know the
 * existing style is not consistent either, but please do your best).
 *
 * See http://www.rexegg.com/regex-disambiguation.html for all the "(?"
 * syntaxes.
 */

 /*
  * Adapted from Gnome Terminal
  * https://github.com/GNOME/gnome-terminal/blob/69572341e785484a019fb454129b8d1064bb1fe1/src/terminal-regex.h
  */

module gx.tilix.terminal.regex;

import std.conv;
import std.string;

import glib.MatchInfo;
import glib.Regex : GRegex = Regex;

import gtkc.glibtypes;

import gx.gtk.vte;

import vte.Regex: VRegex = Regex;

import gx.tilix.constants;

enum SCHEME = "(?ix: news | telnet | nntp | https? | ftps? | sftp | webcal )";

enum USERCHARS = "-+.[:alnum:]";
/* Nonempty username, e.g. "john.smith" */
enum USER = "[" ~ USERCHARS ~ "]+";

enum PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]";
/* Optional colon-prefixed password. I guess empty password should be allowed, right? E.g. ":secret", ":", "" */
enum PASS =  "(?x: :" ~ PASSCHARS_CLASS ~ "* )?";

/* Optional at-terminated username (with perhaps a password too), e.g. "joe@", "pete:secret@", "" */
enum USERPASS = "(?:" ~ USER ~ PASS ~ "@)?";

/* S4: IPv4 segment (number between 0 and 255) with lookahead at the end so that we don't match "25" in the string "256".
   The lookahead could go to the last segment of IPv4 only but this construct allows nicer unittesting. */
enum S4_DEF = "(?(DEFINE)(?<S4>(?x: (?: [0-9] | [1-9][0-9] | 1[0-9]{2} | 2[0-4][0-9] | 25[0-5] ) (?! [0-9] ) )))";

/* IPV4: Decimal IPv4, e.g. "1.2.3.4", with lookahead (implemented in S4) at the end so that we don't match "192.168.1.123" in the string "192.168.1.1234". */
enum IPV4_DEF = S4_DEF ~ "(?(DEFINE)(?<IPV4>(?x: (?: (?&S4) \\. ){3} (?&S4) )))";

/* IPv6, including embedded IPv4, e.g. "::1", "dead:beef::1.2.3.4".
 * Lookahead for the next char not being a dot or digit, so it doesn't get stuck matching "dead:beef::1" in "dead:beef::1.2.3.4".
 * This is not required since the surrounding brackets would trigger backtracking, but it allows nicer unittesting.
 * TODO: more strict check (right number of colons, etc.)
 * TODO: add zone_id: RFC 4007 section 11, RFC 6874 */

/* S6: IPv6 segment, S6C: IPv6 segment followed by a comma, CS6: comma followed by an IPv6 segment */
enum S6_DEF = "(?(DEFINE)(?<S6>[[:xdigit:]]{1,4})(?<CS6>:(?&S6))(?<S6C>(?&S6):))";

/* No :: shorthand */
enum IPV6_FULL = "(?x: (?&S6C){7} (?&S6) )";
/* Begins with :: */
enum IPV6_LEFT = "(?x: : (?&CS6){1,7} )";
/* :: somewhere in the middle - use negative lookahead to make sure there aren't too many colons in total */
enum IPV6_MID = "(?x: (?! (?: [[:xdigit:]]*: ){8} ) (?&S6C){1,6} (?&CS6){1,6} )";
/* Ends with :: */
enum IPV6_RIGHT = "(?x: (?&S6C){1,7} : )";
/* Is "::" and nothing more */
enum IPV6_null = "(?x: :: )";

/* The same ones for IPv4-embedded notation, without the actual IPv4 part */
enum IPV6V4_FULL = "(?x: (?&S6C){6} )";
enum IPV6V4_LEFT = "(?x: :: (?&S6C){0,5} )";  /* includes "::<ipv4>" */
enum IPV6V4_MID = "(?x: (?! (?: [[:xdigit:]]*: ){7} ) (?&S6C){1,4} (?&CS6){1,4} ) :";
enum IPV6V4_RIGHT = "(?x: (?&S6C){1,5} : )";

/* IPV6: An IPv6 address (possibly with an embedded IPv4).
 * This macro defines both IPV4 and IPV6, since the latter one requires the former. */
enum IP_DEF = IPV4_DEF ~ S6_DEF ~ "(?(DEFINE)(?<IPV6>(?x: (?: " ~ IPV6_null ~ " | " ~ IPV6_LEFT ~ " | " ~ IPV6_MID ~ " | " ~ IPV6_RIGHT ~ " | " ~ IPV6_FULL ~ " | (?: " ~ IPV6V4_FULL ~ " | " ~ IPV6V4_LEFT ~ " | " ~ IPV6V4_MID ~ " | " ~ IPV6V4_RIGHT ~ " ) (?&IPV4) ) (?! [.:[:xdigit:]] ) )))";

/* Either an alphanumeric character or dash; or if [negative lookahead] not ASCII
 * then any graphical Unicode character.
 * A segment can consist entirely of numbers.
 * (Note: PCRE doesn't support character class subtraction/intersection.) */
enum HOSTNAMESEGMENTCHARS_CLASS = "(?x: [-[:alnum:]] | (?! [[:ascii:]] ) [[:graph:]] )";

/* A hostname of at least 1 component. The last component cannot be entirely numbers.
 * E.g. "foo", "example.com", "1234.com", but not "foo.123" */
enum HOSTNAME1 = "(?x: (?: " ~ HOSTNAMESEGMENTCHARS_CLASS ~ "+ \\. )* " ~ HOSTNAMESEGMENTCHARS_CLASS ~ "* (?! [0-9] ) " ~ HOSTNAMESEGMENTCHARS_CLASS ~ "+ )";

/* A hostname of at least 2 components. The last component cannot be entirely numbers.
 * E.g. "example.com", "1234.com", but not "1234.56" */
enum HOSTNAME2 = "(?x: (?: " ~ HOSTNAMESEGMENTCHARS_CLASS ~ "+ \\.)+ " ~ HOSTNAME1 ~ " )";

/* For URL: Hostname, IPv4, or bracket-enclosed IPv6, e.g. "example.com", "1.2.3.4", "[::1]" */
enum URL_HOST = "(?x: " ~ HOSTNAME1 ~ " | (?&IPV4) | \\[ (?&IPV6) \\] )";

/* For e-mail: Hostname of at least two segments, or bracket-enclosed IPv4 or IPv6, e.g. "example.com", "[1.2.3.4]", "[::1]".
 * Technically an e-mail with a single-component hostname might be valid on a local network, but let's avoid tons of false positives (e.g. in a typical shell prompt). */
enum EMAIL_HOST = "(?x: " ~ HOSTNAME2 ~ " | \\[ (?: (?&IPV4) | (?&IPV6) ) \\] )";

/* Number between 1 and 65535, with lookahead at the end so that we don't match "6789" in the string "67890",
   and in turn we don't eventually match "http://host:6789" in "http://host:67890". */
enum N_1_65535 = "(?x: (?: [1-9][0-9]{0,3} | [1-5][0-9]{4} | 6[0-4][0-9]{3} | 65[0-4][0-9]{2} | 655[0-2][0-9] | 6553[0-5] ) (?! [0-9] ) )";

/* Optional colon-prefixed port, e.g. ":1080", "" */
enum PORT =  "(?x: \\:" ~ N_1_65535 ~ " )?";

enum PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,:;@&=?/~#|%\\E]";
/* Chars not to end a URL */
enum PATHNONTERM_CLASS = "[\\Q.!,?\\E]";

/* Lookbehind at the end, so that the last character (if we matched a character at all) is not from PATHTERM_CLASS */
enum URLPATH = "(?x: /" ~ PATHCHARS_CLASS ~ "* (?<! " ~ PATHNONTERM_CLASS ~ " ) )?";
enum VOIP_PATH = "(?x: [;?]" ~ PATHCHARS_CLASS ~ "* (?<! " ~ PATHNONTERM_CLASS ~ " ) )?";

/* Now let's put these fragments together */

enum DEFS = IP_DEF;

enum REGEX_URL_AS_IS  = DEFS ~ SCHEME ~ "://" ~ USERPASS ~ URL_HOST ~ PORT ~ URLPATH;
/* TODO: also support file:/etc/passwd */
enum REGEX_URL_FILE = DEFS ~ "(?ix: file:/ (?: / (?: " ~ HOSTNAME1 ~ " )? / )? (?! / ) )(?x: " ~ PATHCHARS_CLASS ~ "+ (?<! " ~ PATHNONTERM_CLASS ~ " ) )?";
/* Lookbehind so that we don't catch "abc.www.foo.bar", bug 739757. Lookahead for www/ftp for convenience (so that we can reuse HOSTNAME1). */
enum REGEX_URL_HTTP = DEFS ~ "(?<!(?:" ~ HOSTNAMESEGMENTCHARS_CLASS ~ "|[.]))(?=(?i:www|ftp))" ~ HOSTNAME1 ~ PORT ~ URLPATH;
enum REGEX_URL_VOIP = DEFS ~ "(?i:h323:|sips?:)" ~ USERPASS ~ URL_HOST ~ PORT ~ VOIP_PATH;
enum REGEX_EMAIL = DEFS ~ "(?i:mailto:)?" ~ USER ~ "@" ~ EMAIL_HOST;
enum REGEX_NEWS_MAN = "(?i:news:|man:|info:)[-[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+";

import std.regex.internal.thompson: ThompsonMatcher;

/**
 * This replaces all instances of $x tokens with values
 * from Regex match. The token $0 matches the whole match
 * whereas $1..$x are replaced with appropriate group match
 */
 string replaceMatchTokens(string tokenizedText, string[] matches) {
     string result = tokenizedText;
     foreach(i, match; matches) {
        result = result.replace("$" ~ to!string(i - 1), match);
     }
     return result;
 }

/**
 * Struct used to track matches in terminal for cases like context menu
 * where we need to preserve state between finding match and performing action
 */
struct TerminalURLMatch {
    TerminalURLFlavor flavor;
    string match;
    int tag = -1;
    bool uri;

    void clear() {
        flavor = TerminalURLFlavor.AS_IS;
        match.length = 0;
        uri = false;
        tag = -1;
    }
}

enum TerminalURLFlavor {
    AS_IS,
    DEFAULT_TO_HTTP,
    VOIP_CALL,
    EMAIL,
    NUMBER,
    CUSTOM
};

struct TerminalRegex {
    string pattern;
    TerminalURLFlavor flavor;
    bool caseless;
    // Only used for custom regex
    string command;
}

/**
 * The list of regex patterns supported by the terminal
 */
immutable TerminalRegex[] URL_REGEX_PATTERNS = [
    TerminalRegex(REGEX_URL_AS_IS, TerminalURLFlavor.AS_IS, true),
    TerminalRegex(REGEX_URL_FILE, TerminalURLFlavor.AS_IS, true),
    TerminalRegex(REGEX_URL_HTTP, TerminalURLFlavor.DEFAULT_TO_HTTP, true),
    TerminalRegex(REGEX_URL_VOIP, TerminalURLFlavor.VOIP_CALL, true),
    TerminalRegex(REGEX_EMAIL, TerminalURLFlavor.EMAIL, true),
    TerminalRegex(REGEX_NEWS_MAN, TerminalURLFlavor.AS_IS, true)
];

immutable GRegex[URL_REGEX_PATTERNS.length] compiledGRegex;
immutable VRegex[URL_REGEX_PATTERNS.length] compiledVRegex;

GRegex compileGRegex(TerminalRegex regex) {
    if (regex.pattern.length == 0) return null;
    GRegexCompileFlags flags = GRegexCompileFlags.OPTIMIZE | regex.caseless ? GRegexCompileFlags.CASELESS : cast(GRegexCompileFlags) 0;
    if (checkVTEVersion(VTE_VERSION_REGEX_MULTILINE)) {
        flags = flags | GRegexCompileFlags.MULTILINE;
    }
    return new GRegex(regex.pattern, flags, cast(GRegexMatchFlags) 0);
}

VRegex compileVRegex(TerminalRegex regex) {
    if (regex.pattern.length == 0) return null;
    uint flags = PCRE2Flags.MULTILINE | PCRE2Flags.UTF | PCRE2Flags.NO_UTF_CHECK;
    if (regex.caseless) {
        flags |= PCRE2Flags.CASELESS;
    }
    return VRegex.newMatch(regex.pattern, -1, flags);
}

static this() {
    import std.exception : assumeUnique;

    if (checkVTEVersion(VTE_VERSION_REGEX)) {
        VRegex[URL_REGEX_PATTERNS.length] tempRegex;
        foreach (i, regex; URL_REGEX_PATTERNS) {
            tempRegex[i] = compileVRegex(regex);
        }
        compiledVRegex = assumeUnique(tempRegex);
    } else {
        GRegex[URL_REGEX_PATTERNS.length] tempRegex;
        foreach (i, regex; URL_REGEX_PATTERNS) {
            tempRegex[i] = compileGRegex(regex);
        }
        compiledGRegex = assumeUnique(tempRegex);
    }
}

unittest {
    /* SCHEME is case insensitive */
    assertMatchAnchored (SCHEME, "http",  ENTIRE);
    assertMatchAnchored (SCHEME, "HTTPS", ENTIRE);

    /* USER is nonempty, alphanumeric, dot, plus and dash */
    assertMatchAnchored (USER, "",              null);
    assertMatchAnchored (USER, "dr.john-smith", ENTIRE);
    assertMatchAnchored (USER, "abc+def@ghi",   "abc+def");

    /* PASS is optional colon-prefixed value, allowing quite some characters, but definitely not @ */
    assertMatchAnchored (PASS, "",          ENTIRE);
    assertMatchAnchored (PASS, "nocolon",   "");
    assertMatchAnchored (PASS, ":s3cr3T",   ENTIRE);
    assertMatchAnchored (PASS, ":$?#@host", ":$?#");

    /* Hostname of at least 1 component, containing at least one non-digit in at least one of the segments */
    assertMatchAnchored (HOSTNAME1, "example.com",       ENTIRE);
    assertMatchAnchored (HOSTNAME1, "a-b.c-d",           ENTIRE);
    assertMatchAnchored (HOSTNAME1, "a_b",               "a");    /* TODO: can/should we totally abort here? */
    assertMatchAnchored (HOSTNAME1, "déjà-vu.com",       ENTIRE);
    assertMatchAnchored (HOSTNAME1, "➡.ws",              ENTIRE);
    assertMatchAnchored (HOSTNAME1, "cömbining-áccents", ENTIRE);
    assertMatchAnchored (HOSTNAME1, "12",                null);
    assertMatchAnchored (HOSTNAME1, "12.34",             null);
    assertMatchAnchored (HOSTNAME1, "12.ab",             ENTIRE);
    //  assertMatchAnchored (HOSTNAME1, "ab.12",             null);  /* errr... could we fail here?? */

    /* Hostname of at least 2 components, containing at least one non-digit in at least one of the segments */
    assertMatchAnchored (HOSTNAME2, "example.com",       ENTIRE);
    assertMatchAnchored (HOSTNAME2, "example",           null);
    assertMatchAnchored (HOSTNAME2, "12",                null);
    assertMatchAnchored (HOSTNAME2, "12.34",             null);
    assertMatchAnchored (HOSTNAME2, "12.ab",             ENTIRE);
    assertMatchAnchored (HOSTNAME2, "ab.12",             null);
    //  assertMatchAnchored (HOSTNAME2, "ab.cd.12",          null);  /* errr... could we fail here?? */

    /* IPv4 segment (number between 0 and 255) */
    assertMatchAnchored (DEFS ~ "(?&S4)", "0",    ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "1",    ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "9",    ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "10",   ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "99",   ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "100",  ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "200",  ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "250",  ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "255",  ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&S4)", "256",  null);
    assertMatchAnchored (DEFS ~ "(?&S4)", "260",  null);
    assertMatchAnchored (DEFS ~ "(?&S4)", "300",  null);
    assertMatchAnchored (DEFS ~ "(?&S4)", "1000", null);
    assertMatchAnchored (DEFS ~ "(?&S4)", "",     null);
    assertMatchAnchored (DEFS ~ "(?&S4)", "a1b",  null);

    /* IPv4 addresses */
    assertMatchAnchored (DEFS ~ "(?&IPV4)", "11.22.33.44",    ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV4)", "0.1.254.255",    ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV4)", "75.150.225.300", null);
    assertMatchAnchored (DEFS ~ "(?&IPV4)", "1.2.3.4.5",      "1.2.3.4");  /* we could also bail out and not match at all */

    /* IPv6 addresses */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:::22",                           null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22::33:44::55:66",               null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "dead::beef",                        ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "faded::bee",                        null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "live::pork",                        null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::1",                               ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11::22:33::44",                     null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:::33",                        null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "dead:beef::192.168.1.1",            ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "192.168.1.1",                       null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77:87654",        null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22::33:45678",                   null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:192.168.1.12345", null);

    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77",              null);   /* no :: */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77:88",           ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77:88:99",        null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::11:22:33:44:55:66:77",            ENTIRE); /* :: at the start */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::11:22:33:44:55:66:77:88",         null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33::44:55:66:77",             ENTIRE); /* :: in the middle */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33::44:55:66:77:88",          null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77::",            ENTIRE); /* :: at the end */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77:88::",         null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::",                                ENTIRE); /* :: only */

    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:192.168.1.1",        null);   /* no :: */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:192.168.1.1",     ENTIRE);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66:77:192.168.1.1",  null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::11:22:33:44:55:192.168.1.1",      ENTIRE); /* :: at the start */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::11:22:33:44:55:66:192.168.1.1",   null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33::44:55:192.168.1.1",       ENTIRE); /* :: in the imddle */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33::44:55:66:192.168.1.1",    null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55::192.168.1.1",       ENTIRE); /* :: at the end(ish) */
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "11:22:33:44:55:66::192.168.1.1",    null);
    assertMatchAnchored (DEFS ~ "(?&IPV6)", "::192.168.1.1",                     ENTIRE); /* :: only(ish) */

    /* URL_HOST is either a hostname, or an IPv4 address, or a bracket-enclosed IPv6 address */
    assertMatchAnchored (DEFS ~ URL_HOST, "example",       ENTIRE);
    assertMatchAnchored (DEFS ~ URL_HOST, "example.com",   ENTIRE);
    assertMatchAnchored (DEFS ~ URL_HOST, "11.22.33.44",   ENTIRE);
    assertMatchAnchored (DEFS ~ URL_HOST, "[11.22.33.44]", null);
    assertMatchAnchored (DEFS ~ URL_HOST, "dead::be:ef",   "dead");  /* TODO: can/should we totally abort here? */
    assertMatchAnchored (DEFS ~ URL_HOST, "[dead::be:ef]", ENTIRE);

    /* EMAIL_HOST is either an at least two-component hostname, or a bracket-enclosed IPv[46] address */
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "example",        null);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "example.com",    ENTIRE);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "11.22.33.44",    null);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "[11.22.33.44]",  ENTIRE);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "[11.22.33.456]", null);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "dead::be:ef",    null);
    assertMatchAnchored (DEFS ~ EMAIL_HOST, "[dead::be:ef]",  ENTIRE);

    /* Number between 1 and 65535 (helper for port) */
    assertMatchAnchored (N_1_65535, "0",      null);
    assertMatchAnchored (N_1_65535, "1",      ENTIRE);
    assertMatchAnchored (N_1_65535, "10",     ENTIRE);
    assertMatchAnchored (N_1_65535, "100",    ENTIRE);
    assertMatchAnchored (N_1_65535, "1000",   ENTIRE);
    assertMatchAnchored (N_1_65535, "10000",  ENTIRE);
    assertMatchAnchored (N_1_65535, "60000",  ENTIRE);
    assertMatchAnchored (N_1_65535, "65000",  ENTIRE);
    assertMatchAnchored (N_1_65535, "65500",  ENTIRE);
    assertMatchAnchored (N_1_65535, "65530",  ENTIRE);
    assertMatchAnchored (N_1_65535, "65535",  ENTIRE);
    assertMatchAnchored (N_1_65535, "65536",  null);
    assertMatchAnchored (N_1_65535, "65540",  null);
    assertMatchAnchored (N_1_65535, "65600",  null);
    assertMatchAnchored (N_1_65535, "66000",  null);
    assertMatchAnchored (N_1_65535, "70000",  null);
    assertMatchAnchored (N_1_65535, "100000", null);
    assertMatchAnchored (N_1_65535, "",       null);
    assertMatchAnchored (N_1_65535, "a1b",    null);

    /* PORT is an optional colon-prefixed value */
    assertMatchAnchored (PORT, "",       ENTIRE);
    assertMatchAnchored (PORT, ":1",     ENTIRE);
    assertMatchAnchored (PORT, ":65535", ENTIRE);
    assertMatchAnchored (PORT, ":65536", "");     /* TODO: can/should we totally abort here? */

    /* TODO: add tests for PATHCHARS and PATHNONTERM; and/or URLPATH */
    assertMatchAnchored (URLPATH, "/ab/cd",       ENTIRE);
    assertMatchAnchored (URLPATH, "/ab/cd.html.", "/ab/cd.html");

    assertMatch (REGEX_URL_AS_IS, "There's no URL here http:/foo",               null);
    assertMatch (REGEX_URL_AS_IS, "Visit http://example.com for details",        "http://example.com");
    assertMatch (REGEX_URL_AS_IS, "Trailing dot http://foo/bar.html.",           "http://foo/bar.html");
    assertMatch (REGEX_URL_AS_IS, "Trailing ellipsis http://foo/bar.html...",    "http://foo/bar.html");
    assertMatch (REGEX_URL_AS_IS, "See <http://foo/bar>",                        "http://foo/bar");
    assertMatch (REGEX_URL_AS_IS, "<http://foo.bar/asdf.qwer.html>",             "http://foo.bar/asdf.qwer.html");
    assertMatch (REGEX_URL_AS_IS, "Go to http://192.168.1.1.",                   "http://192.168.1.1");
    assertMatch (REGEX_URL_AS_IS, "If not, see <http://www.gnu.org/licenses/>.", "http://www.gnu.org/licenses/");
    assertMatch (REGEX_URL_AS_IS, "<a href=\"http://foo/bar\">foo</a>",          "http://foo/bar");
    assertMatch (REGEX_URL_AS_IS, "<a href='http://foo/bar'>foo</a>",            "http://foo/bar");
    assertMatch (REGEX_URL_AS_IS, "<url>http://foo/bar</url>",                   "http://foo/bar");

    assertMatch (REGEX_URL_AS_IS, "http://",          null);
    assertMatch (REGEX_URL_AS_IS, "http://a",         ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://aa.",       "http://aa");
    assertMatch (REGEX_URL_AS_IS, "http://aa.b",      ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://aa.bb",     ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://aa.bb/c",   ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://aa.bb/cc",  ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://aa.bb/cc/", ENTIRE);

    assertMatch (REGEX_URL_AS_IS, "HtTp://déjà-vu.com:10000/déjà/vu", ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "HTTP://joe:sEcReT@➡.ws:1080",      ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "https://cömbining-áccents",        ENTIRE);

    assertMatch (REGEX_URL_AS_IS, "http://111.222.33.44",                ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://111.222.33.44/",               ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://111.222.33.44/foo",            ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://1.2.3.4:5555/xyz",             ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "https://[dead::beef]:12345/ipv6",     ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "https://[dead::beef:11.22.33.44]",    ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://1.2.3.4:",                     "http://1.2.3.4");  /* TODO: can/should we totally abort here? */
    assertMatch (REGEX_URL_AS_IS, "https://dead::beef/no-brackets-ipv6", "https://dead");    /* detto */
    assertMatch (REGEX_URL_AS_IS, "http://111.222.333.444/",             null);
    assertMatch (REGEX_URL_AS_IS, "http://1.2.3.4:70000",                "http://1.2.3.4");  /* TODO: can/should we totally abort here? */
    assertMatch (REGEX_URL_AS_IS, "http://[dead::beef:111.222.333.444]", null);

    /* Username, password */
    assertMatch (REGEX_URL_AS_IS, "http://joe@example.com",                 ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://user.name:sec.ret@host.name",     ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://joe:secret@[::1]",                ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://dudewithnopassword:@example.com", ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://safeguy:!#$%^&*@host",            ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http://invalidusername!@host",           "http://invalidusername");

    assertMatch (REGEX_URL_AS_IS, "http://ab.cd/ef?g=h&i=j|k=l#m=n:o=p", ENTIRE);
    assertMatch (REGEX_URL_AS_IS, "http:///foo",                         null);

    /* No scheme */
    assertMatch (REGEX_URL_HTTP, "www.foo.bar/baz",     ENTIRE);
    assertMatch (REGEX_URL_HTTP, "WWW3.foo.bar/baz",    ENTIRE);
    assertMatch (REGEX_URL_HTTP, "FTP.FOO.BAR/BAZ",     ENTIRE);  /* FIXME if no scheme is given and url starts with ftp, can we make the protocol ftp instead of http? */
    assertMatch (REGEX_URL_HTTP, "ftpxy.foo.bar/baz",   ENTIRE);
    //  assertMatch (REGEX_URL_HTTP, "ftp.123/baz",         null);  /* errr... could we fail here?? */
    assertMatch (REGEX_URL_HTTP, "foo.bar/baz",         null);
    assertMatch (REGEX_URL_HTTP, "abc.www.foo.bar/baz", null);
    assertMatch (REGEX_URL_HTTP, "uvwww.foo.bar/baz",   null);
    assertMatch (REGEX_URL_HTTP, "xftp.foo.bar/baz",    null);

    /* file:/ or file://(hostname)?/ */
    assertMatch (REGEX_URL_FILE, "file:",                null);
    assertMatch (REGEX_URL_FILE, "file:/",               ENTIRE);
    assertMatch (REGEX_URL_FILE, "file://",              null);
    assertMatch (REGEX_URL_FILE, "file:///",             ENTIRE);
    assertMatch (REGEX_URL_FILE, "file:////",            null);
    assertMatch (REGEX_URL_FILE, "file:etc/passwd",      null);
    assertMatch (REGEX_URL_FILE, "File:/etc/passwd",     ENTIRE);
    assertMatch (REGEX_URL_FILE, "FILE:///etc/passwd",   ENTIRE);
    assertMatch (REGEX_URL_FILE, "file:////etc/passwd",  null);
    assertMatch (REGEX_URL_FILE, "file://host.name",     null);
    assertMatch (REGEX_URL_FILE, "file://host.name/",    ENTIRE);
    assertMatch (REGEX_URL_FILE, "file://host.name/etc", ENTIRE);

    assertMatch (REGEX_URL_FILE, "See file:/.",             "file:/");
    assertMatch (REGEX_URL_FILE, "See file:///.",           "file:///");
    assertMatch (REGEX_URL_FILE, "See file:/lost+found.",   "file:/lost+found");
    assertMatch (REGEX_URL_FILE, "See file:///lost+found.", "file:///lost+found");

    /* Email */
    assertMatch (REGEX_EMAIL, "Write to foo@bar.com.",        "foo@bar.com");
    assertMatch (REGEX_EMAIL, "Write to <foo@bar.com>",       "foo@bar.com");
    assertMatch (REGEX_EMAIL, "Write to mailto:foo@bar.com.", "mailto:foo@bar.com");
    assertMatch (REGEX_EMAIL, "Write to MAILTO:FOO@BAR.COM.", "MAILTO:FOO@BAR.COM");
    assertMatch (REGEX_EMAIL, "Write to foo@[1.2.3.4]",       "foo@[1.2.3.4]");
    assertMatch (REGEX_EMAIL, "Write to foo@[1.2.3.456]",     null);
    assertMatch (REGEX_EMAIL, "Write to foo@[1::2345]",       "foo@[1::2345]");
    assertMatch (REGEX_EMAIL, "Write to foo@[dead::beef]",    "foo@[dead::beef]");
    assertMatch (REGEX_EMAIL, "Write to foo@1.2.3.4",         null);
    assertMatch (REGEX_EMAIL, "Write to foo@1.2.3.456",       null);
    assertMatch (REGEX_EMAIL, "Write to foo@1::2345",         null);
    assertMatch (REGEX_EMAIL, "Write to foo@dead::beef",      null);
    assertMatch (REGEX_EMAIL, "<baz email=\"foo@bar.com\"/>", "foo@bar.com");
    assertMatch (REGEX_EMAIL, "<baz email='foo@bar.com'/>",   "foo@bar.com");
    assertMatch (REGEX_EMAIL, "<email>foo@bar.com</email>",   "foo@bar.com");

    /* Sip, examples from rfc 3261 */
    assertMatch (REGEX_URL_VOIP, "sip:alice@atlanta.com;maddr=239.255.255.1;ttl=15",           ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sip:alice@atlanta.com",                                      ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sip:alice:secretword@atlanta.com;transport=tcp",             ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sips:alice@atlanta.com?subject=project%20x&priority=urgent", ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sip:+1-212-555-1212:1234@gateway.com;user=phone",            ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sips:1212@gateway.com",                                      ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sip:alice@192.0.2.4",                                        ENTIRE);
    assertMatch (REGEX_URL_VOIP, "sip:atlanta.com;method=REGISTER?to=alice%40atlanta.com",     ENTIRE);
    assertMatch (REGEX_URL_VOIP, "SIP:alice;day=tuesday@atlanta.com",                          ENTIRE);
    assertMatch (REGEX_URL_VOIP, "Dial sip:alice@192.0.2.4.",                                  "sip:alice@192.0.2.4");

    /* Extremely long match, bug 770147 */
    assertMatch (REGEX_URL_AS_IS, "http://www.example.com/ThisPathConsistsOfMoreThan1024Characters" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890" ~
                                    "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", ENTIRE);

}

private:

    enum ENTIRE = "ENTIRE";

    void assertMatch(string pattern, string search, string expected) {
        string value = getMatch(pattern, search);
        if (expected == ENTIRE) {
            assert(value == search);
        } else {
            assert(value == expected);
        }
    }

    void assertMatchAnchored(string pattern, string search, string expected) {
        string value = getMatch(pattern, search, GRegexCompileFlags.ANCHORED, cast(GRegexMatchFlags)0);
        if (expected == ENTIRE) {
            assert(value == search);
        } else {
            assert(value == expected);
        }
    }

    string getMatch(string pattern, string search) {
        return getMatch(pattern, search, cast(GRegexCompileFlags)0, cast(GRegexMatchFlags)0);
    }

    string getMatch(string pattern, string search, GRegexCompileFlags compileFlags, GRegexMatchFlags matchFlags) {
        GRegex regex = new GRegex(pattern, compileFlags, matchFlags);
        MatchInfo match;
        regex.match(search, matchFlags, match);
        if (match.matches && match.getMatchCount() == 1) return match.fetch(0);
        else return null;
    }