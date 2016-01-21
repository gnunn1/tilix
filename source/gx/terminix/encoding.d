/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.terminix.encoding;

import gx.i18n.l10n;

/**
 * Hashmap of encodings
 */
string[string] lookupEncoding;

/**
 * Array of available encodings
 */
string[2][] encodings = [
       ["ISO-8859-1",	"Western"], 
       ["ISO-8859-2",	"Central European"], 
       ["ISO-8859-3",	"South European"], 
       ["ISO-8859-4",	"Baltic"], 
       ["ISO-8859-5",	"Cyrillic"], 
       ["ISO-8859-6",	"Arabic"], 
       ["ISO-8859-7",	"Greek"], 
       ["ISO-8859-8",	"Hebrew Visual"], 
       ["ISO-8859-8-I",	"Hebrew"], 
       ["ISO-8859-9",	"Turkish"], 
       ["ISO-8859-10",	"Nordic"], 
       ["ISO-8859-13",	"Baltic"], 
       ["ISO-8859-14",	"Celtic"], 
       ["ISO-8859-15",	"Western"], 
       ["ISO-8859-16",	"Romanian"], 
       ["UTF-8",        "Unicode"], 
       ["ARMSCII-8",    "Armenian"], 
       ["BIG5",	        "Chinese Traditional"], 
       ["BIG5-HKSCS",	"Chinese Traditional"], 
       ["CP866",	    "Cyrillic/Russian"], 
       ["EUC-JP",	    "Japanese"], 
       ["EUC-KR",	    "Korean"], 
       ["EUC-TW",	    "Chinese Traditional"], 
       ["GB18030",	    "Chinese Simplified"], 
       ["GB2312",	    "Chinese Simplified"], 
       ["GBK",	        "Chinese Simplified"], 
       ["GEORGIAN-PS",	"Georgian"], 
       ["IBM850",	    "Western"], 
       ["IBM852",	    "Central European"], 
       ["IBM855",	    "Cyrillic"], 
       ["IBM857",	    "Turkish"], 
       ["IBM862",	    "Hebrew"], 
       ["IBM864",	    "Arabic"], 
       ["ISO-2022-JP",	"Japanese"], 
       ["ISO-2022-KR",	"Korean"], 
       ["ISO-IR-111",	"Cyrillic"], 
       ["KOI8-R",	    "Cyrillic"], 
       ["KOI8-U",	    "Cyrillic/Ukrainian"], 
       ["MAC_ARABIC",	"Arabic"], 
       ["MAC_CE",	    "Central European"], 
       ["MAC_CROATIAN",	"Croatian"], 
       ["MAC-CYRILLIC",	"Cyrillic"], 
       ["MAC_DEVANAGARI","Hindi"], 
       ["MAC_FARSI",	    "Persian"], 
       ["MAC_GREEK",	    "Greek"], 
       ["MAC_GUJARATI",	"Gujarati"], 
       ["MAC_GURMUKHI",	"Gurmukhi"], 
       ["MAC_HEBREW",	"Hebrew"], 
       ["MAC_ICELANDIC",	"Icelandic"], 
       ["MAC_ROMAN",	    "Western"], 
       ["MAC_ROMANIAN",	"Romanian"], 
       ["MAC_TURKISH",	"Turkish"], 
       ["MAC_UKRAINIAN",	"Cyrillic/Ukrainian"], 
       ["SHIFT_JIS",	    "Japanese"], 
       ["TCVN",	        "Vietnamese"], 
       ["TIS-620",	    "Thai"], 
       ["UHC",	        "Korean"], 
       ["VISCII",	    "Vietnamese"], 
       ["WINDOWS-1250",	"Central European"], 
       ["WINDOWS-1251",	"Cyrillic"], 
       ["WINDOWS-1252",	"Western"], 
       ["WINDOWS-1253",	"Greek"], 
       ["WINDOWS-1254",	"Turkish"], 
       ["WINDOWS-1255",	"Hebrew"], 
       ["WINDOWS-1256",	"Arabic"], 
       ["WINDOWS-1257",	"Baltic"], 
       ["WINDOWS-1258",	"Vietnamese"]  
    ];

static this() {
    foreach(encoding; encodings) {
        lookupEncoding[encoding[0]] = encoding[1];
    }
}