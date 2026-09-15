#!/usr/bin/env python3
"""Mağaza ekran görüntüleri: store/screenshots/raw/<dil>/NN_ad.png (telefon, 1080x2310) →
store/screenshots/<dil>/NN_ad.png (1080x1920, lacivert çerçeve + başlık). ImageMagick gerekir.

Kullanım: python3 tool/branding/make_screenshots.py tr   (varsayılan: raw altındaki tüm diller)
"""
import os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, 'store', 'screenshots', 'raw')
OUT = os.path.join(ROOT, 'store', 'screenshots')
NAVY, GOLD, CREAM = '#1F3A5F', '#E9A825', '#DCE6F5'
STATUS_BAR, NAV_BAR = 100, 112          # test telefonu, 1080x2310
W, H = 1080, 1920
SHOT_W, SHOT_Y = 880, 400               # çerçevedeki görüntü genişliği ve üst konumu

TEXT = {
    'tr': {
        '01_home': ('Çocuklar için\nsatranç okulu', 'Dersler, bulmacalar, akıllı rakip'),
        '02_lesson': ('20 etkileşimli ders', 'Tahtada görev yap, anında geri bildirim al'),
        '03_puzzle': ('700+ mat bulmacası', 'Kolaydan zora, her gün yeni bulmaca'),
        '04_play': ('5 seviyeli rakip', 'Stockfish motoru, tamamen çevrimdışı'),
        '05_analysis': ('Hatalarını gör,\ndaha iyisini öğren', 'Oyun sonunda hamle hamle analiz'),
        '06_settings': ('10 tahta, 9 taş seti', 'Uygulamaya özel Hilal seti'),
    },
    'en': {
        '01_home': ('Chess school\nfor kids', 'Lessons, puzzles, smart opponent'),
        '02_lesson': ('20 interactive lessons', 'Do tasks on the board, get instant feedback'),
        '03_puzzle': ('700+ mate puzzles', 'Easy to hard, a new puzzle every day'),
        '04_play': ('Opponent with 5 levels', 'Stockfish engine, fully offline'),
        '05_analysis': ('See your mistakes,\nlearn the better move', 'Move-by-move analysis after every game'),
        '06_settings': ('10 boards, 9 piece sets', 'Exclusive Crescent piece set'),
    },
    'de': {
        '01_home': ('Schachschule\nfür Kinder', 'Lektionen, Aufgaben, kluger Gegner'),
        '02_lesson': ('20 interaktive Lektionen', 'Aufgaben am Brett, sofortiges Feedback'),
        '03_puzzle': ('700+ Mattaufgaben', 'Von leicht bis schwer, täglich neu'),
        '04_play': ('Gegner mit 5 Stufen', 'Stockfish-Engine, komplett offline'),
        '05_analysis': ('Fehler erkennen,\nbesser spielen', 'Zug-für-Zug-Analyse nach jeder Partie'),
        '06_settings': ('10 Bretter, 9 Figurensätze', 'Exklusiver Halbmond-Figurensatz'),
    },
    'es': {
        '01_home': ('Escuela de ajedrez\npara niños', 'Lecciones, problemas, rival inteligente'),
        '02_lesson': ('20 lecciones interactivas', 'Tareas en el tablero, respuesta al instante'),
        '03_puzzle': ('700+ problemas de mate', 'De fácil a difícil, uno nuevo cada día'),
        '04_play': ('Rival con 5 niveles', 'Motor Stockfish, sin conexión'),
        '05_analysis': ('Ve tus errores,\naprende la mejor jugada', 'Análisis jugada a jugada tras cada partida'),
        '06_settings': ('10 tableros, 9 juegos de piezas', 'Juego de piezas Media Luna exclusivo'),
    },
}


def run(*a):
    subprocess.run(['convert', *a], check=True)


def frame(src, dst, title, sub):
    tmp = tempfile.mkdtemp()
    shot = os.path.join(tmp, 'shot.png')
    # durum ve gezinme çubuklarını kırp, ölçekle, üst köşeleri yuvarla
    run(src, '-crop', f'1080x{2310-STATUS_BAR-NAV_BAR}+0+{STATUS_BAR}', '+repage', '-resize', f'{SHOT_W}x', shot)
    sh_h = int(subprocess.check_output(['identify', '-format', '%h', shot]).decode())
    mask = os.path.join(tmp, 'mask.png')
    run('-size', f'{SHOT_W}x{sh_h}', 'xc:none', '-fill', 'white', '-draw', f'roundrectangle 0,0 {SHOT_W-1},{sh_h+60} 44,44', mask)
    run(shot, mask, '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', shot)
    lines = title.count('\n') + 1
    title_size = 74 if lines == 1 and len(title) <= 24 else 66
    run('-size', f'{W}x{H}', f'xc:{NAVY}',
        # arka plan altın halkalar
        '-fill', 'none', '-stroke', GOLD, '-strokewidth', '4', '-draw', f'circle 980,{H-120} 980,{H-420}',
        '-strokewidth', '2', '-draw', f'circle 980,{H-120} 980,{H-520}',
        '-stroke', 'none',
        '-font', 'DejaVu-Sans-Bold', '-pointsize', str(title_size), '-fill', 'white', '-gravity', 'north',
        '-interline-spacing', '-6', '-annotate', '+0+96', title,
        '-font', 'DejaVu-Sans', '-pointsize', '34', '-fill', CREAM, '-annotate', f'+0+{96 + title_size*1.2*lines + 26:.0f}', sub,
        # gölge + görüntü (alt kenardan taşar)
        '(', shot, '-alpha', 'extract', '-blur', '0x24', '-fill', 'black', '-colorize', '100', '-alpha', 'copy', '-channel', 'A', '-evaluate', 'multiply', '0.5', '+channel', ')',
        '-gravity', 'north', '-geometry', f'+0+{SHOT_Y+18}', '-compose', 'over', '-composite',
        shot, '-gravity', 'north', '-geometry', f'+0+{SHOT_Y}', '-composite',
        '-crop', f'{W}x{H}+0+0', '+repage', dst)


def main():
    if not os.path.isdir(RAW):
        sys.exit(f'Ham ekran görüntüsü klasörü yok: {RAW} (git dışı; telefondan alınan PNG\'leri <dil>/NN_ad.png olarak koy)')
    langs = sys.argv[1:] or sorted(d for d in os.listdir(RAW) if os.path.isdir(os.path.join(RAW, d)))
    for lang in langs:
        src_dir = os.path.join(RAW, lang); out_dir = os.path.join(OUT, lang); os.makedirs(out_dir, exist_ok=True)
        for f in sorted(os.listdir(src_dir)):
            key = f[:-4]
            if key not in TEXT[lang]:
                print('metin yok:', lang, key); continue
            title, sub = TEXT[lang][key]
            frame(os.path.join(src_dir, f), os.path.join(out_dir, f), title, sub)
            print(lang, f)


if __name__ == '__main__':
    main()
