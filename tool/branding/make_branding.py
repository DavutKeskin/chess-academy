#!/usr/bin/env python3
"""Marka görsellerini üretir (ImageMagick `convert` gerekir).

Çıktılar: assets/branding/{icon,icon_foreground,icon_background,splash}.png,
store/icon_512.png, store/feature_graphic_1024x500.png ve kaynak SVG tool/branding/king_cap.svg.
Sonra: flutter pub run flutter_launcher_icons && flutter pub run flutter_native_splash:create
"""
import os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'branding')
STORE = os.path.join(ROOT, 'store')
HERE = os.path.dirname(os.path.abspath(__file__))
NAVY, NAVY_DARK, GOLD, GOLD_LIGHT, GOLD_DARK = '#1F3A5F', '#16304F', '#E9A825', '#F6C954', '#C98E14'

CROWN = ('<path fill="#fff" stroke-linecap="butt" stroke-linejoin="miter" d="M22.5 25s4.5-7.5 3-10.5c0 0-1-2.5-3-2.5s-3 2.5-3 2.5c-1.5 3 3 10.5 3 10.5"/>'
         '<path fill="#fff" d="M11.5 37c5.5 3.5 15.5 3.5 21 0v-7s9-4.5 6-10.5c-4-6.5-13.5-3.5-16 4V27v-3.5c-3.5-7.5-13-10.5-16-4-3 6 5 10 5 10z"/>'
         '<path d="M11.5 30c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0m-21 3.5c5.5-3 15.5-3 21 0"/>')
CRESCENT = '<path fill="#fff" stroke="#000" stroke-width="1.15" stroke-linejoin="round" d="M0.70 -3.53A3.6 3.6 0 1 0 2.97 2.03A3.05 3.05 0 1 1 0.70 -3.53Z"/>'


def cap(cx, cy, w=12.5, d=4.2, thick=1.5, rot=0):
    L, T, R, B = (-w, 0), (0, -d), (w, 0), (0, d)
    top = f'M{L[0]} {L[1]}L{T[0]} {T[1]}L{R[0]} {R[1]}L{B[0]} {B[1]}Z'
    side = f'M{L[0]} {L[1]}L{B[0]} {B[1]}L{R[0]} {R[1]}L{R[0]} {R[1]+thick}L{B[0]} {B[1]+thick}L{L[0]} {L[1]+thick}Z'
    skull = f'M-6 {d+thick-0.8}q6 4 12 0v3q-6 3.4-12 0z'
    return (f'<g transform="translate({cx} {cy}) rotate({rot})">'
            f'<path fill="{NAVY}" stroke="#000" stroke-width="1.2" stroke-linejoin="round" d="{skull}"/>'
            f'<path fill="{NAVY_DARK}" stroke="#000" stroke-width="1.2" stroke-linejoin="round" d="{side}"/>'
            f'<path fill="{NAVY}" stroke="#000" stroke-width="1.2" stroke-linejoin="round" d="{top}"/>'
            f'<circle r="1.0" fill="{GOLD}" stroke="#000" stroke-width="0.8"/>'
            f'</g>')


def tassel(x0, y0, xc, yc, x1, y1):
    cord = f'M{x0} {y0}Q{xc} {yc} {x1} {y1}'
    return (f'<g stroke-linecap="round">'
            f'<path fill="none" stroke="#000" stroke-width="2.4" d="{cord}"/>'
            f'<path fill="none" stroke="{GOLD}" stroke-width="1.3" d="{cord}"/>'
            f'<path fill="{GOLD}" stroke="#000" stroke-width="0.9" stroke-linejoin="round" d="M{x1-1.3} {y1}h2.6l0.7 4.2h-4z"/>'
            f'</g>')


def king_cap_svg():
    """Hilalli şah (taş setiyle aynı) + sağ üstte, şahtan ayrı, eğik duran kep."""
    import math
    CAP_X, CAP_Y, CAP_ROT, CAP_W, CAP_D = 35.2, 6.3, 22, 10.5, 3.5
    # Püskül: kepin ortasındaki düğmeden sağ köşeye, sonra aşağı sarkar (dünya koordinatları)
    a = math.radians(CAP_ROT)
    rx, ry = CAP_X + CAP_W * math.cos(a), CAP_Y + CAP_W * math.sin(a)
    body = (CROWN
            + '<path stroke="#000" stroke-width="1.6" stroke-linecap="round" d="M22.5 12.3L22.5 10.4"/>'
            + f'<g transform="translate(22.5 8.7) rotate(-55)">{CRESCENT}</g>'
            + cap(CAP_X, CAP_Y, w=CAP_W, d=CAP_D, thick=1.3, rot=CAP_ROT)
            + tassel(CAP_X, CAP_Y, rx, ry - 0.5, rx + 0.6, ry + 4.5))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 -1 50 41">'
            '<g fill="none" fill-rule="evenodd" stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5">'
            + body + '</g></svg>')


def run(*args):
    subprocess.run(['convert', *args], check=True)


def main():
    svg_path = os.path.join(HERE, 'king_cap.svg')
    open(svg_path, 'w').write(king_cap_svg())
    tmp = tempfile.mkdtemp()
    king = os.path.join(tmp, 'king.png')          # şeffaf zemin, 620 px
    run('-background', 'none', '-density', '600', svg_path, '-resize', '690x690', king)
    shadow = os.path.join(tmp, 'shadow.png')
    run(king, '-fill', 'black', '-colorize', '100', '-alpha', 'on', '-channel', 'A', '-evaluate', 'multiply', '0.35', '+channel', '-blur', '0x14', shadow)

    # Altın madalyon: radyal geçiş + koyu kenar halkası, 720 px
    disc = os.path.join(tmp, 'disc.png')
    mask = os.path.join(tmp, 'mask.png')
    run('-size', '720x720', 'xc:none', '-fill', 'white', '-draw', 'circle 360,360 360,8', mask)
    run('-size', '720x720', f'radial-gradient:{GOLD_LIGHT}-{GOLD}', mask, '-alpha', 'off', '-compose', 'CopyOpacity', '-composite',
        '-compose', 'Over', '-fill', 'none', '-stroke', GOLD_DARK, '-strokewidth', '14', '-draw', 'circle 360,360 360,14', disc)

    def compose(base, out, king_y=-30, disc_scale=1.0, king_scale=1.0):
        d = os.path.join(tmp, 'd.png'); k = os.path.join(tmp, 'k.png'); s = os.path.join(tmp, 's.png')
        run(disc, '-resize', f'{int(720*disc_scale)}x{int(720*disc_scale)}', d)
        run(king, '-resize', f'{int(690*king_scale)}x{int(690*king_scale)}', k)
        run(shadow, '-resize', f'{int(690*king_scale)}x{int(690*king_scale)}', s)
        run(base, d, '-gravity', 'center', '-composite',
            s, '-gravity', 'center', '-geometry', f'+8+{king_y+16}', '-composite',
            k, '-gravity', 'center', '-geometry', f'+0+{king_y}', '-composite', out)

    base = os.path.join(tmp, 'base.png')
    run('-size', '1024x1024', 'xc:none', '-fill', NAVY, '-draw', 'roundrectangle 0,0 1023,1023 224,224', base)
    compose(base, os.path.join(OUT, 'icon.png'))
    run(os.path.join(OUT, 'icon.png'), '-resize', '512x512', os.path.join(STORE, 'icon_512.png'))
    # Ana sayfa başlığındaki logo (uygulama içi, 52 dp): 1x/2x/3x.
    logo = os.path.join(ROOT, 'assets', 'logo')
    # İkondaki altın madalyon (lacivert kare zemin olmadan), yuvarlak kırpılır.
    medal = os.path.join(OUT, '_medal.png')
    run(os.path.join(OUT, 'icon.png'), '-crop', '716x716+154+154', '+repage',
        '(', '-size', '716x716', 'xc:none', '-fill', 'white', '-draw', 'circle 358,358 358,2', ')',
        '-compose', 'DstIn', '-composite', medal)
    for sub, px in (('', 44), ('2.0x', 88), ('3.0x', 132)):
        os.makedirs(os.path.join(logo, sub), exist_ok=True)
        run(medal, '-resize', f'{px}x{px}', os.path.join(logo, sub, 'logo.png'))
    os.remove(medal)

    # Adaptive: arka plan lacivert + madalyon, ön plan yalnızca şah (güvenli bölge %66 → 0.72 ölçek)
    run('-size', '1024x1024', f'xc:{NAVY}', disc, '-gravity', 'center', '-composite', os.path.join(OUT, 'icon_background.png'))
    fg = os.path.join(tmp, 'fg.png')
    run('-size', '1024x1024', 'xc:none', fg)
    run(fg, '(', shadow, '-resize', '470x470', ')', '-gravity', 'center', '-geometry', '+8-14', '-composite',
        '(', king, '-resize', '470x470', ')', '-gravity', 'center', '-geometry', '+0-30', '-composite', os.path.join(OUT, 'icon_foreground.png'))
    # Splash: şeffaf zeminde şah (renk pubspec'te)
    run('-size', '1024x1024', 'xc:none', '(', king, '-resize', '520x520', ')', '-gravity', 'center', '-composite', os.path.join(OUT, 'splash.png'))

    # Tanıtım görseli 1024x500
    fgph = os.path.join(STORE, 'feature_graphic_1024x500.png')
    run('-size', '1024x500', f'xc:{NAVY}',
        '-fill', 'none', '-stroke', GOLD, '-strokewidth', '5', '-draw', 'circle 880,150 880,-40',
        '-strokewidth', '3', '-draw', 'circle 880,150 880,-100',
        '(', king, '-resize', '300x300', ')', '-gravity', 'northwest', '-geometry', '+690+120', '-composite',
        '-stroke', 'none', '-fill', 'white', '-font', 'DejaVu-Sans-Bold', '-pointsize', '72', '-gravity', 'northwest', '-annotate', '+70+130', 'Satranç Akademi',
        '-fill', '#DCE6F5', '-font', 'DejaVu-Sans', '-pointsize', '30', '-annotate', '+70+215', 'Çocuklar için Türkçe satranç okulu',
        '-fill', GOLD, '-stroke', 'none', '-draw', 'roundrectangle 70,288 440,332 22,22',
        '-fill', NAVY, '-font', 'DejaVu-Sans-Bold', '-pointsize', '26', '-annotate', '+92+296', '20 ders · 700+ bulmaca',
        '-fill', '#DCE6F5', '-font', 'DejaVu-Sans', '-pointsize', '24', '-annotate', '+70+385', 'Dersler  •  Bulmacalar  •  Bilgisayara karşı oyun  •  Oyun analizi',
        fgph)
    print('ok', OUT, STORE)


if __name__ == '__main__':
    main()
