#!/usr/bin/env python3
"""Mağaza ekran görüntüleri: ham telefon görüntüsü → lacivert çerçeve + başlık. ImageMagick gerekir.

Android (Play): store/screenshots/raw/<dil>/NN_ad.png (1080x2310) → store/screenshots/<dil>/ (1080x1920)
    python3 tool/branding/make_screenshots.py [tr en ...]
iOS (App Store, 6,9"): store/screenshots/ios/raw/<dil>/NN_ad.png (simülatör, 1320x2868; CI artifact'ı
    "store-screenshots-ios") → store/screenshots/ios/<dil>/ (1320x2868)
    python3 tool/branding/make_screenshots.py ios [tr en ...]
"""
import os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NAVY, GOLD, CREAM = '#1F3A5F', '#E9A825', '#DCE6F5'

# Profil: (ham klasör, çıktı klasörü, durum çubuğu kırpma, alt çubuk kırpma, tuval, görüntü genişliği, görüntü üst konumu)
PROFILES = {
    'android': dict(raw=('store', 'screenshots', 'raw'), out=('store', 'screenshots'),
                    status=100, nav=112, w=1080, h=1920, shot_w=880, shot_y=400),
    # Simülatör görüntüsü Flutter yüzeyidir: üstte güvenli alan (62pt), altta ana ekran çubuğu (34pt) boş kalır.
    'ios': dict(raw=('store', 'screenshots', 'ios', 'raw'), out=('store', 'screenshots', 'ios'),
                status=186, nav=102, w=1320, h=2868, shot_w=1120, shot_y=540),
}

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


TEXT_IOS = {
    'tr': {
        '01_home': ('Çocuklar için\nsatranç okulu', 'Dersler, bulmacalar, akıllı rakip'),
        '02_lesson': ('20 etkileşimli ders', 'Tahtada görev yap, anında geri bildirim al'),
        '03_play': ('5 seviyeli rakip', 'Stockfish motoru, tamamen çevrimdışı'),
        '04_analysis': ('Hatalarını gör,\ndaha iyisini öğren', 'Oyun sonunda hamle hamle analiz'),
        '05_puzzle': ('700+ mat bulmacası', 'Kolaydan zora, her gün yeni bulmaca'),
        '06_lan': ('Arkadaşınla oyna', 'Aynı Wi-Fi\'da, hesapsız, sunucusuz'),
        '07_progress': ('İlerlemeni izle', 'Günlük seri ve rozetler'),
        '08_setup': ('Seviyeni seç', 'Çaylaktan büyük ustaya'),
    },
    'en': {
        '01_home': ('Chess school\nfor kids', 'Lessons, puzzles, smart opponent'),
        '02_lesson': ('20 interactive lessons', 'Do tasks on the board, get instant feedback'),
        '03_play': ('Opponent with 5 levels', 'Stockfish engine, fully offline'),
        '04_analysis': ('See your mistakes,\nlearn the better move', 'Move-by-move analysis after every game'),
        '05_puzzle': ('700+ mate puzzles', 'Easy to hard, a new puzzle every day'),
        '06_lan': ('Play with a friend', 'Same Wi-Fi, no account, no server'),
        '07_progress': ('Track your progress', 'Daily streak and badges'),
        '08_setup': ('Pick your level', 'From rookie to grandmaster'),
    },
    'de': {
        '01_home': ('Schachschule\nfür Kinder', 'Lektionen, Aufgaben, kluger Gegner'),
        '02_lesson': ('20 interaktive Lektionen', 'Aufgaben am Brett, sofortiges Feedback'),
        '03_play': ('Gegner mit 5 Stufen', 'Stockfish-Engine, komplett offline'),
        '04_analysis': ('Fehler erkennen,\nbesser spielen', 'Zug-für-Zug-Analyse nach jeder Partie'),
        '05_puzzle': ('700+ Mattaufgaben', 'Von leicht bis schwer, täglich neu'),
        '06_lan': ('Mit Freunden spielen', 'Gleiches WLAN, kein Konto, kein Server'),
        '07_progress': ('Fortschritt im Blick', 'Tägliche Serie und Abzeichen'),
        '08_setup': ('Wähle deine Stufe', 'Vom Anfänger zum Großmeister'),
    },
    'es': {
        '01_home': ('Escuela de ajedrez\npara niños', 'Lecciones, problemas, rival inteligente'),
        '02_lesson': ('20 lecciones interactivas', 'Tareas en el tablero, respuesta al instante'),
        '03_play': ('Rival con 5 niveles', 'Motor Stockfish, sin conexión'),
        '04_analysis': ('Ve tus errores,\naprende la mejor jugada', 'Análisis jugada a jugada tras cada partida'),
        '05_puzzle': ('700+ problemas de mate', 'De fácil a difícil, uno nuevo cada día'),
        '06_lan': ('Juega con un amigo', 'Misma Wi-Fi, sin cuenta, sin servidor'),
        '07_progress': ('Sigue tu progreso', 'Racha diaria e insignias'),
        '08_setup': ('Elige tu nivel', 'De novato a gran maestro'),
    },
}


def run(*a):
    subprocess.run(['magick', *a], check=True)


def font(bold):
    """Makinedeki ilk uygun yazı tipi dosyası (fc-match); değişken (variable) fontta kalınlık seçilemez, atlanır."""
    for fam in ('DejaVu Sans', 'Liberation Sans', 'Noto Sans'):
        f = subprocess.check_output(['fc-match', '-f', '%{file}', f'{fam}:{"bold" if bold else "regular"}']).decode()
        if fam.split()[0].lower() in os.path.basename(f).lower() and (not bold or 'Bold' in f):
            return f
    sys.exit('Uygun yazı tipi yok (DejaVu Sans / Liberation Sans / Noto Sans statik dosyaları)')


def frame(src, dst, title, sub, p):
    W, H, SHOT_W, SHOT_Y = p['w'], p['h'], p['shot_w'], p['shot_y']
    k = W / 1080  # yazı ve süs ölçeği (Android tuvaline göre)
    tmp = tempfile.mkdtemp()
    shot = os.path.join(tmp, 'shot.png')
    sw, sh = map(int, subprocess.check_output(['magick', 'identify', '-format', '%w %h', src]).decode().split())
    # durum ve gezinme çubuklarını kırp, ölçekle, üst köşeleri yuvarla
    run(src, '-crop', f"{sw}x{sh-p['status']-p['nav']}+0+{p['status']}", '+repage', '-resize', f'{SHOT_W}x', shot)
    sh_h = int(subprocess.check_output(['magick', 'identify', '-format', '%h', shot]).decode())
    mask = os.path.join(tmp, 'mask.png')
    r = int(44 * k)
    run('-size', f'{SHOT_W}x{sh_h}', 'xc:none', '-fill', 'white', '-draw', f'roundrectangle 0,0 {SHOT_W-1},{sh_h+60} {r},{r}', mask)
    run(shot, mask, '-alpha', 'off', '-compose', 'CopyOpacity', '-composite', shot)
    lines = title.count('\n') + 1
    title_size = int((74 if lines == 1 and len(title) <= 24 else 66) * k)
    sub_size, top = int(34 * k), int(96 * k)
    cx = int(980 * k)
    run('-size', f'{W}x{H}', f'xc:{NAVY}',
        # arka plan altın halkalar
        '-fill', 'none', '-stroke', GOLD, '-strokewidth', str(int(4 * k)), '-draw', f'circle {cx},{H-int(120*k)} {cx},{H-int(420*k)}',
        '-strokewidth', str(int(2 * k)), '-draw', f'circle {cx},{H-int(120*k)} {cx},{H-int(520*k)}',
        '-stroke', 'none',
        '-font', font(True), '-pointsize', str(title_size), '-fill', 'white', '-gravity', 'north',
        '-interline-spacing', str(int(-6 * k)), '-annotate', f'+0+{top}', title,
        '-font', font(False), '-pointsize', str(sub_size), '-fill', CREAM, '-annotate', f'+0+{top + title_size*1.2*lines + 26*k:.0f}', sub,
        # gölge + görüntü (alt kenardan taşar)
        '(', shot, '-alpha', 'extract', '-blur', f'0x{int(24*k)}', '-fill', 'black', '-colorize', '100', '-alpha', 'copy', '-channel', 'A', '-evaluate', 'multiply', '0.5', '+channel', ')',
        '-gravity', 'north', '-geometry', f'+0+{SHOT_Y+int(18*k)}', '-compose', 'over', '-composite',
        shot, '-gravity', 'north', '-geometry', f'+0+{SHOT_Y}', '-composite',
        '-crop', f'{W}x{H}+0+0', '+repage', dst)


def main():
    args = sys.argv[1:]
    profile = 'ios' if args and args[0] == 'ios' else 'android'
    if profile == 'ios':
        args = args[1:]
    p = PROFILES[profile]
    raw, out, text = os.path.join(ROOT, *p['raw']), os.path.join(ROOT, *p['out']), (TEXT_IOS if profile == 'ios' else TEXT)
    if not os.path.isdir(raw):
        sys.exit(f'Ham ekran görüntüsü klasörü yok: {raw} (git dışı; PNG\'leri <dil>/NN_ad.png olarak koy)')
    langs = args or sorted(d for d in os.listdir(raw) if os.path.isdir(os.path.join(raw, d)))
    for lang in langs:
        src_dir = os.path.join(raw, lang); out_dir = os.path.join(out, lang); os.makedirs(out_dir, exist_ok=True)
        for f in sorted(os.listdir(src_dir)):
            key = f[:-4]
            if key not in text[lang]:
                print('metin yok:', lang, key); continue
            title, sub = text[lang][key]
            frame(os.path.join(src_dir, f), os.path.join(out_dir, f), title, sub, p)
            print(lang, f)


if __name__ == '__main__':
    main()
