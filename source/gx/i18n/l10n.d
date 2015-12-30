/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.i18n.l10n;

/**
 * Preparation in case down the road D supports GNU gettext
 * and po files for translation
 */
string _(string text) {
	return text;
}
