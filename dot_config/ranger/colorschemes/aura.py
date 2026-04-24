from __future__ import absolute_import, division, print_function

from ranger.gui.color import (
    black,
    blue,
    bold,
    cyan,
    default,
    default_colors,
    dim,
    green,
    magenta,
    normal,
    red,
    reverse,
    white,
    yellow,
)
from ranger.gui.colorscheme import ColorScheme


class Scheme(ColorScheme):
    progress_bar_color = 208

    def use(self, context):  # pylint: disable=too-many-branches,too-many-statements
        fg, bg, attr = default_colors

        if context.reset:
            return default_colors

        if context.in_browser:
            fg = 250
            attr = normal

            if context.border:
                fg = 238

            if context.empty or context.error:
                fg = 231
                bg = 124
                attr = bold

            if context.directory:
                fg = 109
                attr |= bold
            elif context.executable and not any(
                (context.media, context.container, context.fifo, context.socket)
            ):
                fg = 142
                attr |= bold

            if context.media:
                fg = 178 if context.image else 175
            if context.container:
                fg = 208
            if context.socket:
                fg = 175
                attr |= bold
            if context.fifo or context.device:
                fg = 178
                attr |= bold if context.device else normal
            if context.link:
                fg = 109 if context.good else 124
                attr |= bold
            if context.tag_marker and not context.selected:
                fg = 208
                attr |= bold
            if not context.selected and (context.cut or context.copied):
                fg = 244
                attr |= dim

            if context.main_column:
                if context.marked:
                    fg = 178
                    attr |= bold
                if context.selected:
                    fg = 235
                    bg = 208
                    attr = bold

            if context.badinfo:
                fg = 124
                attr |= bold

            if context.inactive_pane:
                fg = 244

        elif context.in_titlebar:
            fg = 250
            attr = bold
            if context.hostname:
                fg = 124 if context.bad else 142
            elif context.directory:
                fg = 109
            elif context.tab:
                fg = 235
                bg = 208 if context.good else 238
            elif context.link:
                fg = 109

        elif context.in_statusbar:
            fg = 250
            if context.permissions:
                fg = 109 if context.good else 124
                attr |= bold if context.bad else normal
            if context.marked:
                fg = 235
                bg = 178
                attr |= bold
            if context.frozen:
                fg = 235
                bg = 109
                attr |= bold
            if context.message:
                fg = 124 if context.bad else 250
                attr |= bold if context.bad else normal
            if context.loaded:
                fg = 235
                bg = self.progress_bar_color
            if context.vcsinfo:
                fg = 109
                attr &= ~bold
            if context.vcscommit:
                fg = 178
                attr &= ~bold
            if context.vcsdate:
                fg = 244
                attr &= ~bold

        if context.text and context.highlight:
            attr |= reverse

        if context.in_taskview:
            fg = 250
            if context.title:
                fg = 109
                attr |= bold
            if context.selected:
                fg = 235
                bg = 208
                attr |= bold
            if context.loaded:
                bg = self.progress_bar_color

        if context.vcsfile and not context.selected:
            attr &= ~bold
            if context.vcsconflict:
                fg = magenta
            elif context.vcsuntracked:
                fg = cyan
            elif context.vcschanged or context.vcsunknown:
                fg = red
            elif context.vcsstaged or context.vcssync:
                fg = green
            elif context.vcsignored:
                fg = default

        elif context.vcsremote and not context.selected:
            attr &= ~bold
            if context.vcssync or context.vcsnone:
                fg = green
            elif context.vcsbehind:
                fg = red
            elif context.vcsahead:
                fg = blue
            elif context.vcsdiverged:
                fg = magenta
            elif context.vcsunknown:
                fg = yellow

        return fg, bg, attr
