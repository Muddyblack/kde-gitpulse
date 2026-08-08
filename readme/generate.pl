#!/usr/bin/env perl
#
# Draws the README artwork.
#
#   perl readme/generate.pl
#
# These are illustrations of the real UI, not screenshots: SVG stays crisp at
# any zoom and diffs as text. They are generated rather than hand-drawn so the
# heatmap and the 90-day strips (hundreds of rects each) stay consistent, and
# so a palette change is one edit rather than five.
#
# Glyph paths are copied from hyprland/Icons.js — same artwork as the widget.

use strict;
use warnings;
use MIME::Base64 qw(encode_base64);

my $DIR = do { my $d = $0; $d =~ s{/[^/]+$}{}; $d };
my $AVATAR = do {
    open my $fh, '<:raw', "$DIR/70057554.png" or die "$DIR/70057554.png: $!";
    local $/;
    'data:image/png;base64,' . encode_base64(<$fh>, '');
};

# ── palette ──────────────────────────────────────────────────────────────────
my %C = (
    bg_top   => '#191c23',
    bg_bot   => '#101318',
    surface  => '#1e222a',
    text     => '#e8eaf0',
    dim      => '#9aa2b4',
    faint    => '#6b7386',
    line     => 'rgba(255,255,255,0.08)',
    edge     => 'rgba(255,255,255,0.10)',
    sheen    => 'rgba(255,255,255,0.20)',
    accent   => '#3daee9',
    onaccent => '#0d1117',
    positive => '#3fb950',
    negative => '#f85149',
    neutral  => '#d29922',
);

my $UI   = 'system-ui,-apple-system,Segoe UI,sans-serif';
my $MONO = 'ui-monospace,SFMono-Regular,Menlo,monospace';

# ── glyphs (16×16, from Icons.js) ────────────────────────────────────────────
my %FILL = (
    github  => 'M8 0C3.58 0 0 3.58 0 8a8 8 0 0 0 5.47 7.59c.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82a7.5 7.5 0 0 1 4 0c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8 8 0 0 0 16 8c0-4.42-3.58-8-8-8Z',
    bell    => 'M8 16a2 2 0 0 0 1.985-1.75c.017-.137-.097-.25-.235-.25h-3.5c-.138 0-.252.113-.235.25A2 2 0 0 0 8 16ZM3 5a5 5 0 0 1 10 0v2.947c0 .05.015.098.042.139l1.703 2.555A1.519 1.519 0 0 1 13.482 13H2.518a1.516 1.516 0 0 1-1.263-2.36l1.703-2.554A.255.255 0 0 0 3 7.947Z',
    play    => 'M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Zm4.879-2.773 4.264 2.559a.25.25 0 0 1 0 .428l-4.264 2.559A.25.25 0 0 1 6 10.559V5.441a.25.25 0 0 1 .379-.214Z',
    pull    => 'M1.5 3.25a2.25 2.25 0 1 1 3 2.122v5.256a2.251 2.251 0 1 1-1.5 0V5.372A2.25 2.25 0 0 1 1.5 3.25Zm5.677-.177L9.573.677A.25.25 0 0 1 10 .854V2.5h1A2.5 2.5 0 0 1 13.5 5v5.628a2.251 2.251 0 1 1-1.5 0V5a1 1 0 0 0-1-1h-1v1.646a.25.25 0 0 1-.427.177L7.177 3.427a.25.25 0 0 1 0-.354ZM3.75 2.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm0 9.5a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Zm8.5 0a.75.75 0 1 0 0 1.5.75.75 0 0 0 0-1.5Z',
    issue   => 'M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Z',
    person  => 'M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0 1.5c-3 0-5.5 1.7-5.5 3.4V15h11v-2.1c0-1.7-2.5-3.4-5.5-3.4Z',
    search  => 'M10.68 11.74a6 6 0 1 1 1.06-1.06l3.04 3.04a.75.75 0 1 1-1.06 1.06ZM11.5 7a4.5 4.5 0 1 0-9 0 4.5 4.5 0 0 0 9 0Z',
    group   => 'M3 2a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Zm0 4.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3Zm0 4.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM6.4 2.7h8v1.6h-8Zm0 4.5h8v1.6h-8Zm0 4.5h8v1.6h-8Z',
    refresh => 'M8 2.5a5.487 5.487 0 0 0-4.131 1.869l1.204 1.204A.25.25 0 0 1 4.896 6H1.25A.25.25 0 0 1 1 5.75V2.104a.25.25 0 0 1 .427-.177l1.38 1.38A7.001 7.001 0 0 1 14.95 7.16a.75.75 0 1 1-1.49.178A5.5 5.5 0 0 0 8 2.5ZM1.705 8.005a.75.75 0 0 1 .834.656 5.5 5.5 0 0 0 9.592 2.97l-1.204-1.204a.25.25 0 0 1 .177-.427h3.646a.25.25 0 0 1 .25.25v3.646a.25.25 0 0 1-.427.177l-1.38-1.38A7.001 7.001 0 0 1 1.05 8.84a.75.75 0 0 1 .656-.834Z',
    check   => 'M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.751.751 0 0 1 1.06-1.06L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z',
    cross   => 'M3.72 3.72a.75.75 0 0 1 1.06 0L8 6.94l3.22-3.22a.75.75 0 1 1 1.06 1.06L9.06 8l3.22 3.22a.75.75 0 1 1-1.06 1.06L8 9.06l-3.22 3.22a.75.75 0 0 1-1.06-1.06L6.94 8 3.72 4.78a.75.75 0 0 1 0-1.06Z',
    ext     => 'M3.75 2h3.5a.75.75 0 0 1 0 1.5h-3.5a.25.25 0 0 0-.25.25v8.5c0 .138.112.25.25.25h8.5a.25.25 0 0 0 .25-.25v-3.5a.75.75 0 0 1 1.5 0v3.5A1.75 1.75 0 0 1 12.25 14h-8.5A1.75 1.75 0 0 1 2 12.25v-8.5C2 2.784 2.784 2 3.75 2Zm6.854-1h4.146a.25.25 0 0 1 .25.25v4.146a.75.75 0 0 1-1.5 0V2.75h-2.682l-5.36 5.36a.75.75 0 0 1-1.06-1.06l5.36-5.36Z',
    dot     => 'M8 4.4a3.6 3.6 0 1 1 0 7.2 3.6 3.6 0 0 1 0-7.2Z',
    comment => '',
);

my %STROKE = (
    pulse   => { d => 'M1 8h3l2.1-5.2L9.2 13l2-5H15', w => 1.5 },
    copilot => { d => 'M3 7.6a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v3a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3ZM8 5.6V3.9', w => 1.4 },
    gear    => { d => 'M8 3.4a4.6 4.6 0 1 0 0 9.2 4.6 4.6 0 0 0 0-9.2Z', w => 2 },
    close   => { d => 'M3.5 3.5 12.5 12.5M12.5 3.5 3.5 12.5', w => 1.8 },
    chevron => { d => 'm4 6.2 4 4 4-4', w => 1.7 },
    at      => { d => 'M10.5 8a2.5 2.5 0 1 0-2.5 2.5M10.5 8v1.3a2 2 0 0 0 4 0V8A6.5 6.5 0 1 0 11 13.7', w => 1.3 },
    merge   => { d => 'M4 4.9v6M5.7 3.4c3.3 0 4.6 1 4.8 3', w => 1.4 },
    clock   => { d => 'M8 1.6a6.4 6.4 0 1 0 0 12.8A6.4 6.4 0 0 0 8 1.6Zm0 2.8V8.3l2.5 1.6', w => 1.4 },
    mail    => { d => 'M1.7 6.4 8 2.1l6.3 4.3v6.1a1 1 0 0 1-1 1H2.7a1 1 0 0 1-1-1Zm0 0 6.3 4.3 6.3-4.3', w => 1.35 },
);
my %EXTRA = (
    gear  => { d => 'M8 1v1.8M8 13.2V15M1 8h1.8M13.2 8H15M3.05 3.05l1.25 1.25M11.7 11.7l1.25 1.25M12.95 3.05 11.7 4.3M4.3 11.7l-1.25 1.25', w => 2.6 },
    merge => { d => 'M4 1.5a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Zm0 9.6a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Zm8-6.5a1.7 1.7 0 1 0 0 3.4 1.7 1.7 0 0 0 0-3.4Z', w => 1.4 },
);

# ── primitives ───────────────────────────────────────────────────────────────

sub esc { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; return $s }

sub glyph {
    my (%a) = @_;
    my ($n, $x, $y, $s, $col) = @a{qw(name x y size color)};
    my $k = sprintf('%.4f', $s / 16);
    my $o = sprintf('<g transform="translate(%.2f,%.2f) scale(%s)">', $x, $y, $k);
    if (my $d = $FILL{$n}) {
        $o .= qq{<path d="$d" fill="$col"/>};
    }
    if (my $st = $STROKE{$n}) {
        $o .= qq{<path d="$st->{d}" fill="none" stroke="$col" stroke-width="$st->{w}" stroke-linecap="round" stroke-linejoin="round"/>};
    }
    if (my $ex = $EXTRA{$n}) {
        $o .= qq{<path d="$ex->{d}" fill="none" stroke="$col" stroke-width="$ex->{w}" stroke-linecap="round" stroke-linejoin="round"/>};
    }
    return $o . '</g>';
}

sub text {
    my (%a) = @_;
    my $anchor = $a{anchor} ? qq{ text-anchor="$a{anchor}"} : '';
    my $weight = $a{weight} ? qq{ font-weight="$a{weight}"} : '';
    my $family = $a{mono} ? $MONO : $UI;
    my $extra  = $a{extra} // '';
    return sprintf(
        '<text x="%.1f" y="%.1f" font-family="%s" font-size="%s" fill="%s"%s%s%s>%s</text>',
        $a{x}, $a{y}, $family, $a{size}, $a{color}, $weight, $anchor, $extra, esc($a{t}));
}

sub rect {
    my (%a) = @_;
    my $rx     = defined $a{rx} ? qq{ rx="$a{rx}"} : '';
    my $stroke = $a{stroke} ? qq{ stroke="$a{stroke}" stroke-width="}.($a{sw} // 1).'"' : '';
    my $op     = defined $a{opacity} ? qq{ fill-opacity="$a{opacity}"} : '';
    return sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"%s%s%s/>',
        $a{x}, $a{y}, $a{w}, $a{h}, $a{fill} // 'none', $rx, $op, $stroke);
}

sub circle {
    my (%a) = @_;
    my $op = defined $a{opacity} ? qq{ fill-opacity="$a{opacity}"} : '';
    return sprintf('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"%s/>', $a{cx}, $a{cy}, $a{r}, $a{fill}, $op);
}

sub avatar {
    my (%a) = @_;
    my $id = $a{id};
    my $x = $a{cx} - $a{r};
    my $y = $a{cy} - $a{r};
    my $d = $a{r} * 2;
    return join '',
        qq{<defs><clipPath id="$id"><circle cx="$a{cx}" cy="$a{cy}" r="$a{r}"/></clipPath></defs>},
        qq{<image href="$AVATAR" x="$x" y="$y" width="$d" height="$d" preserveAspectRatio="xMidYMid slice" clip-path="url(#$id)"/>},
        qq{<circle cx="$a{cx}" cy="$a{cy}" r="$a{r}" fill="none" stroke="$C{accent}" stroke-width="1"/>};
}

sub card {
    my ($w, $h) = @_;
    return join('',
        qq{<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">},
        qq{<stop offset="0%" stop-color="$C{bg_top}"/><stop offset="100%" stop-color="$C{bg_bot}"/>},
        qq{</linearGradient></defs>},
        rect(x => 0, y => 0, w => $w, h => $h, rx => 14, fill => 'url(#bg)'),
        rect(x => 0.5, y => 0.5, w => $w - 1, h => $h - 1, rx => 14, stroke => $C{edge}),
        qq{<path d="M14 1.5 H}.($w - 14).qq{" stroke="$C{sheen}" stroke-width="1"/>},
    );
}

# Pill with an optional glyph, returns (markup, width).
sub pill {
    my (%a) = @_;
    my $tw = length($a{t}) * 5.6;
    my $w  = $tw + ($a{glyph} ? 14 : 0) + 14;
    my $o  = rect(x => $a{x}, y => $a{y}, w => $w, h => 18, rx => 9, fill => $a{color}, opacity => 0.16);
    my $tx = $a{x} + 7;
    if ($a{glyph}) {
        $o .= glyph(name => $a{glyph}, x => $tx, y => $a{y} + 4, size => 10, color => $a{color});
        $tx += 14;
    }
    $o .= text(x => $tx, y => $a{y} + 12.5, size => 10, weight => 600, color => $a{color}, t => $a{t});
    return ($o, $w);
}

# ── shared chrome ────────────────────────────────────────────────────────────

sub header {
    my (%a) = @_;
    my $o = '';
    $o .= avatar(id => 'header-avatar', cx => 30, cy => 32, r => 16);
    $o .= text(x => 56, y => 29, size => 15, weight => 700, color => $C{text}, t => 'Gitpulse');
    $o .= sprintf(
        '<text x="56" y="45" font-family="%s" font-size="11.5" fill="%s">%s<tspan fill="%s" font-weight="700">%s</tspan>%s</text>',
        $UI, $C{dim}, 'Muddyblack · ', $C{accent}, $a{need}, esc($a{tail} // ''));

    my @tools = ('search', 'group', 'refresh', 'gear', 'close');
    my $x = 288;
    for my $t (@tools) {
        $o .= glyph(name => $t, x => $x, y => 25, size => 14, color => $C{dim});
        $x += 30;
    }
    return $o;
}

my @TABS = (
    { id => 'inbox',   icon => 'bell',    label => 'Inbox',   n => 2, tone => 'accent' },
    { id => 'actions', icon => 'play',    label => 'Actions', n => 1, tone => 'accent' },
    { id => 'pulls',   icon => 'pull',    label => 'Pulls',   n => 1, tone => 'accent' },
    { id => 'issues',  icon => 'issue',   label => 'Issues',  n => 3, tone => 'accent' },
    { id => 'profile', icon => 'person',  label => 'Profile', n => 0 },
    { id => 'copilot', icon => 'copilot', label => 'Copilot', n => 0 },
    { id => 'status',  icon => 'pulse',   label => 'Status',  n => 0 },
);

sub tabbar {
    my ($active, $w) = @_;
    my $o = '';
    my $activeW = 104;
    my $restW   = ($w - 28 - $activeW) / 6;
    my $x       = 14;

    for my $t (@TABS) {
        my $on = $t->{id} eq $active;
        my $tw = $on ? $activeW : $restW;
        my $cx = $x + $tw / 2;

        if ($on) {
            my $lw = length($t->{label}) * 6.6;
            my $gw = 15 + 5 + $lw + ($t->{n} ? 5 + 22 : 0);
            my $gx = $cx - $gw / 2;
            $o .= glyph(name => $t->{icon}, x => $gx, y => 68, size => 15, color => $C{text});
            $o .= text(x => $gx + 20, y => 80, size => 12, weight => 700, color => $C{text}, t => $t->{label});
            if ($t->{n}) {
                $o .= rect(x => $gx + 20 + $lw + 5, y => 68, w => 22, h => 15, rx => 7.5, fill => $C{accent});
                $o .= text(x => $gx + 20 + $lw + 16, y => 79.5, size => 10, weight => 700, color => $C{onaccent}, anchor => 'middle', t => $t->{n});
            }
            $o .= rect(x => $x + 4, y => 92, w => $tw - 8, h => 2.5, rx => 1.25, fill => $C{accent});
        } else {
            my $gw = 14 + ($t->{n} ? 4 + 20 : 0);
            my $gx = $cx - $gw / 2;
            $o .= glyph(name => $t->{icon}, x => $gx, y => 68.5, size => 14, color => $C{dim});
            if ($t->{n}) {
                $o .= rect(x => $gx + 18, y => 68.5, w => 20, h => 14, rx => 7, fill => $C{accent});
                $o .= text(x => $gx + 28, y => 79.5, size => 9.5, weight => 700, color => $C{onaccent}, anchor => 'middle', t => $t->{n});
            }
        }
        $x += $tw;
    }
    $o .= qq{<path d="M14 94.25 H}.($w - 14).qq{" stroke="$C{line}" stroke-width="1"/>};
    return $o;
}

sub chips {
    my ($y, @defs) = @_;
    my $o = '';
    my $x = 14;
    for my $d (@defs) {
        my $tw = length($d->{t}) * 6 + ($d->{n} ? 16 : 0) + 20;
        if ($d->{on}) {
            $o .= rect(x => $x, y => $y, w => $tw, h => 22, rx => 11, fill => $C{accent});
            $o .= text(x => $x + 10, y => $y + 15, size => 11, color => $C{onaccent}, t => $d->{t});
            $o .= text(x => $x + 12 + length($d->{t}) * 6, y => $y + 15, size => 10, weight => 700, mono => 1, color => $C{onaccent}, t => $d->{n}) if $d->{n};
        } else {
            $o .= rect(x => $x + 0.5, y => $y + 0.5, w => $tw - 1, h => 21, rx => 10.5, stroke => $C{line});
            $o .= text(x => $x + 10, y => $y + 15, size => 11, color => $C{dim}, t => $d->{t});
            $o .= text(x => $x + 12 + length($d->{t}) * 6, y => $y + 15, size => 10, weight => 700, mono => 1, color => $C{faint}, t => $d->{n}) if $d->{n};
        }
        $x += $tw + 6;
    }
    return $o;
}

sub divider {
    my ($y, $label, $accented) = @_;
    my $col = $accented ? $C{accent} : $C{faint};
    return text(x => 14, y => $y, size => 10, weight => 700, mono => 1, color => $col, t => $label,
        extra => ' letter-spacing="0.6"');
}

sub row {
    my (%a) = @_;
    my $y   = $a{y};
    my $tone = $a{tone};
    my $o = '';

    $o .= rect(x => 14, y => $y + 6, w => 3, h => 38, rx => 1.5, fill => $tone);
    $o .= circle(cx => 36, cy => $y + 22, r => 14, fill => $tone, opacity => 0.16);
    $o .= glyph(name => $a{icon}, x => 29, y => $y + 15, size => 14, color => $tone);

    $o .= text(x => 58, y => $y + 17, size => 13, weight => $a{bold} ? 700 : 400, color => $C{text}, t => $a{title});
    $o .= text(x => 58, y => $y + 35, size => 11, mono => 1, color => $C{dim}, t => $a{meta});

    my $mw = length($a{meta}) * 6.1;
    my ($p) = pill(x => 58 + $mw + 10, y => $y + 24, t => $a{state}, color => $tone, glyph => $a{stateIcon});
    $o .= $p;

    $o .= text(x => 426, y => $y + 17, size => 11, mono => 1, color => $C{faint}, anchor => 'end', t => $a{age});
    return $o;
}

sub footer {
    my ($w, $h, %a) = @_;
    my $y = $h - 20;
    my $o = '';
    $o .= circle(cx => 18, cy => $y, r => 3.5, fill => $C{positive});
    $o .= text(x => 28, y => $y + 4, size => 10.5, mono => 1, color => $C{faint}, t => $a{fresh} // 'updated 12s ago');
    $o .= rect(x => 250, y => $y - 2, w => 34, h => 4, rx => 2, fill => '#ffffff', opacity => 0.12);
    $o .= rect(x => 250, y => $y - 2, w => 31, h => 4, rx => 2, fill => $C{positive});
    $o .= text(x => 292, y => $y + 4, size => 10.5, mono => 1, color => $C{faint}, t => '4870');
    $o .= glyph(name => 'mail', x => 332, y => $y - 7, size => 13, color => $C{dim});
    $o .= text(x => 350, y => $y + 4, size => 11.5, color => $C{dim}, t => 'Mark all read');
    return $o;
}

sub write_svg {
    my ($name, $w, $h, $body) = @_;
    my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">\n}
        . card($w, $h) . "\n" . $body . "\n</svg>\n";
    open my $fh, '>', "$DIR/$name" or die "$DIR/$name: $!";
    print $fh $svg;
    close $fh;
    printf "  %-22s %5d bytes\n", $name, length($svg);
}

# ── inbox ────────────────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 380;
    my $b = header(need => '2 need you', tail => ' · 1 more');
    $b .= tabbar('inbox', $w);
    $b .= chips(106,
        { t => 'All',       n => 3, on => 1 },
        { t => 'Needs you', n => 2 },
        { t => 'Mentions',  n => 1 },
        { t => 'Unread',    n => 2 });
    $b .= divider(150, 'NEW SINCE YOU LAST LOOKED', 1);
    $b .= row(y => 158, tone => $C{accent}, icon => 'pull', bold => 1,
        title => 'Review requested: popup tab order',
        meta => 'muddyblack/gitpulse · #14', state => 'review', stateIcon => 'dot', age => '4m');
    $b .= row(y => 212, tone => $C{accent}, icon => 'at', bold => 1,
        title => '@muddyblack can you confirm the path?',
        meta => 'muddyblack/ai-usage · #42', state => 'mention', stateIcon => 'dot', age => '52m');
    $b .= divider(276, 'EARLIER');
    $b .= row(y => 284, tone => $C{faint}, icon => 'merge',
        title => 'PR merged: waybar cleanup',
        meta => 'muddyblack/dotfiles · #5', state => 'merged', stateIcon => 'check', age => '1d');
    $b .= footer($w, $h);
    write_svg('demo_inbox.svg', $w, $h, $b);
}

# ── actions ──────────────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 380;
    my $b = header(need => '2 need you', tail => ' · 1 more');
    $b .= tabbar('actions', $w);
    $b .= chips(106,
        { t => 'All',     n => 3, on => 1 },
        { t => 'Failed',  n => 1 },
        { t => 'Running', n => 1 });
    $b .= row(y => 140, tone => $C{negative}, icon => 'cross', bold => 1,
        title => 'flake-check · nix build',
        meta => 'muddyblack/nixos-config · main', state => 'failure', stateIcon => 'cross', age => '26m');
    $b .= row(y => 194, tone => $C{accent}, icon => 'refresh',
        title => 'build-plasmoid · package',
        meta => 'muddyblack/gitpulse · feat/tabs', state => 'running', stateIcon => 'refresh', age => '2m');

    # expanded drawer
    $b .= rect(x => 14, y => 248, w => $w - 28, h => 96, rx => 8, fill => $C{surface});
    my @facts = (['branch', 'feat/tabs'], ['job', 'package'], ['updated', '2m ago']);
    my $fy = 266;
    for my $f (@facts) {
        $b .= text(x => 28, y => $fy, size => 11, mono => 1, color => $C{faint}, t => $f->[0]);
        $b .= text(x => 86, y => $fy, size => 11.5, color => $C{dim}, t => $f->[1]);
        $fy += 16;
    }
    my $bx = 28;
    for my $btn (['Open', 'ext', 1], ['Pull request #12', 'pull', 0], ['Re-run', 'refresh', 0], ['Repository', 'issue', 0]) {
        my ($label, $ic, $primary) = @$btn;
        my $bw = length($label) * 6.1 + 32;
        if ($primary) {
            $b .= rect(x => $bx, y => 316, w => $bw, h => 22, rx => 8, fill => $C{accent});
            $b .= glyph(name => $ic, x => $bx + 9, y => 321.5, size => 12, color => $C{onaccent});
            $b .= text(x => $bx + 25, y => 331, size => 11.5, color => $C{onaccent}, t => $label);
        } else {
            $b .= rect(x => $bx + 0.5, y => 316.5, w => $bw - 1, h => 21, rx => 7.5, stroke => $C{line});
            $b .= glyph(name => $ic, x => $bx + 9, y => 321.5, size => 12, color => $C{text});
            $b .= text(x => $bx + 25, y => 331, size => 11.5, color => $C{text}, t => $label);
        }
        $bx += $bw + 6;
    }
    $b .= footer($w, $h);
    write_svg('demo_actions.svg', $w, $h, $b);
}

# ── profile ──────────────────────────────────────────────────────────────────
{
    my $w = 440; my $h = 590;
    my $b = header(need => '2 need you', tail => ' · 1 more');
    $b .= tabbar('profile', $w);

    # Identity and all eight counters share the top row on a normal-width
    # popup. This mirrors ProfilePane's compact header instead of using a
    # separate stats block below the avatar.
    $b .= avatar(id => 'profile-avatar', cx => 42, cy => 138, r => 28);
    $b .= text(x => 82, y => 125, size => 17, weight => 700, color => $C{text}, t => 'Christian');
    $b .= text(x => 82, y => 141, size => 11, mono => 1, color => $C{accent}, t => '@Muddyblack');
    $b .= text(x => 82, y => 157, size => 10, color => $C{faint}, t => 'Germany · joined 5y ago');

    my @stats = (
        ['31', 'stars'], ['487', 'commits'], ['67', 'PRs'], ['64', 'issues'],
        ['3', 'reviews'], ['39', 'repos'], ['3', 'followers'], ['2', 'orgs'],
    );
    for my $i (0 .. $#stats) {
        my $col = $i % 4;
        my $row = int($i / 4);
        my $sx = 242 + $col * 47;
        my $sy = 121 + $row * 27;
        $b .= text(x => $sx, y => $sy, size => 12, weight => 700, color => $C{text}, t => $stats[$i][0]);
        $b .= text(x => $sx, y => $sy + 11, size => 8.5, color => $C{faint}, t => $stats[$i][1]);
    }

    # Compact contribution summary: the detailed ring card no longer consumes
    # a full row, keeping the lower analytics and language legend in view.
    $b .= rect(x => 14, y => 172, w => $w - 28, h => 38, rx => 8, fill => $C{surface});
    my @streaks = (['1,293', 'contributions', $C{accent}], ['5', 'day streak', $C{text}], ['14', 'longest streak', $C{text}]);
    for my $i (0 .. $#streaks) {
        my $sx = 26 + $i * 136;
        $b .= text(x => $sx, y => 196, size => 16, weight => 700, color => $streaks[$i][2], t => $streaks[$i][0]);
        $b .= text(x => $sx + length($streaks[$i][0]) * 7 + 5, y => 196, size => 10, color => $C{dim}, t => $streaks[$i][1]);
    }

    # heatmap
    $b .= text(x => 14, y => 230, size => 11, weight => 700, color => $C{dim}, t => 'Contributions');
    $b .= text(x => 426, y => 230, size => 10, color => $C{faint}, anchor => 'end', t => '146 active days');
    my $seed = 12345;
    my $cell = 6.4; my $gap = 1.6;
    for my $col (0 .. 51) {
        for my $r (0 .. 6) {
            $seed = ($seed * 1103515245 + 12345) % 2147483648;
            my $v = $seed / 2147483648;
            my $lvl = $v < 0.34 ? 0 : $v < 0.6 ? 1 : $v < 0.8 ? 2 : $v < 0.93 ? 3 : 4;
            my $op = $lvl == 0 ? 0.07 : 0.18 + 0.205 * $lvl;
            my $fill = $lvl == 0 ? '#ffffff' : $C{accent};
            $b .= rect(x => 14 + $col * ($cell + $gap), y => 240 + $r * ($cell + $gap),
                w => $cell, h => $cell, rx => 1.6, fill => $fill, opacity => $op);
        }
    }
    $b .= text(x => 14, y => 306, size => 9, color => $C{faint}, t => 'plus 650 in private repositories');

    # trend
    $b .= text(x => 14, y => 328, size => 11, weight => 700, color => $C{dim}, t => 'Last 30 days');
    $b .= text(x => 426, y => 328, size => 10, color => $C{faint}, anchor => 'end', t => 'peak 112 · avg 3.5/day');
    my @pts;
    $seed = 99;
    for my $i (0 .. 29) {
        $seed = ($seed * 1103515245 + 12345) % 2147483648;
        my $v = ($seed / 2147483648) ** 2;
        push @pts, sprintf('%.1f,%.1f', 14 + $i * (412 / 29), 374 - $v * 30);
    }
    $b .= qq{<polyline points="14,374 } . join(' ', @pts) . qq{ 426,374" fill="$C{accent}" fill-opacity="0.18"/>};
    $b .= qq{<polyline points="} . join(' ', @pts) . qq{" fill="none" stroke="$C{accent}" stroke-width="1.6" stroke-linejoin="round"/>};

    # The compact rhythm rows and single-line language legend are deliberate:
    # both sit above the footer without requiring the profile pane to scroll.
    $b .= text(x => 14, y => 396, size => 11, weight => 700, color => $C{dim}, t => 'When I ship');
    $b .= text(x => 426, y => 396, size => 10, color => $C{faint}, anchor => 'end', t => 'public events, local time');
    my @rhythm = (['evening', 76], ['night', 15], ['afternoon', 5], ['morning', 4], ['day', 0]);
    for my $i (0 .. $#rhythm) {
        my $y = 408 + $i * 17;
        $b .= text(x => 78, y => $y + 8, size => 10, color => $C{dim}, anchor => 'end', t => $rhythm[$i][0]);
        $b .= rect(x => 86, y => $y, w => 310, h => 7, rx => 3.5, fill => '#ffffff', opacity => 0.07);
        $b .= rect(x => 86, y => $y, w => 310 * $rhythm[$i][1] / 76, h => 7, rx => 3.5, fill => $C{accent}, opacity => 0.68) if $rhythm[$i][1];
        $b .= text(x => 426, y => $y + 8, size => 9, mono => 1, color => $C{faint}, anchor => 'end', t => $rhythm[$i][1] . '%');
    }

    $b .= text(x => 14, y => 500, size => 11, weight => 700, color => $C{dim}, t => 'Languages');
    $b .= text(x => 426, y => 500, size => 10, color => $C{faint}, anchor => 'end', t => 'by bytes, own repositories');
    my @languages = (['Python', 23, '#3572a5'], ['TypeScript', 18, '#3178c6'], ['JavaScript', 15, '#f1e05a'], ['Nix', 13, '#7e7eff'], ['QML', 9, '#44a51c']);
    my $lx = 14;
    for my $lang (@languages) {
        my $lw = 412 * $lang->[1] / 100;
        $b .= rect(x => $lx, y => 509, w => $lw, h => 8, fill => $lang->[2]);
        $lx += $lw;
    }
    $lx = 14;
    for my $lang (@languages) {
        $b .= circle(cx => $lx + 3, cy => 534, r => 3, fill => $lang->[2]);
        $b .= text(x => $lx + 10, y => 537, size => 9, color => $C{dim}, t => $lang->[0] . ' ' . $lang->[1] . '%');
        $lx += length($lang->[0]) * 5.4 + 42;
    }

    $b .= footer($w, $h);
    write_svg('demo_profile.svg', $w, $h, $b);
}

# ── status ───────────────────────────────────────────────────────────────────
{
    # Six component rows need room above the persistent footer.
    my $w = 440; my $h = 430;
    my $b = header(need => '2 need you', tail => ' · 1 more');
    $b .= tabbar('status', $w);

    $b .= rect(x => 14, y => 108, w => $w - 28, h => 34, rx => 8, fill => $C{positive}, opacity => 0.12);
    $b .= rect(x => 14.5, y => 108.5, w => $w - 29, h => 33, rx => 8, stroke => 'rgba(63,185,80,0.35)');
    $b .= circle(cx => 32, cy => 125, r => 5, fill => $C{positive});
    $b .= text(x => 46, y => 129, size => 13, weight => 700, color => $C{text}, t => 'All Systems Operational');

    my ($cA, $cB) = (0, 0);
    ($cA, $cB) = (pill(x => 14, y => 152, t => 'Components', color => $C{accent}))[0, 1];
    $b .= rect(x => 14, y => 152, w => 92, h => 22, rx => 11, fill => $C{accent});
    $b .= text(x => 60, y => 167, size => 11, color => $C{onaccent}, anchor => 'middle', t => 'Components');
    $b .= rect(x => 112.5, y => 152.5, w => 79, h => 21, rx => 10.5, stroke => $C{line});
    $b .= text(x => 152, y => 167, size => 11, color => $C{dim}, anchor => 'middle', t => 'Incidents');
    $b .= text(x => 426, y => 167, size => 10, color => $C{faint}, anchor => 'end', t => '90 days · incident-free');

    my @svcs = (
        ['Git Operations', 0.02], ['API Requests', 0.09], ['Actions', 0.14],
        ['Pull Requests', 0.05], ['Webhooks', 0.06], ['Copilot', 0.08],
    );
    my $sy   = 190;
    my $seed = 4242;
    for my $s (@svcs) {
        $b .= circle(cx => 18, cy => $sy, r => 3.5, fill => $C{positive});
        $b .= text(x => 30, y => $sy + 4, size => 12, color => $C{text}, t => $s->[0]);
        $b .= text(x => 426, y => $sy + 4, size => 10, color => $C{positive}, anchor => 'end', t => 'operational');
        my $n = 90; my $cw = (412 - ($n - 1) * 0.8) / $n;
        for my $d (0 .. $n - 1) {
            $seed = ($seed * 1103515245 + 12345) % 2147483648;
            my $v = $seed / 2147483648;
            my ($fill, $op) = ($C{positive}, 0.35);
            if ($v < $s->[1] * 0.35) { ($fill, $op) = ($C{negative}, 1) }
            elsif ($v < $s->[1])     { ($fill, $op) = ($C{neutral},  1) }
            $b .= rect(x => 14 + $d * ($cw + 0.8), y => $sy + 10, w => $cw, h => 9, rx => 1, fill => $fill, opacity => $op);
        }
        $sy += 34;
    }
    $b .= footer($w, $h);
    write_svg('demo_status.svg', $w, $h, $b);
}

# ── panel ────────────────────────────────────────────────────────────────────
{
    my $w = 132; my $h = 44;
    my $svg = qq{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">\n};
    $svg .= rect(x => 0, y => 0, w => $w, h => $h, rx => 10, fill => 'rgba(20,22,27,0.85)');
    $svg .= rect(x => 0.5, y => 0.5, w => $w - 1, h => $h - 1, rx => 10, stroke => $C{edge});
    for my $i (0 .. 1) {
        $svg .= circle(cx => 20 + $i * 26, cy => 22, r => 8, fill => '#ffffff', opacity => 0.12);
    }
    $svg .= avatar(id => 'panel-avatar', cx => 78, cy => 22, r => 13);
    $svg .= circle(cx => 88, cy => 12, r => 8, fill => $C{accent});
    $svg .= text(x => 88, y => 15.5, size => 9.5, weight => 700, color => $C{onaccent}, anchor => 'middle', t => '5');
    $svg .= text(x => 112, y => 20, size => 10, mono => 1, color => $C{text}, anchor => 'middle', t => '09:41');
    $svg .= text(x => 112, y => 31, size => 7.5, mono => 1, color => $C{dim}, anchor => 'middle', t => 'Fri 8');
    $svg .= "\n</svg>\n";
    open my $fh, '>', "$DIR/panel.svg" or die $!;
    print $fh $svg; close $fh;
    printf "  %-22s %5d bytes\n", 'panel.svg', length($svg);
}

print "done\n";
