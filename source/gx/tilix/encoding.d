/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.tilix.encoding;

import gx.i18n.l10n;

/**
 * Hashmap of encodings
 */
string[string] lookupEncoding;

/**
 * Array of available encodings
 */
string[2][] encodings = [
       ["ISO-8859-1",     N_("Western")],
       ["ISO-8859-2",     N_("Central European")],
       ["ISO-8859-3",     N_("South European")],
       ["ISO-8859-4",     N_("Baltic")],
       ["ISO-8859-5",     N_("Cyrillic")],
       ["ISO-8859-6",     N_("Arabic")],
       ["ISO-8859-7",     N_("Greek")],
       ["ISO-8859-8",     N_("Hebrew Visual")],
       ["ISO-8859-8-I",   N_("Hebrew")],
       ["ISO-8859-9",     N_("Turkish")],
       ["ISO-8859-10",    N_("Nordic")],
       ["ISO-8859-13",    N_("Baltic")],
       ["ISO-8859-14",    N_("Celtic")],
       ["ISO-8859-15",    N_("Western")],
       ["ISO-8859-16",    N_("Romanian")],
       ["UTF-8",          N_("Unicode")],
       ["ARMSCII-8",      N_("Armenian")],
       ["BIG5",           N_("Chinese Traditional")],
       ["BIG5-HKSCS",     N_("Chinese Traditional")],
       ["CP866",          N_("Cyrillic/Russian")],
       ["EUC-JP",         N_("Japanese")],
       ["EUC-KR",         N_("Korean")],
       ["EUC-TW",         N_("Chinese Traditional")],
       ["GB18030",        N_("Chinese Simplified")],
       ["GB2312",         N_("Chinese Simplified")],
       ["GBK",            N_("Chinese Simplified")],
       ["GEORGIAN-PS",    N_("Georgian")],
       ["IBM850",         N_("Western")],
       ["IBM852",         N_("Central European")],
       ["IBM855",         N_("Cyrillic")],
       ["IBM857",         N_("Turkish")],
       ["IBM862",         N_("Hebrew")],
       ["IBM864",         N_("Arabic")],
       ["ISO-2022-JP",    N_("Japanese")],
       ["ISO-2022-KR",    N_("Korean")],
       ["ISO-IR-111",     N_("Cyrillic")],
       ["KOI8-R",         N_("Cyrillic")],
       ["KOI8-U",         N_("Cyrillic/Ukrainian")],
       ["MAC_ARABIC",     N_("Arabic")],
       ["MAC_CE",         N_("Central European")],
       ["MAC_CROATIAN",   N_("Croatian")],
       ["MAC-CYRILLIC",   N_("Cyrillic")],
       ["MAC_DEVANAGARI", N_("Hindi")],
       ["MAC_FARSI",      N_("Persian")],
       ["MAC_GREEK",      N_("Greek")],
       ["MAC_GUJARATI",   N_("Gujarati")],
       ["MAC_GURMUKHI",   N_("Gurmukhi")],
       ["MAC_HEBREW",     N_("Hebrew")],
       ["MAC_ICELANDIC",  N_("Icelandic")],
       ["MAC_ROMAN",      N_("Western")],
       ["MAC_ROMANIAN",   N_("Romanian")],
       ["MAC_TURKISH",    N_("Turkish")],
       ["MAC_UKRAINIAN",  N_("Cyrillic/Ukrainian")],
       ["SHIFT_JIS",      N_("Japanese")],
       ["TCVN",           N_("Vietnamese")],
       ["TIS-620",        N_("Thai")],
       ["UHC",            N_("Korean")],
       ["VISCII",         N_("Vietnamese")],
       ["WINDOWS-1250",   N_("Central European")],
       ["WINDOWS-1251",   N_("Cyrillic")],
       ["WINDOWS-1252",   N_("Western")],
       ["WINDOWS-1253",   N_("Greek")],
       ["WINDOWS-1254",   N_("Turkish")],
       ["WINDOWS-1255",   N_("Hebrew")],
       ["WINDOWS-1256",   N_("Arabic")],
       ["WINDOWS-1257",   N_("Baltic")],
       ["WINDOWS-1258",   N_("Vietnamese")]
    ];

static this() {
    foreach(encoding; encodings) {
        lookupEncoding[encoding[0]] = encoding[1];
    }
}
