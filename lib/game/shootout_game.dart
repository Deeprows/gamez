import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Penalty Kings 4.0 — match engine
//  Behind-the-ball 3D view • swipe to shoot (aim, power, curve) • dive to save
//  Alternating 5-kick shootouts with sudden death, net physics, confetti.
// ─────────────────────────────────────────────────────────────────────────────

const Color _ink = Color(0xFF071019);
const Color _panel = Color(0xFF101D2A);
const Color _lime = Color(0xFFC7F36B);
const Color _muted = Color(0xFF8DA1B3);
const Color _red = Color(0xFFFF6878);
const Color _gold = Color(0xFFFFC65C);
const Color _ice = Color(0xFF73C8FF);
const Color _cpuKeeper = Color(0xFF3DDC97);

const double _hw = 3.66; // half goal width (m)
const double _gh = 2.44; // goal height (m)
const double _depth = 2.2; // net depth (m)
const double _rearH = 2.0; // rear net height (m)
const double _spotZ = 11.0; // penalty spot distance (m)

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _c(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double _clamp01(double v) => _c(v, 0, 1);
double _ease(double t) => t * t * (3 - 2 * t);

enum MatchFormat { shootout, suddenDeath, training }

class MatchSetup {
  final MatchFormat format;
  final String title;
  final String subtitle;
  final String homeName, homeShort, awayName, awayShort;
  final Color homeColor, awayColor, keeperColor;
  final String difficulty;
  final bool vibration, sound;
  const MatchSetup({
    required this.format,
    required this.title,
    required this.subtitle,
    required this.homeName,
    required this.homeShort,
    required this.awayName,
    required this.awayShort,
    required this.homeColor,
    required this.awayColor,
    required this.keeperColor,
    required this.difficulty,
    required this.vibration,
    required this.sound,
  });
}

class MatchResult {
  final int goals, oppGoals, attempts, oppAttempts, saves, bestStreak;
  final bool won;
  const MatchResult({
    required this.goals,
    required this.oppGoals,
    required this.attempts,
    required this.oppAttempts,
    required this.saves,
    required this.bestStreak,
    required this.won,
  });
}

enum _Phase { aim, runUp, flight, aftermath, finished }

enum _Outcome { goal, saved, wide, over, post }

class _Aim {
  final double tx, ty, curve;
  const _Aim(this.tx, this.ty, this.curve);
}

class _Particle {
  double x, y, vx, vy, rot, vr, size, life;
  final Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.rot, this.vr, this.size, this.life, this.color);
}

// Mutable render state shared between the game logic and the painter.
class _Scene extends ChangeNotifier {
  double time = 0;
  double spin = 0;
  Color shooterColor = Colors.white;
  Color keeperColor = Colors.orange;
  double runUp = 0, kick = 0;
  double bx = 0, by = .105, bz = _spotZ;
  final List<List<double>> trail = <List<double>>[];
  double kx = 0, ky = .95, kRot = 0, kArms = 0;
  double netAge = 99, netX = 0, netY = 1;
  double zoom = 0, shake = 0, hype = 0;
  List<Offset> dragTrail = const <Offset>[];
  Offset? reticle;
  double reticleCurve = 0;
  bool showZones = false;
  int diveZone = -1;
  final List<_Particle> particles = <_Particle>[];

  void repaint() => notifyListeners();
}

// Simple perspective camera sitting behind the penalty spot.
class _Cam {
  final Size size;
  final double camZ, camY, f, hy;
  _Cam._(this.size, this.camZ, this.camY, this.f, this.hy);
  factory _Cam(Size size, double zoom) {
    final f = math.min(size.width * .9 / 7.32 * 15.5, size.height * 1.0);
    return _Cam._(size, 15.5 - zoom * 1.8, 2.4 - zoom * .45, f, size.height * .30);
  }
  double s(double z) => f / math.max(.35, camZ - z);
  Offset p(double x, double y, double z) {
    final k = s(z);
    return Offset(size.width / 2 + x * k, hy + (camY - y) * k);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget
// ─────────────────────────────────────────────────────────────────────────────

class ShootoutMatch extends StatefulWidget {
  final MatchSetup setup;
  final ValueChanged<MatchResult> onFinished;
  final VoidCallback onExit;
  const ShootoutMatch({
    super.key,
    required this.setup,
    required this.onFinished,
    required this.onExit,
  });

  @override
  State<ShootoutMatch> createState() => _ShootoutMatchState();
}

class _ShootoutMatchState extends State<ShootoutMatch> with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  final _Scene _sc = _Scene();
  late final _PitchPainter _painter;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _size = const Size(390, 700);
  bool _paused = false;
  bool _reported = false;

  _Phase _phase = _Phase.aim;
  double _pt = 0;
  double _runDur = .32;
  bool _playerTurn = true;

  int _pGoals = 0, _cGoals = 0, _pAtt = 0, _cAtt = 0, _saves = 0, _streak = 0, _bestStreak = 0;
  final List<int> _pHist = <int>[];
  final List<int> _cHist = <int>[];

  // Current shot
  double _tx = 0, _ty = 1, _power = .7, _curve = 0, _flightDur = .8;
  _Outcome _outcome = _Outcome.goal;
  bool _decided = false;

  // Keeper
  bool _diveChosen = false;
  int _kCol = 1, _kRow = 0;
  double _diveAt = -1;
  double _kx0 = 0, _ky0 = .95, _kxT = 0, _kyT = .95;

  // Ball after the shot
  double _bvx = 0, _bvy = 0, _bvz = 0;

  // Input
  List<Offset> _dragPts = <Offset>[];

  // UI
  String? _banner;
  Color _bannerColor = _lime;
  int _bannerId = 0;
  String _hint = '';

  bool get _training => widget.setup.format == MatchFormat.training;
  int get _reg => widget.setup.format == MatchFormat.shootout ? 5 : 0;

  @override
  void initState() {
    super.initState();
    _painter = _PitchPainter(_sc, widget.setup);
    _beginTurn();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sc.dispose();
    super.dispose();
  }

  // ── Loop ───────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (dt > .05) dt = .05;
    if (dt < 0) dt = 0;
    if (_paused) return;
    _update(dt);
    _sc.repaint();
  }

  void _update(double dt) {
    final sc = _sc;
    sc.time += dt;
    sc.spin += dt * (_phase == _Phase.flight ? 16 : 2);
    sc.netAge += dt;
    sc.hype = math.max(0, sc.hype - dt * .45);
    sc.shake = math.max(0, sc.shake - dt * 22);
    if (_phase != _Phase.flight) sc.zoom = math.max(0, sc.zoom - dt * .9);
    sc.showZones = !_playerTurn &&
        !_diveChosen &&
        (_phase == _Phase.aim || _phase == _Phase.runUp || _phase == _Phase.flight);

    for (int i = sc.particles.length - 1; i >= 0; i--) {
      final p = sc.particles[i];
      p.life -= dt;
      if (p.life <= 0) {
        sc.particles.removeAt(i);
        continue;
      }
      p.vy += 520 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vr * dt;
    }

    _updateKeeper();

    switch (_phase) {
      case _Phase.aim:
        _pt += dt;
        if (!_playerTurn && _pt >= 1.15) {
          _phase = _Phase.runUp;
          _pt = 0;
          _runDur = .55;
        }
        break;
      case _Phase.runUp:
        _pt += dt;
        sc.runUp = _clamp01(_pt / _runDur);
        if (_pt >= _runDur) _kick();
        break;
      case _Phase.flight:
        _pt += dt;
        _updateFlight();
        break;
      case _Phase.aftermath:
        _pt += dt;
        _updateAftermath(dt);
        if (_pt >= 1.75) _advance();
        break;
      case _Phase.finished:
        _pt += dt;
        _updateAftermath(dt);
        if (_pt >= 1.9 && !_reported) {
          _reported = true;
          widget.onFinished(_buildResult());
        }
        break;
    }
  }

  void _updateKeeper() {
    final sc = _sc;
    if (_diveAt >= 0) {
      if (sc.time >= _diveAt) {
        final raw = _clamp01((sc.time - _diveAt) / .42);
        final e = 1 - math.pow(1 - raw, 3).toDouble();
        sc.kx = _lerp(_kx0, _kxT, e);
        sc.ky = _lerp(_ky0, _kyT, e);
        final dx = _kxT - _kx0;
        final spread = math.min(1.0, dx.abs() / 2.4);
        final low = _kyT < .9;
        sc.kRot = (dx >= 0 ? 1.0 : -1.0) * e * spread * (low ? 1.35 : .9);
        sc.kArms = e;
      }
    } else if (_phase != _Phase.aftermath && _phase != _Phase.finished) {
      sc.kx = math.sin(sc.time * 1.6) * .32;
      sc.ky = .95;
      sc.kRot = 0;
      sc.kArms = .05 + .05 * math.sin(sc.time * 3);
    }
  }

  // ── Turn flow ──────────────────────────────────────────────────────────────

  Color get _awayKeeper => _cpuKeeper;

  void _beginTurn() {
    final sc = _sc;
    final s = widget.setup;
    _phase = _Phase.aim;
    _pt = 0;
    _decided = false;
    _diveChosen = false;
    _diveAt = -1;
    _outcome = _Outcome.goal;
    _banner = null;
    _bvx = 0;
    _bvy = 0;
    _bvz = 0;
    sc.runUp = 0;
    sc.kick = 0;
    sc.bx = 0;
    sc.by = .105;
    sc.bz = _spotZ;
    sc.trail.clear();
    sc.zoom = 0;
    sc.shooterColor = _playerTurn ? s.homeColor : s.awayColor;
    sc.keeperColor = _playerTurn ? _awayKeeper : s.keeperColor;
    sc.kx = 0;
    sc.ky = .95;
    sc.kRot = 0;
    sc.kArms = 0;
    sc.dragTrail = const <Offset>[];
    sc.reticle = null;
    sc.diveZone = -1;
    if (_playerTurn) {
      _hint = 'SWIPE UP TO SHOOT  •  FLICK FOR POWER  •  CURVE IT';
    } else {
      _hint = 'SWIPE OR TAP A ZONE TO DIVE';
      _genCpuShot();
    }
  }

  void _genCpuShot() {
    final diff = widget.setup.difficulty;
    final cornerP = switch (diff) { 'AMATEUR' => .5, 'WORLD CLASS' => .8, _ => .66 };
    final missP = switch (diff) { 'AMATEUR' => .17, 'WORLD CLASS' => .06, _ => .11 };
    final corner = _rng.nextDouble() < cornerP;
    final col = corner ? (_rng.nextBool() ? 0 : 2) : 1;
    final row = _rng.nextDouble() < .55 ? 0 : 1;
    final side = col == 0 ? -1.0 : 1.0;
    double x = col == 1 ? (_rng.nextDouble() - .5) * 1.8 : side * (1.8 + _rng.nextDouble() * 1.55);
    double y = row == 0 ? .25 + _rng.nextDouble() * .75 : 1.55 + _rng.nextDouble() * .75;
    if (_rng.nextDouble() < missP) {
      if (_rng.nextBool()) {
        x = (x >= 0 ? 1.0 : -1.0) * (3.9 + _rng.nextDouble() * .8);
      } else {
        y = 2.62 + _rng.nextDouble() * .4;
      }
    }
    _tx = x;
    _ty = y;
    _power = .55 + _rng.nextDouble() * .4;
    _curve = (_rng.nextDouble() - .5) * .8;
    _flightDur = _lerp(1.1, .66, _power);
  }

  void _launchPlayerShot(_Aim aim, double power) {
    double n() => _rng.nextDouble() + _rng.nextDouble() + _rng.nextDouble() - 1.5;
    _tx = aim.tx + n() * (.10 + power * .24);
    _ty = aim.ty + n() * (.07 + power * .16);
    if (power > .93) _ty += (power - .93) * 5 * _rng.nextDouble();
    _ty = math.max(.08, _ty);
    _power = power;
    _curve = aim.curve;
    _flightDur = _lerp(1.05, .52, power);
    _decided = false;
    _diveChosen = false;
    _diveAt = -1;
    _phase = _Phase.runUp;
    _pt = 0;
    _runDur = .3;
    _sc.dragTrail = const <Offset>[];
    _sc.reticle = null;
    setState(() => _hint = 'POWER ${(power * 100).round()}%');
  }

  void _kick() {
    _phase = _Phase.flight;
    _pt = 0;
    _sc.runUp = 1;
    _sc.trail.clear();
    _sfx();
    _haptic(0);
    if (_playerTurn) {
      _decideDefence();
      _startDive(.08 + _rng.nextDouble() * .1);
    } else if (_diveChosen) {
      _decideDefence(lateT: 0);
      _startDive(0);
    }
  }

  void _startDive(double delay) {
    _kx0 = _sc.kx;
    _ky0 = _sc.ky;
    _diveAt = _sc.time + delay;
  }

  _Outcome _classify(double x, double y) {
    final ax = x.abs();
    if (ax > _hw + .16) return _Outcome.wide;
    if (y > _gh + .16) return _Outcome.over;
    final edge = math.min(_hw - ax, _gh - y);
    if (edge < 0) return _Outcome.post;
    if (edge < .14 && _rng.nextDouble() < .45) return _Outcome.post;
    return _Outcome.goal;
  }

  double _saveChance(int shotCol, int shotRow, int kCol, int kRow) {
    if (kCol != shotCol) return 0;
    double p = kRow == shotRow ? .82 : (kCol == 1 ? .5 : .28);
    p *= (1.22 - _power * .5);
    if (_tx.abs() > 2.75 && (_ty < .55 || _ty > 1.85)) p *= .62;
    p *= 1 - _curve.abs() * .14;
    return _c(p, 0, .92);
  }

  void _decideDefence({double lateT = 0, bool noDive = false}) {
    if (_decided) return;
    _decided = true;
    final shotCol = _tx < -_hw / 3 ? 0 : (_tx > _hw / 3 ? 2 : 1);
    final shotRow = _ty >= _gh / 2 ? 1 : 0;
    var o = _classify(_tx, _ty);
    if (o == _Outcome.goal) {
      double chance;
      if (_playerTurn) {
        final read = switch (widget.setup.difficulty) { 'AMATEUR' => .10, 'WORLD CLASS' => .34, _ => .22 };
        _kCol = _rng.nextDouble() < read ? shotCol : _rng.nextInt(3);
        _kRow = _rng.nextDouble() < .55 ? shotRow : _rng.nextInt(2);
        chance = _saveChance(shotCol, shotRow, _kCol, _kRow);
      } else if (noDive) {
        chance = shotCol == 1 ? .4 : 0;
      } else {
        chance = _saveChance(shotCol, shotRow, _kCol, _kRow) * (lateT > .72 ? .45 : 1);
      }
      if (_rng.nextDouble() < chance) o = _Outcome.saved;
    } else if (_playerTurn) {
      _kCol = _rng.nextInt(3);
      _kRow = _rng.nextInt(2);
    }
    _outcome = o;
    const zoneX = <double>[-2.4, 0.0, 2.4];
    if (o == _Outcome.saved) {
      _kxT = _c(_tx * .94, -3.1, 3.1);
      _kyT = _c(_ty - .25, .55, 1.95);
    } else if (noDive) {
      _kxT = _sc.kx;
      _kyT = .95;
    } else {
      _kxT = zoneX[_kCol];
      _kyT = _kRow == 1 ? 1.75 : .6;
    }
  }

  void _updateFlight() {
    final sc = _sc;
    final t = _clamp01(_pt / _flightDur);
    sc.kick = _clamp01(_pt / .22);
    sc.zoom = _ease(t);
    final x = _tx * t + math.sin(math.pi * t) * _curve * 1.2;
    final y = _lerp(.105, _ty, t) + math.sin(math.pi * t) * .18;
    final z = _spotZ * (1 - t);
    sc.bx = x;
    sc.by = y;
    sc.bz = z;
    sc.trail.add(<double>[x, y, z]);
    if (sc.trail.length > 12) sc.trail.removeAt(0);
    if (!_playerTurn && !_decided && t >= .86) {
      _decideDefence(noDive: true);
      if (_outcome == _Outcome.saved) _startDive(0);
    }
    if (_pt >= _flightDur) _resolve();
  }

  void _resolve() {
    final sc = _sc;
    final o = _outcome;
    final goal = o == _Outcome.goal;

    double vx = (_tx - math.pi * 1.2 * _curve) / _flightDur;
    double vy = (_ty - .105 - math.pi * .18) / _flightDur;
    double vz = -_spotZ / _flightDur;
    switch (o) {
      case _Outcome.goal:
        vx *= .5;
        vy = math.max(vy * .4, -1.0);
        vz *= .55;
        break;
      case _Outcome.saved:
        vx = (_tx >= 0 ? 1.0 : -1.0) * (1.5 + _rng.nextDouble() * 2.5);
        vy = 2 + _rng.nextDouble() * 2.5;
        vz = 3.5 + _rng.nextDouble() * 3.5;
        _diveAt = sc.time - .6; // snap the keeper onto the ball
        _kx0 = _kxT;
        _ky0 = _kyT;
        break;
      case _Outcome.post:
        vx = (_tx >= 0 ? 1.0 : -1.0) * (_rng.nextDouble() * 3 - 1);
        vy = _rng.nextDouble() * 3;
        vz = 5 + _rng.nextDouble() * 3;
        break;
      case _Outcome.wide:
      case _Outcome.over:
        vz *= .8;
        break;
    }
    sc.bx = _tx;
    sc.by = _ty;
    sc.bz = 0;
    _bvx = vx;
    _bvy = vy;
    _bvz = vz;

    if (_playerTurn) {
      _pAtt++;
      _pHist.add(goal ? 1 : 0);
      if (goal) {
        _pGoals++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
      } else {
        _streak = 0;
      }
    } else {
      _cAtt++;
      _cHist.add(goal ? 1 : 0);
      if (o == _Outcome.saved) _saves++;
    }

    _celebrate(o);
    _phase = _Phase.aftermath;
    _pt = 0;
    _hint = '';
    setState(() {});
  }

  void _celebrate(_Outcome o) {
    final sc = _sc;
    final goal = o == _Outcome.goal;
    final good = (_playerTurn && goal) || (!_playerTurn && !goal);
    if (goal) {
      sc.netAge = 0;
      sc.netX = _tx;
      sc.netY = _ty;
      sc.shake = 6;
    }
    if (o == _Outcome.post) sc.shake = 12;
    if (o == _Outcome.saved) sc.shake = 4;
    if (good) {
      sc.hype = 1;
      _confetti(goal ? 60 : 30);
    }
    if (_playerTurn) {
      switch (o) {
        case _Outcome.goal:
          _setBanner(_streak >= 3 ? 'ON FIRE!' : 'GOAL!', _lime);
          break;
        case _Outcome.saved:
          _setBanner('SAVED!', _ice);
          break;
        case _Outcome.wide:
          _setBanner('WIDE!', _red);
          break;
        case _Outcome.over:
          _setBanner('OVER THE BAR!', _red);
          break;
        case _Outcome.post:
          _setBanner('OFF THE POST!', _gold);
          break;
      }
    } else {
      switch (o) {
        case _Outcome.goal:
          _setBanner('THEY SCORE', _red);
          break;
        case _Outcome.saved:
          _setBanner('WHAT A SAVE!', _lime);
          break;
        case _Outcome.wide:
        case _Outcome.over:
          _setBanner('THEY MISS!', _lime);
          break;
        case _Outcome.post:
          _setBanner('OFF THE POST!', _gold);
          break;
      }
    }
    switch (o) {
      case _Outcome.goal:
        _haptic(2);
        break;
      case _Outcome.post:
        _haptic(2);
        break;
      case _Outcome.saved:
        _haptic(1);
        break;
      default:
        _haptic(0);
    }
  }

  void _setBanner(String text, Color color) {
    _banner = text;
    _bannerColor = color;
    _bannerId++;
  }

  void _confetti(int count) {
    final w = _size.width, h = _size.height;
    final colors = <Color>[
      widget.setup.homeColor,
      _gold,
      _lime,
      Colors.white,
      widget.setup.awayColor,
    ];
    for (int i = 0; i < count; i++) {
      _sc.particles.add(_Particle(
        w * (.15 + _rng.nextDouble() * .7),
        h * (.28 + _rng.nextDouble() * .1),
        (_rng.nextDouble() - .5) * 520,
        -(160 + _rng.nextDouble() * 420),
        _rng.nextDouble() * 6,
        (_rng.nextDouble() - .5) * 14,
        6 + _rng.nextDouble() * 7,
        1.6 + _rng.nextDouble() * .8,
        colors[_rng.nextInt(colors.length)],
      ));
    }
  }

  void _updateAftermath(double dt) {
    final sc = _sc;
    _bvy -= 9.8 * dt;
    sc.bx += _bvx * dt;
    sc.by += _bvy * dt;
    sc.bz += _bvz * dt;
    if (sc.by < .105) {
      sc.by = .105;
      _bvy = -_bvy * .42;
      _bvx *= .75;
      _bvz *= .75;
      if (_bvy.abs() < .6) _bvy = 0;
    }
    if (sc.by <= .11) {
      _bvx *= math.max(0, 1 - 2 * dt);
      _bvz *= math.max(0, 1 - 2 * dt);
    }
    if (_outcome == _Outcome.goal) {
      if (sc.bz < -_depth + .15) {
        sc.bz = -_depth + .15;
        _bvz *= -.12;
        _bvx *= .4;
      }
      if (sc.bx.abs() > _hw - .12) {
        sc.bx = (_hw - .12) * (sc.bx >= 0 ? 1.0 : -1.0);
        _bvx *= -.3;
      }
    }
    if (sc.trail.isNotEmpty) sc.trail.removeAt(0);
  }

  bool _isMatchDecided() {
    if (_training) return _pAtt >= 10;
    final reg = _reg;
    if (_pAtt < reg || _cAtt < reg) {
      final pRem = reg - _pAtt;
      final cRem = reg - _cAtt;
      return _pGoals > _cGoals + cRem || _cGoals > _pGoals + pRem;
    }
    return _pAtt == _cAtt && _pGoals != _cGoals;
  }

  void _advance() {
    if (_isMatchDecided()) {
      final won = _training || _pGoals > _cGoals;
      _phase = _Phase.finished;
      _pt = 0;
      if (_training) {
        _setBanner('FULL TIME', _gold);
      } else {
        _setBanner(won ? 'YOU WIN!' : 'YOU LOSE', won ? _gold : _red);
      }
      if (won && !_training) {
        _sc.hype = 1;
        _confetti(90);
      }
      setState(() {});
      return;
    }
    setState(() {
      _playerTurn = _training ? true : !_playerTurn;
      _beginTurn();
    });
  }

  MatchResult _buildResult() => MatchResult(
        goals: _pGoals,
        oppGoals: _cGoals,
        attempts: _pAtt,
        oppAttempts: _cAtt,
        saves: _saves,
        bestStreak: _bestStreak,
        won: _training || _pGoals > _cGoals,
      );

  // ── Feedback ───────────────────────────────────────────────────────────────

  void _sfx() {
    if (widget.setup.sound) SystemSound.play(SystemSoundType.click);
  }

  void _haptic(int level) {
    if (!widget.setup.vibration) return;
    switch (level) {
      case 2:
        HapticFeedback.heavyImpact();
        break;
      case 1:
        HapticFeedback.mediumImpact();
        break;
      default:
        HapticFeedback.lightImpact();
    }
  }

  // ── Input ──────────────────────────────────────────────────────────────────

  bool get _canShoot => _playerTurn && _phase == _Phase.aim && !_paused;
  bool get _canDive =>
      !_playerTurn &&
      !_diveChosen &&
      !_paused &&
      (_phase == _Phase.aim || _phase == _Phase.runUp || _phase == _Phase.flight);

  _Aim? _aimFrom(List<Offset> pts) {
    if (pts.length < 2) return null;
    final a = pts.first;
    final b = pts.last;
    final dx = b.dx - a.dx;
    final up = a.dy - b.dy;
    if (up < 45) return null;
    final tx = dx / (_size.width * .26) * _hw;
    final ty = .1 + (up - 45) / (_size.height * .30) * 2.4;
    double curve = 0;
    final v = b - a;
    final len = v.distance;
    if (len > 1 && pts.length > 4) {
      final nx = -v.dy / len;
      final ny = v.dx / len;
      double best = 0;
      for (final p in pts) {
        final dev = (p.dx - a.dx) * nx + (p.dy - a.dy) * ny;
        if (dev.abs() > best.abs()) best = dev;
      }
      curve = _c(best / 42, -1, 1);
    }
    return _Aim(_c(tx, -5.4, 5.4), _c(ty, .1, 3.3), curve);
  }

  void _onPanStart(DragStartDetails d) {
    _dragPts = <Offset>[d.localPosition];
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _dragPts.add(d.localPosition);
    if (_canShoot) {
      _sc.dragTrail = List<Offset>.of(_dragPts);
      final a = _aimFrom(_dragPts);
      _sc.reticle = a == null ? null : Offset(a.tx, a.ty);
      _sc.reticleCurve = a == null ? 0 : a.curve;
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_canShoot) {
      final aim = _aimFrom(_dragPts);
      _sc.dragTrail = const <Offset>[];
      _sc.reticle = null;
      if (aim != null) {
        final speed = d.velocity.pixelsPerSecond.distance;
        final power = .3 + .7 * _clamp01((speed - 500) / 3000);
        _launchPlayerShot(aim, power);
      }
    } else if (_canDive && _dragPts.length > 1) {
      final v = _dragPts.last - _dragPts.first;
      if (v.distance < 24) {
        _diveAtPoint(_dragPts.first);
      } else {
        final col = v.dx < -28 ? 0 : (v.dx > 28 ? 2 : 1);
        final row = v.dy < -28 ? 1 : 0;
        _registerDive(col, row);
      }
    }
    _dragPts = <Offset>[];
  }

  void _onPanCancel() {
    _dragPts = <Offset>[];
    _sc.dragTrail = const <Offset>[];
    _sc.reticle = null;
  }

  void _onTapUp(TapUpDetails d) {
    if (_canDive) _diveAtPoint(d.localPosition);
  }

  void _diveAtPoint(Offset p) {
    final cam = _Cam(_size, _sc.zoom);
    final tl = cam.p(-_hw, _gh, 0);
    final br = cam.p(_hw, 0, 0);
    final w = br.dx - tl.dx;
    final col = p.dx < tl.dx + w / 3 ? 0 : (p.dx > tl.dx + w * 2 / 3 ? 2 : 1);
    final row = p.dy < (tl.dy + br.dy) / 2 ? 1 : 0;
    _registerDive(col, row);
  }

  void _registerDive(int col, int row) {
    if (!_canDive) return;
    _diveChosen = true;
    _kCol = col;
    _kRow = row;
    _sc.diveZone = col + row * 3;
    if (_phase == _Phase.flight) {
      _decideDefence(lateT: _clamp01(_pt / _flightDur));
      _startDive(.02);
    }
    setState(() => _hint = '');
  }

  Future<void> _confirmExit() async {
    setState(() => _paused = true);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: const Text('Leave shootout?'),
        content: const Text('Your current match progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP PLAYING')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: _ink),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      widget.onExit();
    } else {
      setState(() => _paused = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: LayoutBuilder(builder: (context, box) {
          _size = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            onTapUp: _onTapUp,
            child: CustomPaint(painter: _painter, size: Size.infinite),
          );
        }),
      ),
      Positioned(top: 0, left: 0, right: 0, child: _hud()),
      if (_hint.isNotEmpty && _phase != _Phase.aftermath && _phase != _Phase.finished)
        Positioned(left: 16, right: 16, bottom: 18, child: IgnorePointer(child: _hintChip())),
      _bannerWidget(),
    ]);
  }

  Widget _hintChip() {
    final shoot = _playerTurn && _phase == _Phase.aim;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xCC071019),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(shoot ? Icons.swipe_up_rounded : Icons.pan_tool_alt_rounded, color: _lime, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(_hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
          ),
        ]),
      ),
    );
  }

  Widget _bannerWidget() {
    final b = _banner;
    if (b == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: _size.height * .40,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          key: ValueKey<int>(_bannerId),
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Opacity(
            opacity: _clamp01(v * 1.4),
            child: Transform.scale(
              scale: .55 + .45 * v,
              child: Center(
                child: Text(
                  b,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _bannerColor,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Colors.black.withOpacity(.65), blurRadius: 14, offset: const Offset(0, 4)),
                      Shadow(color: _bannerColor.withOpacity(.45), blurRadius: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    final s = widget.setup;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(children: [
        Row(children: [
          IconButton(
            onPressed: _confirmExit,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(backgroundColor: const Color(0xAA101D2A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
              Text(s.subtitle, style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 1)),
            ]),
          ),
          if (!_training)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (_playerTurn ? _lime : _ice).withOpacity(.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (_playerTurn ? _lime : _ice).withOpacity(.45)),
              ),
              child: Text(
                _phase == _Phase.finished ? 'FULL TIME' : (_playerTurn ? 'YOU SHOOT' : 'YOU SAVE'),
                style: TextStyle(color: _playerTurn ? _lime : _ice, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        _scoreboard(),
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.8)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
      );

  Widget _dots(List<int> hist, bool active, WrapAlignment align) {
    final pending = active && _phase != _Phase.finished ? 1 : 0;
    final total = math.max(_reg, hist.length + pending);
    return Wrap(
      alignment: align,
      spacing: 4,
      runSpacing: 4,
      children: List<Widget>.generate(total, (i) {
        final done = i < hist.length;
        final isNext = i == hist.length && active && _phase != _Phase.finished;
        final color = done ? (hist[i] == 1 ? _lime : _red) : Colors.transparent;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: done ? color : (isNext ? _gold : Colors.white.withOpacity(.22)),
              width: isNext ? 2 : 1.2,
            ),
          ),
          child: done
              ? Icon(hist[i] == 1 ? Icons.check_rounded : Icons.close_rounded, size: 9, color: _ink)
              : null,
        );
      }),
    );
  }

  Widget _scoreboard() {
    final s = widget.setup;
    final box = BoxDecoration(
      color: const Color(0xE6101D2A),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.08)),
    );
    if (_training) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: box,
        child: Row(children: [
          _badge(s.homeShort, s.homeColor),
          const SizedBox(width: 10),
          const Text('GOALS', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(width: 8),
          Text('$_pGoals', style: const TextStyle(color: _lime, fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          Text('KICK ${math.min(_pAtt + 1, 10)} / 10',
              style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: box,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          _badge(s.homeShort, s.homeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(s.homeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          Text('$_pGoals', style: const TextStyle(color: _lime, fontSize: 26, fontWeight: FontWeight.w900)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('-', style: TextStyle(color: _muted, fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Text('$_cGoals', style: const TextStyle(color: _gold, fontSize: 26, fontWeight: FontWeight.w900)),
          Expanded(
            child: Text(s.awayName,
                maxLines: 1,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          _badge(s.awayShort, s.awayColor),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _dots(_pHist, _playerTurn, WrapAlignment.start)),
          const SizedBox(width: 10),
          Expanded(child: _dots(_cHist, !_playerTurn, WrapAlignment.end)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  final _Scene sc;
  final MatchSetup setup;
  _PitchPainter(this.sc, this.setup) : super(repaint: sc);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _Cam(size, sc.zoom);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (sc.shake > 0) {
      canvas.translate(math.sin(sc.time * 91) * sc.shake, math.cos(sc.time * 77) * sc.shake);
    }

    _backdrop(canvas, size, cam);
    _ground(canvas, size, cam);
    _net(canvas, cam);
    final ballBehind = sc.bz < .2;
    if (ballBehind) _ball(canvas, cam);
    _frame(canvas, cam);
    _keeper(canvas, cam);
    if (!ballBehind) _ball(canvas, cam);
    _shooter(canvas, cam);
    _zones(canvas, cam);
    _preview(canvas, cam);
    _particles(canvas);
    canvas.restore();
  }

  // ── Stadium ───────────────────────────────────────────────────────────────

  void _backdrop(Canvas canvas, Size size, _Cam cam) {
    final standBase = cam.p(0, 0, -9).dy;
    final rect = Rect.fromLTWH(-20, -20, size.width + 40, standBase + 20);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF040910), Color(0xFF0C1A2B), Color(0xFF15283B)],
        ).createShader(rect),
    );

    final boardTop = cam.p(0, 1.05, -7).dy;
    final boardBottom = cam.p(0, 0, -7).dy;
    final palette = <Color>[
      setup.homeColor,
      setup.awayColor,
      Colors.white,
      _gold,
      const Color(0xFF6C7E91),
      const Color(0xFF2B3A4A),
    ];
    final groups = List<List<Offset>>.generate(palette.length, (_) => <Offset>[]);
    const gap = 9.0;
    final rows = math.max(0, ((boardTop - 8) / gap).floor());
    final cols = (size.width / gap).ceil() + 2;
    final energy = math.max(sc.hype, .12);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final h = ((r * 73856093) ^ (c * 19349663)) & 0x7fffffff;
        final bounce = -math.sin(sc.time * 8 + (h % 17)).abs() * energy * 4;
        groups[h % palette.length].add(Offset(c * gap + (r.isOdd ? gap / 2 : 0), 8 + r * gap + bounce));
      }
    }
    for (int i = 0; i < palette.length; i++) {
      canvas.drawPoints(
        ui.PointMode.points,
        groups[i],
        Paint()
          ..color = palette[i].withOpacity(i >= 4 ? .5 : .72)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
    }
    // dim the crowd at the top
    final dim = Rect.fromLTRB(0, 0, size.width, boardTop);
    canvas.drawRect(
      dim,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(.55), Colors.transparent],
        ).createShader(dim),
    );

    // Advertising boards
    final board = Rect.fromLTRB(0, boardTop, size.width, boardBottom);
    canvas.drawRect(board, Paint()..color = const Color(0xFF0A1420));
    final segColors = <Color>[setup.homeColor, _lime, setup.awayColor, Colors.white];
    const seg = 64.0;
    for (int i = 0; i * seg < size.width; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * seg + 6, boardTop + 3, seg - 12, math.max(2, board.height - 6)),
        Paint()..color = segColors[i % 4].withOpacity(.5),
      );
    }

    // Floodlights
    for (final cx in <double>[size.width * .1, size.width * .9]) {
      final c = Offset(cx, 14);
      canvas.drawCircle(
        c,
        110,
        Paint()
          ..shader = RadialGradient(colors: [Colors.white.withOpacity(.38), Colors.transparent])
              .createShader(Rect.fromCircle(center: c, radius: 110)),
      );
    }
  }

  void _ground(Canvas canvas, Size size, _Cam cam) {
    final top = cam.p(0, 0, -7).dy;
    canvas.drawRect(Rect.fromLTRB(-20, top, size.width + 20, size.height + 20), Paint()..color = const Color(0xFF14543B));
    final zMax = cam.camZ - .8;
    final light = Paint()..color = const Color(0xFF1B6A48);
    int i = 0;
    for (double z = -7; z < zMax; z += 3.05) {
      final zb = math.min(z + 3.05, zMax);
      if (i.isEven) {
        final path = Path()
          ..moveTo(cam.p(-45, 0, z).dx, cam.p(-45, 0, z).dy)
          ..lineTo(cam.p(45, 0, z).dx, cam.p(45, 0, z).dy)
          ..lineTo(cam.p(45, 0, zb).dx, cam.p(45, 0, zb).dy)
          ..lineTo(cam.p(-45, 0, zb).dx, cam.p(-45, 0, zb).dy)
          ..close();
        canvas.drawPath(path, light);
      }
      i++;
    }
    final fog = Rect.fromLTRB(0, top, size.width, top + 130);
    canvas.drawRect(
      fog,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(.32), Colors.transparent],
        ).createShader(fog),
    );

    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    void seg(double x1, double z1, double x2, double z2) => canvas.drawLine(cam.p(x1, 0, z1), cam.p(x2, 0, z2), line);
    seg(-34, 0, 34, 0);
    seg(-9.16, 0, -9.16, 5.5);
    seg(9.16, 0, 9.16, 5.5);
    seg(-9.16, 5.5, 9.16, 5.5);
    seg(-20.16, 0, -20.16, zMax);
    seg(20.16, 0, 20.16, zMax);

    final k = cam.s(_spotZ);
    canvas.drawOval(
      Rect.fromCenter(center: cam.p(0, 0, _spotZ), width: .34 * k, height: .13 * k),
      Paint()..color = Colors.white.withOpacity(.9),
    );
  }

  // ── Goal ──────────────────────────────────────────────────────────────────

  void _net(Canvas canvas, _Cam cam) {
    Offset np(double x, double y, double z) {
      var zz = z;
      if (sc.netAge < 2.0 && z < -.3) {
        final d2 = (x - sc.netX) * (x - sc.netX) + (y - sc.netY) * (y - sc.netY);
        final amp = .7 * math.exp(-sc.netAge * 3.2) * math.cos(sc.netAge * 16);
        zz = z - amp * math.exp(-d2 / 1.6) * (-z / _depth);
      }
      return cam.p(x, y, zz);
    }

    // dark backing
    final back = Path()
      ..moveTo(np(-_hw, 0, -_depth).dx, np(-_hw, 0, -_depth).dy)
      ..lineTo(np(_hw, 0, -_depth).dx, np(_hw, 0, -_depth).dy)
      ..lineTo(np(_hw, _rearH, -_depth).dx, np(_hw, _rearH, -_depth).dy)
      ..lineTo(np(-_hw, _rearH, -_depth).dx, np(-_hw, _rearH, -_depth).dy)
      ..close();
    canvas.drawPath(back, Paint()..color = Colors.black.withOpacity(.28));

    final net = Paint()
      ..color = Colors.white.withOpacity(.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 12; i++) {
      final x = -_hw + _hw * 2 * i / 12;
      canvas.drawLine(np(x, 0, -_depth), np(x, _rearH, -_depth), net);
      canvas.drawLine(np(x, _gh, 0), np(x, _rearH, -_depth), net);
    }
    for (int j = 0; j <= 5; j++) {
      final y = _rearH * j / 5;
      canvas.drawLine(np(-_hw, y, -_depth), np(_hw, y, -_depth), net);
    }
    for (int k = 1; k <= 4; k++) {
      final z = -_depth * k / 4;
      final y = _lerp(_gh, _rearH, k / 4);
      canvas.drawLine(np(-_hw, y, z), np(_hw, y, z), net);
    }
    for (final sx in const <double>[-_hw, _hw]) {
      for (int k = 0; k <= 4; k++) {
        final z = -_depth * k / 4;
        final yTop = _lerp(_gh, _rearH, k / 4);
        canvas.drawLine(np(sx, 0, z), np(sx, yTop, z), net);
      }
      for (int i = 0; i <= 5; i++) {
        canvas.drawLine(np(sx, _gh * i / 5, 0), np(sx, _rearH * i / 5, -_depth), net);
      }
    }
  }

  void _frame(Canvas canvas, _Cam cam) {
    final w = math.max(3.0, .13 * cam.s(0));
    final shadow = Paint()
      ..color = Colors.black.withOpacity(.3)
      ..strokeWidth = w + 3
      ..strokeCap = StrokeCap.square
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = w
      ..strokeCap = StrokeCap.square;
    final thin = Paint()
      ..color = Colors.white.withOpacity(.65)
      ..strokeWidth = 1.6;
    final bl = cam.p(-_hw, 0, 0), br = cam.p(_hw, 0, 0), tl = cam.p(-_hw, _gh, 0), tr = cam.p(_hw, _gh, 0);
    canvas.drawLine(bl.translate(2, 3), tl.translate(2, 3), shadow);
    canvas.drawLine(br.translate(2, 3), tr.translate(2, 3), shadow);
    canvas.drawLine(tl.translate(0, 3), tr.translate(0, 3), shadow);
    canvas.drawLine(tl, cam.p(-_hw, _rearH, -_depth), thin);
    canvas.drawLine(tr, cam.p(_hw, _rearH, -_depth), thin);
    canvas.drawLine(bl, cam.p(-_hw, 0, -_depth), thin);
    canvas.drawLine(br, cam.p(_hw, 0, -_depth), thin);
    canvas.drawLine(bl, tl, post);
    canvas.drawLine(br, tr, post);
    canvas.drawLine(tl, tr, post);
  }

  // ── Characters ────────────────────────────────────────────────────────────

  void _limb(Canvas canvas, Offset pivot, double angle, double len, double width, Paint paint) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromLTRBR(-width / 2, 0, width / 2, len, Radius.circular(width / 2)),
      paint,
    );
    canvas.restore();
  }

  void _keeper(Canvas canvas, _Cam cam) {
    const z = .3;
    final k = cam.s(z);
    final c = cam.p(sc.kx, sc.ky, z);
    final g = cam.p(sc.kx, 0, z);
    canvas.drawOval(
      Rect.fromCenter(center: g, width: 1.3 * k, height: .3 * k),
      Paint()..color = Colors.black.withOpacity(_c(.32 - sc.ky * .08, .1, .3)),
    );
    final kit = sc.keeperColor;
    final dark = Color.lerp(kit, Colors.black, .55)!;
    final skin = Paint()..color = const Color(0xFFC68642);
    final e = sc.kArms;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sc.kRot);
    canvas.scale(k);

    // legs
    final legAngle = _lerp(.06, .3, e);
    final legPaint = Paint()..color = dark;
    _limb(canvas, const Offset(-.1, .25), legAngle, .88, .18, legPaint);
    _limb(canvas, const Offset(.1, .25), -legAngle, .88, .18, legPaint);
    // boots
    final boot = Paint()..color = Colors.black;
    canvas.save();
    canvas.translate(-.1, .25);
    canvas.rotate(legAngle);
    canvas.drawRRect(RRect.fromLTRBR(-.1, .8, .1, .95, const Radius.circular(.06)), boot);
    canvas.restore();
    canvas.save();
    canvas.translate(.1, .25);
    canvas.rotate(-legAngle);
    canvas.drawRRect(RRect.fromLTRBR(-.1, .8, .1, .95, const Radius.circular(.06)), boot);
    canvas.restore();

    // torso
    final torso = RRect.fromLTRBR(-.27, -.44, .27, .32, const Radius.circular(.11));
    canvas.drawRRect(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(kit, Colors.white, .22)!, kit, dark],
        ).createShader(torso.outerRect),
    );

    // arms + gloves
    final armPaint = Paint()..color = kit;
    final armL = _lerp(.5, math.pi - .28, e);
    _limb(canvas, const Offset(-.28, -.34), armL, .6, .15, armPaint);
    _limb(canvas, const Offset(.28, -.34), -armL, .6, .15, armPaint);
    for (final sgn in const <double>[-1, 1]) {
      canvas.save();
      canvas.translate(.28 * sgn, -.34);
      canvas.rotate(armL * -sgn);
      canvas.drawCircle(const Offset(0, .64), .12, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(0, .64), .12, Paint()
        ..color = Colors.black.withOpacity(.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .025);
      canvas.restore();
    }

    // head
    canvas.drawCircle(const Offset(0, -.63), .165, skin);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -.65), radius: .17),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF1B1410),
    );
    canvas.restore();
  }

  void _shooter(Canvas canvas, _Cam cam) {
    final u = sc.runUp;
    final kk = sc.kick;
    final z = 12.4 - u * 1.05 - kk * .25;
    final x = -1.2 + u * .75 + kk * .1;
    if (cam.camZ - z < .9) return;
    final k = cam.s(z);
    final g = cam.p(x, 0, z);
    canvas.drawOval(
      Rect.fromCenter(center: g, width: 1.0 * k, height: .26 * k),
      Paint()..color = Colors.black.withOpacity(.28),
    );

    final shirt = sc.shooterColor;
    final shirtDark = Color.lerp(shirt, Colors.black, .35)!;
    final running = u > 0 && u < 1 && kk == 0;
    final phase = u * math.pi * 5;
    final bob = running ? math.sin(phase).abs() * .05 : 0.0;
    final kickSwing = math.sin(math.pi * kk);

    canvas.save();
    canvas.translate(g.dx, g.dy - bob * k);
    canvas.scale(k);

    final skin = Paint()..color = const Color(0xFFC68642);
    final short = Paint()..color = Colors.white;
    final sock = Paint()..color = shirt;
    final boot = Paint()..color = const Color(0xFF111111);

    for (int side = 0; side < 2; side++) {
      final sx = side == 0 ? -.11 : .11;
      double lift = 0;
      if (running) lift = math.max(0, math.sin(phase + side * math.pi)) * .3;
      if (side == 1 && kk > 0) lift = kickSwing * .5;
      final len = .92 * (1 - lift);
      canvas.save();
      canvas.translate(sx, -.92);
      canvas.drawRRect(RRect.fromLTRBR(-.085, 0, .085, len, const Radius.circular(.08)), skin);
      canvas.drawRRect(RRect.fromLTRBR(-.095, len * .55, .095, len - .05, const Radius.circular(.05)), sock);
      canvas.drawRRect(RRect.fromLTRBR(-.1, 0, .1, .4, const Radius.circular(.06)), short);
      canvas.drawRRect(RRect.fromLTRBR(-.1, len - .06, .1, len + .05, const Radius.circular(.05)), boot);
      canvas.restore();
    }

    // arms
    final armSwing = running ? math.sin(phase) * .35 : 0.0;
    final armPaint = Paint()..color = shirt;
    _limb(canvas, const Offset(-.31, -1.5), .16 + armSwing, .6, .14, armPaint);
    _limb(canvas, const Offset(.31, -1.5), -.16 + armSwing, .6, .14, armPaint);

    // torso
    final torso = RRect.fromLTRBR(-.28, -1.58, .28, -.84, const Radius.circular(.1));
    canvas.drawRRect(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(shirt, Colors.white, .18)!, shirt, shirtDark],
        ).createShader(torso.outerRect),
    );
    // number
    final tp = TextPainter(
      text: TextSpan(
        text: '10',
        style: TextStyle(
          color: shirt.computeLuminance() > .55 ? Colors.black87 : Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(0, -1.25);
    canvas.scale(.01);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();

    // head
    canvas.drawCircle(const Offset(0, -1.74), .15, skin);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(0, -1.75), radius: .155),
      math.pi * .95,
      math.pi * 1.1,
      true,
      Paint()..color = const Color(0xFF1B1410),
    );
    canvas.restore();
  }

  // ── Ball ──────────────────────────────────────────────────────────────────

  void _ball(Canvas canvas, _Cam cam) {
    if (cam.camZ - sc.bz < .7) return;
    final k = cam.s(sc.bz);
    final c = cam.p(sc.bx, sc.by, sc.bz);
    final r = math.max(2.0, .115 * k);

    final g = cam.p(sc.bx, 0, sc.bz);
    final sh = (1 - math.min(1.0, sc.by / 3)) * .35;
    canvas.drawOval(
      Rect.fromCenter(center: g, width: r * 2.3, height: r * .8),
      Paint()..color = Colors.black.withOpacity(sh),
    );

    final n = sc.trail.length;
    for (int i = 0; i < n; i++) {
      final t = sc.trail[i];
      if (cam.camZ - t[2] < .7) continue;
      final f = (i + 1) / n;
      canvas.drawCircle(
        cam.p(t[0], t[1], t[2]),
        math.max(1.0, .1 * cam.s(t[2]) * f),
        Paint()..color = Colors.white.withOpacity(.22 * f),
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    final circle = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: [Colors.white, Color(0xFFD9DEE3), Color(0xFF9AA5AF)],
          stops: [0, .6, 1],
        ).createShader(circle),
    );
    canvas.clipPath(Path()..addOval(circle));
    final patch = Paint()..color = const Color(0xFF1B232B);
    for (int i = 0; i < 5; i++) {
      final a = sc.spin + i * math.pi * 2 / 5;
      canvas.drawCircle(Offset(math.cos(a), math.sin(a)) * r * .66, r * .24, patch);
    }
    canvas.drawCircle(Offset(math.sin(sc.spin) * r * .12, math.cos(sc.spin) * r * .12), r * .28, patch);
    canvas.restore();
  }

  // ── Overlays ──────────────────────────────────────────────────────────────

  void _zones(Canvas canvas, _Cam cam) {
    if (!sc.showZones) return;
    final pulse = .5 + .5 * math.sin(sc.time * 5);
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 3; col++) {
        final x0 = -_hw + col * _hw * 2 / 3;
        final x1 = x0 + _hw * 2 / 3;
        final y0 = row == 0 ? 0.0 : _gh / 2;
        final y1 = row == 0 ? _gh / 2 : _gh;
        final r = Rect.fromPoints(cam.p(x0, y1, 0), cam.p(x1, y0, 0)).deflate(2);
        final chosen = sc.diveZone == col + row * 3;
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = (chosen ? _gold : _lime).withOpacity(chosen ? .28 : .04 + .05 * pulse),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()
            ..color = (chosen ? _gold : _lime).withOpacity(.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  void _preview(Canvas canvas, _Cam cam) {
    if (sc.dragTrail.length > 1) {
      final path = Path()..moveTo(sc.dragTrail.first.dx, sc.dragTrail.first.dy);
      for (int i = 1; i < sc.dragTrail.length; i++) {
        path.lineTo(sc.dragTrail[i].dx, sc.dragTrail[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _lime.withOpacity(.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _lime
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final r = sc.reticle;
    if (r == null) return;
    final tgt = cam.p(r.dx, r.dy, 0);
    final ball = cam.p(0, .105, _spotZ);
    final inside = r.dx.abs() < _hw && r.dy < _gh;
    final color = inside ? _lime : _red;

    final dir = tgt - ball;
    final len = dir.distance;
    if (len > 1) {
      final mid = Offset.lerp(ball, tgt, .5)!;
      final n = Offset(-dir.dy, dir.dx) / len;
      final ctrl = mid + n * (sc.reticleCurve * len * .22);
      final path = Path()
        ..moveTo(ball.dx, ball.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tgt.dx, tgt.dy);
      final dot = Paint()..color = Colors.white.withOpacity(.8);
      for (final m in path.computeMetrics()) {
        for (double d = 14; d < m.length; d += 14) {
          final t = m.getTangentForOffset(d);
          if (t != null) canvas.drawCircle(t.position, 2.2, dot);
        }
      }
    }
    final rad = math.max(9.0, .3 * cam.s(0));
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(tgt, rad, ring);
    canvas.drawCircle(tgt, rad * .45, ring..strokeWidth = 1.6);
    canvas.drawLine(tgt.translate(-rad * 1.4, 0), tgt.translate(-rad * .7, 0), ring);
    canvas.drawLine(tgt.translate(rad * .7, 0), tgt.translate(rad * 1.4, 0), ring);
    canvas.drawLine(tgt.translate(0, -rad * 1.4), tgt.translate(0, -rad * .7), ring);
    canvas.drawLine(tgt.translate(0, rad * .7), tgt.translate(0, rad * 1.4), ring);
  }

  void _particles(Canvas canvas) {
    final paint = Paint();
    for (final p in sc.particles) {
      paint.color = p.color.withOpacity(_clamp01(p.life / 1.2));
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .5), paint);
      canvas.restore();
    }
  }
}
