# mpv-specific widgets

This directory is reserved for widgets whose behavior or presentation is specific
to mpv/mpv.net. Such widgets must not be imported by the host-free core aggregates
until their host boundary and public contract are documented.

Current contents are experimental placeholders. Move reusable behavior into
`widget/widgets/` and inject host services through explicit callbacks or Define
modules instead of importing `mp` into framework layers.
