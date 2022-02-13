# Crier

A rudimentary [Desktop
Notifications](https://specifications.freedesktop.org/notification-spec/latest/ar01s02.html)
server optimised for mobile formfactors and touchscreen.

* Supports: summary, body, app-icon, actions, timeouts
* Does not support: action icons, images, markup in text, links
* Notifications are displayed in an overlay layer at the top of the screen
* Swipe a notification to dismiss it (TODO)

## TO DO

- swipe to cancel
- find out if actions are supposed to cancel
- test multi-paragraph body and markup
- implement "image-data", "image-path" https://specifications.freedesktop.org/notification-spec/latest/ar01s05.html (is this required? it needs a hint, so maybe not)
- "do not disturb" setting
- audible alerts?
- how does deployed script find css and xml?
