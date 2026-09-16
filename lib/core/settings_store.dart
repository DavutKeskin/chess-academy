import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Kullanıcının seçebildiği tahta temaları. Ad, çocuk için anlaşılır Türkçe.
enum BoardTheme {
  klasik(ChessboardColorScheme.brown),
  turnuva(ChessboardColorScheme.green),
  okyanus(ChessboardColorScheme.blue),
  ahsap(ChessboardColorScheme.wood2),
  akcaagac(ChessboardColorScheme.maple),
  mermer(ChessboardColorScheme.marble),
  menekse(ChessboardColorScheme.purple),
  zeytin(ChessboardColorScheme.olive),
  grafit(ChessboardColorScheme.grey),
  seker(ChessboardColorScheme.pinkPyramid);

  const BoardTheme(this._colors);
  final ChessboardColorScheme _colors;

  /// Lichess'in yeşil temasında son hamle soluk mavi; yeşil karelerde seçilmiyordu
  /// (test geri bildirimi). Bu temada belirgin sarı kullanılır.
  ChessboardColorScheme get colors => this == BoardTheme.turnuva
      ? _colors.copyWith(lastMove: const HighlightDetails(solidColor: Color(0xA6F2E24B)))
      : _colors;

  String label(AppLocalizations t) => switch (this) {
        BoardTheme.klasik => t.boardKlasik,
        BoardTheme.turnuva => t.boardTurnuva,
        BoardTheme.okyanus => t.boardOkyanus,
        BoardTheme.ahsap => t.boardAhsap,
        BoardTheme.akcaagac => t.boardAkcaagac,
        BoardTheme.mermer => t.boardMermer,
        BoardTheme.menekse => t.boardMenekse,
        BoardTheme.zeytin => t.boardZeytin,
        BoardTheme.grafit => t.boardGrafit,
        BoardTheme.seker => t.boardSeker,
      };
}

/// Uygulamanın kendi taş seti: cburnett tabanlı, şah ve filde haç yerine hilal.
/// Görseller `assets/pieces/hilal/` altında (1x, 2x, 3x).
final PieceAssets hilalAssets = {
  for (final kind in PieceKind.values)
    kind: AssetImage('assets/pieces/hilal/${_kindFile(kind)}.webp'),
};

String _kindFile(PieceKind kind) {
  final color = kind.side == Side.white ? 'w' : 'b';
  final role = switch (kind.role) {
    Role.pawn => 'P',
    Role.knight => 'N',
    Role.bishop => 'B',
    Role.rook => 'R',
    Role.queen => 'Q',
    Role.king => 'K',
  };
  return '$color$role';
}

/// Taş setleri: klasikten çocuk dostu yumuşak formlara.
enum PieceStyle {
  hilal(null),
  klasik(PieceSet.cburnett),
  merida(PieceSet.merida),
  staunty(PieceSet.staunty),
  fresca(PieceSet.fresca),
  cardinal(PieceSet.cardinal),
  gioco(PieceSet.gioco),
  tatiana(PieceSet.tatiana),
  horsey(PieceSet.horsey);

  const PieceStyle(this._set);
  final PieceSet? _set;

  PieceAssets get assets => _set?.assets ?? hilalAssets;

  String label(AppLocalizations t) => switch (this) {
        PieceStyle.hilal => t.pieceHilal,
        PieceStyle.klasik => t.pieceKlasik,
        PieceStyle.merida => t.pieceMerida,
        PieceStyle.staunty => t.pieceStaunty,
        PieceStyle.fresca => t.pieceFresca,
        PieceStyle.cardinal => t.pieceCardinal,
        PieceStyle.gioco => t.pieceGioco,
        PieceStyle.tatiana => t.pieceTatiana,
        PieceStyle.horsey => t.pieceHorsey,
      };
}

/// Yaş grubu: metin tonu ve öneriler için.
enum AgeGroup {
  child,
  teen,
  adult;

  String label(AppLocalizations t) => switch (this) {
        AgeGroup.child => t.ageChild,
        AgeGroup.teen => t.ageTeen,
        AgeGroup.adult => t.ageAdult,
      };

  String hint(AppLocalizations t) => switch (this) {
        AgeGroup.child => t.ageChildHint,
        AgeGroup.teen => t.ageTeenHint,
        AgeGroup.adult => t.ageAdultHint,
      };
}

/// Başlangıç seviyesi: dersleri kilitler/açar ve rakip seviyesini önerir.
enum SkillLevel {
  beginner,
  knowsRules,
  plays;

  String label(AppLocalizations t) => switch (this) {
        SkillLevel.beginner => t.skillBeginner,
        SkillLevel.knowsRules => t.skillKnowsRules,
        SkillLevel.plays => t.skillPlays,
      };

  String hint(AppLocalizations t) => switch (this) {
        SkillLevel.beginner => t.skillBeginnerHint,
        SkillLevel.knowsRules => t.skillKnowsRulesHint,
        SkillLevel.plays => t.skillPlaysHint,
      };
}

/// Görünüm ve geri bildirim tercihleri; cihazda saklanır, değişince dinleyenler güncellenir.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kBoard = 'board_theme';
  static const _kPieces = 'piece_style';
  static const _kSound = 'sound_on';
  static const _kHaptics = 'haptics_on';
  static const _kAge = 'profile_age';
  static const _kLevel = 'profile_level';
  static const _kOnboarded = 'onboarding_done';
  static const _kLang = 'language';
  static const _kTimeControl = 'time_control';

  late SharedPreferences _prefs;
  BoardTheme _board = BoardTheme.turnuva;
  PieceStyle _pieces = PieceStyle.hilal;

  bool _sound = true;
  bool _haptics = true;
  AgeGroup _age = AgeGroup.child;
  SkillLevel _level = SkillLevel.beginner;
  bool _onboarded = false;
  String? _language; // null = sistem dili
  String? _timeControl; // son seçilen süre kodu ("5+0"), null = süresiz

  BoardTheme get board => _board;
  PieceStyle get pieces => _pieces;
  bool get soundOn => _sound;
  bool get hapticsOn => _haptics;
  AgeGroup get age => _age;
  SkillLevel get level => _level;
  bool get onboardingDone => _onboarded;

  /// Bilgisayara karşı son seçilen süre kontrolü kodu; null ise süresiz.
  String? get timeControl => _timeControl;

  /// Seçili dil kodu; null ise cihaz dili.
  String? get language => _language;
  Locale? get locale => _language == null ? null : Locale(_language!);

  /// Kuralları bilen kullanıcı için dersler baştan açık.
  bool get lessonsUnlocked => _level != SkillLevel.beginner;

  /// Seviyeye göre önerilen bilgisayar rakibi.
  int get suggestedBotLevel => switch (_level) {
        SkillLevel.beginner => 1,
        SkillLevel.knowsRules => 2,
        SkillLevel.plays => 3,
      };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _board = BoardTheme.values.asNameMap()[_prefs.getString(_kBoard)] ?? _board;
    _pieces =
        PieceStyle.values.asNameMap()[_prefs.getString(_kPieces)] ?? _pieces;
    _sound = _prefs.getBool(_kSound) ?? true;
    _haptics = _prefs.getBool(_kHaptics) ?? true;
    _age = AgeGroup.values.asNameMap()[_prefs.getString(_kAge)] ?? _age;
    _level = SkillLevel.values.asNameMap()[_prefs.getString(_kLevel)] ?? _level;
    _onboarded = _prefs.getBool(_kOnboarded) ?? false;
    _language = _prefs.getString(_kLang);
    _timeControl = _prefs.getString(_kTimeControl);
  }

  Future<void> setTimeControl(String? code) async {
    _timeControl = code;
    if (code == null) {
      await _prefs.remove(_kTimeControl);
    } else {
      await _prefs.setString(_kTimeControl, code);
    }
  }

  Future<void> setLanguage(String? code) async {
    _language = code;
    if (code == null) {
      await _prefs.remove(_kLang);
    } else {
      await _prefs.setString(_kLang, code);
    }
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    await _prefs.setBool(_kSound, value);
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  Future<void> setProfile({required AgeGroup age, required SkillLevel level}) async {
    _age = age;
    _level = level;
    _onboarded = true;
    await _prefs.setString(_kAge, age.name);
    await _prefs.setString(_kLevel, level.name);
    await _prefs.setBool(_kOnboarded, true);
    notifyListeners();
  }

  Future<void> setBoard(BoardTheme value) async {
    if (value == _board) return;
    _board = value;
    await _prefs.setString(_kBoard, value.name);
    notifyListeners();
  }

  Future<void> setPieces(PieceStyle value) async {
    if (value == _pieces) return;
    _pieces = value;
    await _prefs.setString(_kPieces, value.name);
    await _loadPieceImages();
    notifyListeners();
  }

  /// Seçili taş setinin görsellerini önbelleğe alır; ilk karede boş tahta görünmesin.
  Future<void> _loadPieceImages() async {
    ChessgroundImages.instance.clear();
    await ChessgroundImages.instance.loadAll(
      _pieces.assets,
      devicePixelRatio: WidgetsBinding
          .instance
          .platformDispatcher
          .implicitView
          ?.devicePixelRatio,
    );
  }

  Future<void> preloadPieceImages() => _loadPieceImages();

  static const _radius = BorderRadius.all(Radius.circular(14));
  static const _shadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// Etkileşimli tahta ayarları.
  ChessboardSettings get boardSettings => ChessboardSettings(
    colorScheme: _board.colors,
    pieceAssets: _pieces.assets,
    enableCoordinates: true,
    enablePremoves: false,
    autoQueenPromotion: true,
    borderRadius: _radius,
    boxShadow: _shadow,
  );

  /// Ders anlatımındaki sabit tahta ayarları.
  StaticChessboardSettings get staticBoardSettings => StaticChessboardSettings(
    colorScheme: _board.colors,
    pieceAssets: _pieces.assets,
    enableCoordinates: true,
    borderRadius: _radius,
    boxShadow: _shadow,
  );

  /// Küçük önizlemeler için sade ayar (koordinatsız, gölgesiz).
  StaticChessboardSettings previewSettings({
    BoardTheme? board,
    PieceStyle? pieces,
  }) => StaticChessboardSettings(
    colorScheme: (board ?? _board).colors,
    pieceAssets: (pieces ?? _pieces).assets,
    enableCoordinates: false,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
  );
}
