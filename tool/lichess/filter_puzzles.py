#!/usr/bin/env python3
"""Lichess bulmaca veritabanından (CC0) çocuk seviyesine uygun mat bulmacalarını süzer.

Kullanım: zstd -dc lichess_db_puzzle.csv.zst | python3 filter_puzzles.py
Çıktı: selected_mate_in_1.csv ve selected_mate_in_2.csv (ham FEN + tüm hamleler; dönüştürme
ve doğrulama Dart tarafında convert.dart ile yapılır).
"""
import csv, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
SPECS = {
    'mateIn1': dict(rating=(400, 1100), take=400, out='selected_mate_in_1.csv'),
    'mateIn2': dict(rating=(600, 1400), take=300, out='selected_mate_in_2.csv'),
}
MIN_POPULARITY, MIN_PLAYS, MAX_DEVIATION = 90, 2000, 90

reader = csv.reader(sys.stdin)
header = next(reader)
idx = {name: i for i, name in enumerate(header)}
cands = {k: [] for k in SPECS}
for row in reader:
    themes = row[idx['Themes']].split()
    try:
        rating = int(row[idx['Rating']]); dev = int(row[idx['RatingDeviation']])
        pop = int(row[idx['Popularity']]); plays = int(row[idx['NbPlays']])
    except ValueError:
        continue
    if pop < MIN_POPULARITY or plays < MIN_PLAYS or dev > MAX_DEVIATION:
        continue
    for key, spec in SPECS.items():
        lo, hi = spec['rating']
        if key in themes and lo <= rating <= hi:
            cands[key].append(row)

for key, spec in SPECS.items():
    rows = sorted(cands[key], key=lambda r: int(r[idx['Rating']]))
    n = spec['take']
    # Puan aralığına eşit yayılmış örnekleme: kolaydan zora düzgün geçiş.
    if len(rows) > n:
        step = len(rows) / n
        rows = [rows[int(i * step)] for i in range(n)]
    with open(os.path.join(HERE, spec['out']), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['PuzzleId', 'FEN', 'Moves', 'Rating', 'Themes'])
        for r in rows:
            w.writerow([r[idx['PuzzleId']], r[idx['FEN']], r[idx['Moves']], r[idx['Rating']], r[idx['Themes']]])
    print(f"{key}: aday {len(cands[key])}, seçilen {len(rows)} -> {spec['out']}")
