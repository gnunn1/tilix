/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module gx.gtk.tablabel;

import gtk.Button;
import gtk.Box;
import gtk.Label;
import gtk.Widget;

alias OnCloseClickedDelegate = void delegate(TabLabel label, Widget Page);

/**
 * This is a tab label that supports having a close button.
 */
class TabLabel : Box {

private:
    Button button;
    Label label;
    Widget page;

    OnCloseClickedDelegate[] closeClickedHandlers;

    void closeClicked(Button button) {
        foreach (OnCloseClickedDelegate handler; closeClickedHandlers) {
            handler(this, page);
        }
    }

public:

    this(string text, Widget page) {
        super(Orientation.HORIZONTAL, 5);

        this.page = page;

        label = new Label(text);
        label.setHexpand(true);
        add(label);

        button = new Button("window-close-symbolic", IconSize.MENU);
        button.setRelief(ReliefStyle.NONE);
        button.setFocusOnClick(false);

        button.addOnClicked(&closeClicked);

        add(button);

        showAll();
    }

    /**
	 * Handler that is invoked when close button is clicked. It is
	 * up to the application to listen to this event and actually remove
	 * the tab.
	 */
    void addOnCloseClicked(OnCloseClickedDelegate handler) {
        closeClickedHandlers ~= handler;
    }

    @property string text() {
        return label.getText();
    }

    @property void text(string value) {
        label.setText(value);
    }
}
