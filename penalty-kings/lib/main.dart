import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const ink = Color(0xFF071019);
const panel = Color(0xFF101D2A);
const panel2 = Color(0xFF172838);
const lime = Color(0xFFC7F36B);
const muted = Color(0xFF8DA1B3);
const red = Color(0xFFFF6878);
const gold = Color(0xFFFFC65C);
const keeperKits = <Color>[Color(0xFFFFB83F), Color(0xFF55B8FF), Color(0xFFFF6B8A), Color(0xFFB48CFF)];
const keeperKitNames = <String>['GOLDEN CAPTAIN', 'ICE BLUE', 'NEON STRIKER', 'ROYAL PURPLE'];

class TeamOption {
  final String id, name, shortName;
  final Color color;
  const TeamOption(this.id, this.name, this.shortName, this.color);
}
const clubTeams = <TeamOption>[
  TeamOption('man_city','Manchester City','MCI',Color(0xFF6CABDD)),
  TeamOption('man_utd','Manchester United','MUN',Color(0xFFDA291C)),
  TeamOption('liverpool','Liverpool','LIV',Color(0xFFC8102E)),
  TeamOption('arsenal','Arsenal','ARS',Color(0xFFEF0107)),
  TeamOption('chelsea','Chelsea','CHE',Color(0xFF034694)),
  TeamOption('tottenham','Tottenham Hotspur','TOT',Color(0xFF132257)),
  TeamOption('newcastle','Newcastle United','NEW',Color(0xFF241F20)),
  TeamOption('aston_villa','Aston Villa','AVL',Color(0xFF670E36)),
  TeamOption('real_madrid','Real Madrid','RMA',Color(0xFFFEBE10)),
  TeamOption('barcelona','Barcelona','BAR',Color(0xFFA50044)),
  TeamOption('atletico','Atlético Madrid','ATM',Color(0xFFCB3524)),
  TeamOption('bayern','Bayern Munich','BAY',Color(0xFFDC052D)),
  TeamOption('dortmund','Borussia Dortmund','BVB',Color(0xFFFDE100)),
  TeamOption('psg','Paris Saint-Germain','PSG',Color(0xFF004170)),
  TeamOption('inter','Inter Milan','INT',Color(0xFF0068A8)),
  TeamOption('milan','AC Milan','MIL',Color(0xFFFB090B)),
  TeamOption('juventus','Juventus','JUV',Color(0xFF222222)),
  TeamOption('napoli','Napoli','NAP',Color(0xFF00AEEF)),
  TeamOption('ajax','Ajax','AJA',Color(0xFFD2122E)),
  TeamOption('benfica','Benfica','BEN',Color(0xFFE32219)),
];
const nationalTeams = <TeamOption>[
  TeamOption('nigeria','Nigeria','NGA',Color(0xFF008751)),
  TeamOption('egypt','Egypt','EGY',Color(0xFFCE1126)),
  TeamOption('ghana','Ghana','GHA',Color(0xFF006B3F)),
  TeamOption('senegal','Senegal','SEN',Color(0xFF00853F)),
  TeamOption('morocco','Morocco','MAR',Color(0xFFC1272D)),
  TeamOption('ivory_coast','Ivory Coast','CIV',Color(0xFFF77F00)),
  TeamOption('south_africa','South Africa','RSA',Color(0xFF007A4D)),
  TeamOption('england','England','ENG',Color(0xFFCE1124)),
  TeamOption('france','France','FRA',Color(0xFF0055A4)),
  TeamOption('spain','Spain','ESP',Color(0xFFAA151B)),
  TeamOption('portugal','Portugal','POR',Color(0xFFDA291C)),
  TeamOption('germany','Germany','GER',Color(0xFF222222)),
  TeamOption('italy','Italy','ITA',Color(0xFF009246)),
  TeamOption('netherlands','Netherlands','NED',Color(0xFFFF6600)),
  TeamOption('brazil','Brazil','BRA',Color(0xFFFFDF00)),
  TeamOption('argentina','Argentina','ARG',Color(0xFF75AADB)),
  TeamOption('uruguay','Uruguay','URU',Color(0xFF5CC6E8)),
  TeamOption('usa','United States','USA',Color(0xFF3C3B6E)),
  TeamOption('mexico','Mexico','MEX',Color(0xFF006847)),
  TeamOption('japan','Japan','JPN',Color(0xFFBC002D)),
];
TeamOption teamById(String id) => [...clubTeams, ...nationalTeams]
    .firstWhere((team) => team.id == id, orElse: () => clubTeams.first);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: ink,
    systemNavigationBarColor: ink,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const PenaltyKingsApp());
}

class PenaltyKingsApp extends StatelessWidget {
  const PenaltyKingsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Penalty Kings',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: lime,
          brightness: Brightness.dark,
          surface: panel,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const KingsShell(),
    );
  }
}

enum GameMode { quick, golden, training, tournament }
enum Screen { home, match, result, settings, career }

class KingsShell extends StatefulWidget {
  const KingsShell({super.key});

  @override
  State<KingsShell> createState() => _KingsShellState();
}

class _KingsShellState extends State<KingsShell> with TickerProviderStateMixin {
  final math.Random _random = math.Random();
  late final AnimationController _shotAnimation;
  late final AnimationController _pulseAnimation;
  Screen _screen = Screen.home;
  GameMode _mode = GameMode.quick;
  String _difficulty = 'PRO';
  bool _sound = true;
  bool _vibration = true;
  bool _tutorialSeen = false;
  int _keeperKitIndex = 0;
  TeamOption _selectedTeam = clubTeams[0];
  TeamOption _selectedOpponent = clubTeams[3];
  final List<String> _leaderboard = <String>[];
  int _tournamentRound = 1;
  int _opponentScore = 0;
  String _opponentName = 'NORTH CITY';
  int _bestScore = 0;
  int _bestStreak = 0;
  int _careerShots = 0;
  int _careerGoals = 0;
  int _careerSaves = 0;
  int _matchesPlayed = 0;
  int _score = 0;
  int _attempts = 0;
  int _streak = 0;
  int _saves = 0;
  int _round = 1;
  int _keeperLane = 1;
  int _keeperVertical = 1;
  int _targetLane = 1;
  final List<int> _shotHistory = <int>[];
  int _matchBestStreak = 0;
  int _previousBestScore = 0;
  bool _newRecord = false;
  double _power = .72;
  Offset _aim = const Offset(.0, -.68);
  Offset _joystick = Offset.zero;
  bool _shotTaken = false;
  bool _goal = false;
  bool _saved = false;
  bool _wide = false;
  bool _isResolving = false;
  String _commentary = 'PICK YOUR CORNER';
  Timer? _nextShotTimer;

  int get _maxShots => (_mode == GameMode.quick || _mode == GameMode.tournament) ? 5 : 999;
  bool get _finished => (_mode == GameMode.quick || _mode == GameMode.tournament) && _attempts >= _maxShots;
  Color get _keeperKitColor => keeperKits[_keeperKitIndex.clamp(0, keeperKits.length - 1).toInt()];
  String get _modeTitle => switch (_mode) {
        GameMode.quick => 'QUICK SHOOTOUT',
        GameMode.golden => 'GOLDEN GOAL',
        GameMode.training => 'TRAINING GROUND',
        GameMode.tournament => 'KING’S CUP TOURNAMENT',
      };

  @override
  void initState() {
    super.initState();
    _shotAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat(reverse: true);
    _loadStats();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestScore = prefs.getInt('best_score') ?? 0;
      _difficulty = prefs.getString('difficulty') ?? 'PRO';
      _bestStreak = prefs.getInt('best_streak') ?? 0;
      _careerShots = prefs.getInt('career_shots') ?? 0;
      _careerGoals = prefs.getInt('career_goals') ?? 0;
      _careerSaves = prefs.getInt('career_saves') ?? 0;
      _matchesPlayed = prefs.getInt('matches_played') ?? 0;
      _sound = prefs.getBool('sound') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;
      _tutorialSeen = prefs.getBool('tutorial_seen') ?? false;
      _keeperKitIndex = (prefs.getInt('keeper_kit') ?? 0).clamp(0, keeperKits.length - 1).toInt();
      _selectedTeam = teamById(prefs.getString('selected_team') ?? 'man_city');
      _selectedOpponent = teamById(prefs.getString('selected_opponent') ?? 'arsenal');
      _leaderboard
        ..clear()
        ..addAll(prefs.getStringList('local_leaderboard') ?? <String>[]);
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('best_score', _bestScore);
    await prefs.setString('difficulty', _difficulty);
    await prefs.setInt('best_streak', _bestStreak);
    await prefs.setInt('career_shots', _careerShots);
    await prefs.setInt('career_goals', _careerGoals);
    await prefs.setInt('career_saves', _careerSaves);
    await prefs.setInt('matches_played', _matchesPlayed);
    await prefs.setBool('sound', _sound);
    await prefs.setBool('vibration', _vibration);
    await prefs.setBool('tutorial_seen', _tutorialSeen);
    await prefs.setInt('keeper_kit', _keeperKitIndex);
    await prefs.setString('selected_team', _selectedTeam.id);
    await prefs.setString('selected_opponent', _selectedOpponent.id);
    await prefs.setStringList('local_leaderboard', _leaderboard);
  }

  @override
  void dispose() {
    _nextShotTimer?.cancel();
    _shotAnimation.dispose();
    _pulseAnimation.dispose();
    super.dispose();
  }


  Future<void> _chooseTeamsAndStart(GameMode? mode) async {
    var national = nationalTeams.any((t) => t.id == _selectedTeam.id);
    var player = _selectedTeam;
    var opponent = _selectedOpponent;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => StatefulBuilder(builder: (context, updateSheet) {
        final teams = national ? nationalTeams : clubTeams;
        if (!teams.any((t) => t.id == player.id)) player = teams.first;
        if (!teams.any((t) => t.id == opponent.id) || opponent.id == player.id) {
          opponent = teams.firstWhere((t) => t.id != player.id);
        }
        Widget selector(String label, TeamOption selected, ValueChanged<TeamOption> onChanged) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: panel2, borderRadius: BorderRadius.circular(14)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: selected.id, isExpanded: true, dropdownColor: panel2, iconEnabledColor: lime,
                items: teams.map((t) => DropdownMenuItem<String>(
                  value: t.id,
                  child: Row(children: [_teamBadge(t,size:30), const SizedBox(width:10), Text(t.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800))]),
                )).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  onChanged(teams.firstWhere((t) => t.id == id));
                },
              )),
            ),
          ]);
        }
        return SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(20,18,20,18+MediaQuery.of(context).viewInsets.bottom),
          child: Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Expanded(child:Text('CHOOSE YOUR SIDES',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900,letterSpacing:1))),IconButton(onPressed:()=>Navigator.pop(sheetContext),icon:const Icon(Icons.close_rounded,color:muted))]),
            const Text('Choose your favourite team and the opponent you want to face.',style:TextStyle(color:muted,fontSize:11)),
            const SizedBox(height:15),
            Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:ink,borderRadius:BorderRadius.circular(13)),child:Row(children:[
              Expanded(child:_categoryChoice('CLUBS',!national,()=>updateSheet(() { national = false; player = clubTeams.first; opponent = clubTeams[3]; }))),
              Expanded(child:_categoryChoice('NATIONAL TEAMS',national,()=>updateSheet(() { national = true; player = nationalTeams.first; opponent = nationalTeams[7]; }))),
            ])),
            const SizedBox(height:16),
            selector('YOUR TEAM',player,(t)=>updateSheet(() { player = t; if (opponent.id == player.id) opponent = teams.firstWhere((x) => x.id != player.id); })),
            const SizedBox(height:12),
            selector('YOUR OPPONENT',opponent,(t)=>updateSheet(() { opponent = t; })),
            const SizedBox(height:16),
            Row(children:[Expanded(child:_teamPreview(player,'HOME')),Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Text('VS',style:TextStyle(color:gold,fontWeight:FontWeight.w900))),Expanded(child:_teamPreview(opponent,'AWAY'))]),
            const SizedBox(height:18),
            SizedBox(width:double.infinity,height:52,child:FilledButton(
              onPressed:player.id==opponent.id?null:(){
                setState(() { _selectedTeam = player; _selectedOpponent = opponent; });
                _saveStats();
                Navigator.pop(sheetContext);
                if (mode != null) _start(mode);
              },
              style:FilledButton.styleFrom(backgroundColor:lime,foregroundColor:ink,disabledBackgroundColor:panel2,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
              child:Text(mode == null ? 'SAVE TEAM SELECTION' : 'CONFIRM TEAMS & PLAY',style:const TextStyle(fontWeight:FontWeight.w900,letterSpacing:1)),
            )),
          ]),
        ));
      }),
    );
  }

  Widget _categoryChoice(String label,bool selected,VoidCallback onTap)=>InkWell(
    onTap:onTap,borderRadius:BorderRadius.circular(10),
    child:Container(padding:const EdgeInsets.symmetric(vertical:11),decoration:BoxDecoration(color:selected?lime:Colors.transparent,borderRadius:BorderRadius.circular(10)),
      child:Text(label,textAlign:TextAlign.center,style:TextStyle(color:selected?ink:muted,fontSize:9,fontWeight:FontWeight.w900,letterSpacing:.6))),
  );

  Widget _teamBadge(TeamOption team,{double size=38})=>Container(
    width:size,height:size,alignment:Alignment.center,
    decoration:BoxDecoration(color:team.color.withOpacity(.18),borderRadius:BorderRadius.circular(size*.28),border:Border.all(color:team.color.withOpacity(.7))),
    child:Text(team.shortName,style:TextStyle(color:team.color,fontSize:size*.25,fontWeight:FontWeight.w900)),
  );

  Widget _teamPreview(TeamOption team,String side)=>Container(
    padding:const EdgeInsets.symmetric(vertical:10,horizontal:7),decoration:BoxDecoration(color:ink,borderRadius:BorderRadius.circular(14)),
    child:Column(children:[_teamBadge(team,size:42),const SizedBox(height:6),Text(side,style:const TextStyle(color:muted,fontSize:8,fontWeight:FontWeight.w900)),const SizedBox(height:3),
      Text(team.name,textAlign:TextAlign.center,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))]),
  );

  Widget _matchupCard()=>Material(
    color:panel,borderRadius:BorderRadius.circular(18),
    child:InkWell(onTap:()=>_chooseTeamsAndStart(null),borderRadius:BorderRadius.circular(18),
      child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
        _teamBadge(_selectedTeam,size:42),const SizedBox(width:9),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('YOUR MATCHUP',style:TextStyle(color:muted,fontSize:8,fontWeight:FontWeight.w900,letterSpacing:1.2)),
          const SizedBox(height:4),
          Text(_selectedTeam.name+'  vs  '+_selectedOpponent.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),const Text('Tap to change clubs or national teams',style:TextStyle(color:muted,fontSize:9)),
        ])),
        _teamBadge(_selectedOpponent,size:42),const SizedBox(width:4),const Icon(Icons.edit_rounded,color:lime,size:17),
      ]))),
  );

  void _start(GameMode mode) {
    _nextShotTimer?.cancel();
    setState(() {
      _mode = mode;
      _tournamentRound = 1;
      _opponentName = _selectedOpponent.name;
      _opponentScore = mode == GameMode.tournament ? _random.nextInt(6) : 0;
      _score = 0;
      _attempts = 0;
      _shotHistory.clear();
      _matchBestStreak = 0;
      _previousBestScore = _bestScore;
      _newRecord = false;
      _streak = 0;
      _saves = 0;
      _round = 1;
      _shotTaken = false;
      _goal = false;
      _saved = false;
      _wide = false;
      _isResolving = false;
      _power = .72;
      _aim = const Offset(0, -.68);
      _commentary = 'PICK YOUR CORNER';
      _screen = Screen.match;
    });
    _shotAnimation.reset();
    if (!_tutorialSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _screen == Screen.match) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('HOW TO TAKE THE PERFECT PENALTY',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TutorialLine(icon: Icons.gamepad_rounded, text: 'Use the left virtual joystick to aim at a corner.'),
            SizedBox(height: 12),
            _TutorialLine(icon: Icons.bolt_rounded, text: 'Set your shot power with the power bar.'),
            SizedBox(height: 12),
            _TutorialLine(icon: Icons.sports_soccer_rounded, text: 'Tap SHOOT. The goalkeeper will try to read your shot.'),
            SizedBox(height: 12),
            _TutorialLine(icon: Icons.emoji_events_rounded, text: 'Score, build streaks and beat your personal best.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _tutorialSeen = true;
              _saveStats();
            },
            style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink),
            child: const Text('LET’S PLAY'),
          )
        ],
      ),
    );
  }

  void _setAim(Offset local, Size size) {
    if (_shotTaken || _isResolving) return;
    final x = ((local.dx / size.width) * 2 - 1).clamp(-.92, .92);
    final y = ((local.dy / size.height) * 2 - 1).clamp(-.92, .28);
    setState(() => _aim = Offset(x.toDouble(), y.toDouble()));
  }

  void _moveAimJoystick(Offset local, Size size) {
    if (_shotTaken || _isResolving) return;
    const center = 44.0;
    const radius = 31.0;
    var delta = local - const Offset(center, center);
    if (delta.distance > radius) {
      delta = Offset.fromDirection(delta.direction, radius);
    }
    setState(() {
      _joystick = delta / radius;
      _aim = Offset(
        _joystick.dx.clamp(-.92, .92).toDouble(),
        (-.68 + _joystick.dy * .65).clamp(-.92, .28).toDouble(),
      );
    });
  }

  void _releaseAimJoystick() {
    if (!mounted) return;
    setState(() => _joystick = Offset.zero);
  }

  void _shoot() {
    if (_shotTaken || _isResolving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final lane = _aim.dx < -.29 ? 0 : (_aim.dx > .29 ? 2 : 1);
    final vertical = _aim.dy < -.58 ? 0 : (_aim.dy > -.12 ? 2 : 1);
    final keeperRead = _random.nextInt(3);
    final keeperHeightRead = _random.nextInt(3);
    final difficultyFactor = switch (_difficulty) {
      'AMATEUR' => .36,
      'WORLD CLASS' => .59,
      _ => .48,
    };
    final keeperMatches = lane == keeperRead && vertical == keeperHeightRead;
    final lowPowerMiss = _power < .18;
    final overhit = _power > .97 && _random.nextDouble() < .22;
    final powerAdvantage = ((_power - .5) * .12).clamp(-.06, .06);
    final keeperSaveChance = (difficultyFactor - powerAdvantage + (_power < .38 ? .12 : 0)).clamp(.15, .82);
    final keeperSave = keeperMatches && _random.nextDouble() < keeperSaveChance;
    final isWide = lowPowerMiss || overhit || _random.nextDouble() < .025;
    final isGoal = !keeperSave && !isWide;

    setState(() {
      _shotTaken = true;
      _isResolving = true;
      _attempts++;
      _careerShots++;
      if (isGoal) _careerGoals++;
      if (keeperSave) _careerSaves++;
      _keeperLane = keeperRead;
      _keeperVertical = keeperHeightRead;
      _targetLane = lane;
      _shotHistory.add(isGoal ? 1 : keeperSave ? 2 : 3);
      _goal = isGoal;
      _saved = keeperSave;
      _wide = isWide;
      if (isGoal) {
        _score++;
        _streak++;
        _commentary = _streak >= 3 ? 'ICE IN YOUR VEINS!' : 'WHAT A FINISH!';
      } else if (keeperSave) {
        _saves++;
        _streak = 0;
        _commentary = 'THE KEEPER READ IT!';
      } else {
        _streak = 0;
        _commentary = 'JUST OFF TARGET!';
      }
      if (_score > _bestScore) _bestScore = _score;
      if (_streak > _bestStreak) _bestStreak = _streak;
      if (_streak > _matchBestStreak) _matchBestStreak = _streak;
      if (_score > _previousBestScore) _newRecord = true;
    });

    if (_vibration) {
      if (isGoal) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    _saveStats();
    _shotAnimation.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _nextShotTimer = Timer(const Duration(milliseconds: 1450), _advanceAfterShot);
    });
  }

  void _advanceAfterShot() {
    if (!mounted) return;
    final goldenFinished = _mode == GameMode.golden && (_score >= 3 || _saves >= 3);
    final trainingFinished = _mode == GameMode.training && _attempts >= 10;
    if (_finished || goldenFinished || trainingFinished) {
      _matchesPlayed++;
      _recordLeaderboard();
      _saveStats();
      setState(() {
        _isResolving = false;
        _screen = Screen.result;
      });
      return;
    }
    setState(() {
      _round++;
      _shotTaken = false;
      _isResolving = false;
      _goal = false;
      _saved = false;
      _wide = false;
      _aim = const Offset(0, -.68);
      _power = .72;
      _commentary = 'PICK YOUR CORNER';
    });
    _shotAnimation.reset();
  }

  void _recordLeaderboard() {
    if (_mode == GameMode.training || _mode == GameMode.golden) return;
    final entry = '$_score|$_attempts|${_mode == GameMode.tournament ? 'KING’S CUP R$_tournamentRound' : 'QUICK SHOOTOUT'}';
    _leaderboard.add(entry);
    _leaderboard.sort((a, b) {
      final aScore = int.tryParse(a.split('|').first) ?? 0;
      final bScore = int.tryParse(b.split('|').first) ?? 0;
      return bScore.compareTo(aScore);
    });
    if (_leaderboard.length > 5) _leaderboard.removeRange(5, _leaderboard.length);
  }

  void _startNextTournamentRound() {
    if (_tournamentRound >= 3 || _score <= _opponentScore) return;
    setState(() {
      _tournamentRound++;
      _opponentName = _selectedOpponent.name;
      _opponentScore = _random.nextInt(6);
      _score = 0;
      _attempts = 0;
      _saves = 0;
      _streak = 0;
      _matchBestStreak = 0;
      _shotHistory.clear();
      _shotTaken = false;
      _goal = false;
      _saved = false;
      _wide = false;
      _isResolving = false;
      _aim = const Offset(0, -.68);
      _power = .72;
      _commentary = 'CUP SEMI-FINAL • PICK YOUR CORNER';
      _screen = Screen.match;
    });
    _shotAnimation.reset();
  }

  void _cycleKeeperKit() {
    setState(() => _keeperKitIndex = (_keeperKitIndex + 1) % keeperKits.length);
    _saveStats();
  }

  void _returnHome() {
    _nextShotTimer?.cancel();
    setState(() => _screen = Screen.home);
  }

  void _toggleSound(bool value) {
    setState(() => _sound = value);
    _saveStats();
  }

  void _toggleVibration(bool value) {
    setState(() => _vibration = value);
    _saveStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0C1A26), ink, Color(0xFF050B11)],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: switch (_screen) {
              Screen.home => _homeScreen(),
              Screen.match => _matchScreen(),
              Screen.result => _resultScreen(),
              Screen.settings => _settingsScreen(),
              Screen.career => _careerScreen(),
            },
          ),
        ),
      ),
    );
  }

  Widget _homeScreen() {
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        key: const ValueKey('home'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _brandMark(),
                  const SizedBox(width: 11),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENALTY KINGS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      Text('THE SPOTLIGHT IS YOURS', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 2)),
                    ],
                  )),
                  IconButton(
                    onPressed: () => setState(() => _screen = Screen.settings),
                    icon: const Icon(Icons.settings_rounded, color: muted),
                    tooltip: 'Settings',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _heroBanner(),
              const SizedBox(height: 13),
              _matchupCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Text('CHOOSE YOUR CHALLENGE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12))),
                  Text('SEASON 01', style: TextStyle(color: lime.withOpacity(.8), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 12),
              _modeCard(
                icon: Icons.bolt_rounded,
                title: 'QUICK SHOOTOUT',
                subtitle: '5 penalties • Beat your best score',
                tag: 'CLASSIC',
                onTap: () => _chooseTeamsAndStart(GameMode.quick),
                accent: lime,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.workspace_premium_rounded,
                title: 'GOLDEN GOAL',
                subtitle: 'First to 3 goals wins the shootout',
                tag: 'SUDDEN DEATH',
                onTap: () => _chooseTeamsAndStart(GameMode.golden),
                accent: gold,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.emoji_events_rounded,
                title: 'KING’S CUP',
                subtitle: '3-round knockout • Win the trophy',
                tag: 'TOURNAMENT',
                onTap: () => _chooseTeamsAndStart(GameMode.tournament),
                accent: gold,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.sports_soccer_rounded,
                title: 'TRAINING GROUND',
                subtitle: '10 attempts • Sharpen your accuracy',
                tag: 'PRACTICE',
                onTap: () => _chooseTeamsAndStart(GameMode.training),
                accent: const Color(0xFF73C8FF),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _recordCard('PERSONAL BEST', '$_bestScore', Icons.emoji_events_rounded, gold)),
                  const SizedBox(width: 10),
                  Expanded(child: _recordCard('BEST STREAK', '$_bestStreak', Icons.local_fire_department_rounded, red)),
                ],
              ),
              const SizedBox(height: 12),
              _careerShortcut(),
              const SizedBox(height: 18),
              const Center(child: Text('NO SHORTCUTS. JUST NERVES OF STEEL.', style: TextStyle(color: Color(0xFF617789), fontSize: 9, letterSpacing: 1.4, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      );
    });
  }


  Widget _careerShortcut() {
    final accuracy = _careerShots == 0 ? 0 : ((_careerGoals / _careerShots) * 100).round();
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () => setState(() => _screen = Screen.career),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: gold.withOpacity(.13), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.query_stats_rounded, color: gold),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CAREER & ACHIEVEMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8)),
              const SizedBox(height: 3),
              Text('$_matchesPlayed matches  •  $accuracy% conversion', style: const TextStyle(color: muted, fontSize: 9)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: muted, size: 15),
          ]),
        ),
      ),
    );
  }

  Widget _careerScreen() {
    final accuracy = _careerShots == 0 ? 0 : ((_careerGoals / _careerShots) * 100).round();
    final milestones = <(String, String, bool, IconData)>[
      ('First Steps', 'Play your first match', _matchesPlayed >= 1, Icons.flag_rounded),
      ('Clinical Finisher', 'Score 10 career goals', _careerGoals >= 10, Icons.gps_fixed_rounded),
      ('Top Corner', 'Score 25 career goals', _careerGoals >= 25, Icons.stars_rounded),
      ('Wall Breaker', 'Beat the keeper 50 times', _careerGoals >= 50, Icons.shield_rounded),
      ('Veteran', 'Play 20 matches', _matchesPlayed >= 20, Icons.military_tech_rounded),
      ('Unshakeable', 'Reach a 5-shot best streak', _bestStreak >= 5, Icons.local_fire_department_rounded),
    ];
    final unlocked = milestones.where((m) => m.$3).length;
    return SingleChildScrollView(
      key: const ValueKey('career'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _screen = Screen.home), icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 6),
          const Text('YOUR CAREER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF284E3D), Color(0xFF142A2B), Color(0xFF142033)]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('THE RECORD BOOK', style: TextStyle(color: lime, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
            const SizedBox(height: 8),
            Text('$unlocked / ${milestones.length}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const Text('ACHIEVEMENTS UNLOCKED', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.4)),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: unlocked / milestones.length, minHeight: 7, backgroundColor: Colors.white12, color: lime),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('CAREER STATISTICS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.75,
          children: [
            _careerStat('MATCHES PLAYED', '$_matchesPlayed', Icons.sports_soccer_rounded, lime),
            _careerStat('TOTAL GOALS', '$_careerGoals', Icons.sports_score_rounded, gold),
            _careerStat('SHOTS TAKEN', '$_careerShots', Icons.track_changes_rounded, const Color(0xFF73C8FF)),
            _careerStat('KEEPER SAVES', '$_careerSaves', Icons.pan_tool_alt_rounded, red),
            _careerStat('CONVERSION', '$accuracy%', Icons.gps_fixed_rounded, lime),
            _careerStat('BEST STREAK', '$_bestStreak', Icons.local_fire_department_rounded, red),
          ],
        ),
        const SizedBox(height: 20),
        const Text('LOCAL LEADERBOARD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.05))),
          child: _leaderboard.isEmpty
              ? const Text('Your best five shootouts will appear here.', style: TextStyle(color: muted, fontSize: 10))
              : Column(children: _leaderboard.asMap().entries.map((entry) {
                  final parts = entry.value.split('|');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Text('#${entry.key + 1}', style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 11)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(parts.length > 2 ? parts[2] : 'SHOOTOUT', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),
                      Text(parts.first, style: const TextStyle(color: lime, fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(width: 5),
                      const Text('GOALS', style: TextStyle(color: muted, fontSize: 8)),
                    ]),
                  );
                }).toList()),
        ),
        const SizedBox(height: 20),
        const Text('ACHIEVEMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        const SizedBox(height: 10),
        ...milestones.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: m.$3 ? lime.withOpacity(.35) : Colors.white.withOpacity(.05)),
          ),
          child: Row(children: [
            Container(
              width: 39, height: 39,
              decoration: BoxDecoration(color: (m.$3 ? lime : muted).withOpacity(.13), borderRadius: BorderRadius.circular(12)),
              child: Icon(m.$4, color: m.$3 ? lime : muted),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(m.$2, style: const TextStyle(color: muted, fontSize: 9)),
            ])),
            Icon(m.$3 ? Icons.check_circle_rounded : Icons.lock_rounded, color: m.$3 ? lime : muted, size: 18),
          ]),
        )),
      ]),
    );
  }

  Widget _careerStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.05))),
      child: Row(children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 9),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .5)),
        ])),
      ]),
    );
  }

  Widget _brandMark() => Container(
    width: 43, height: 43,
    decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: lime.withOpacity(.18), blurRadius: 18)]),
    child: const Icon(Icons.sports_soccer_rounded, color: ink, size: 27),
  );

  Widget _heroBanner() {
    return Container(
      height: 190,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(.09)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF244B3C), Color(0xFF132D2C), Color(0xFF102033)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: StadiumBackdropPainter())),
          Positioned(right: -8, bottom: -22, child: Transform.rotate(angle: -.23, child: Icon(Icons.sports_soccer_rounded, size: 170, color: Colors.white.withOpacity(.10)))),
          Positioned(left: 19, top: 19, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(30)),
            child: const Text('NEW SEASON', style: TextStyle(color: ink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          )),
          const Positioned(left: 20, bottom: 20, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OWN THE', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, height: 1)),
              Text('MOMENT.', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: lime, height: 1.05)),
              SizedBox(height: 7),
              Text('One ball. One keeper. Your legacy.', style: TextStyle(color: Color(0xFFD2E0DB), fontSize: 11)),
            ],
          )),
          Positioned(right: 16, top: 17, child: Icon(Icons.stadium_rounded, size: 22, color: Colors.white.withOpacity(.7))),
        ],
      ),
    );
  }

  Widget _modeCard({required IconData icon, required String title, required String subtitle, required String tag, required VoidCallback onTap, required Color accent}) {
    return Material(
      color: panel,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.055))),
          child: Row(
            children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: accent.withOpacity(.13), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 25)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: .8)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: muted, fontSize: 10)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(tag, style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 7),
                Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(.7), size: 18),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white.withOpacity(.05))),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .8)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _matchScreen() {
    return Column(
      key: const ValueKey('match'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 8),
          child: Row(children: [
            IconButton(
              onPressed: () => _confirmExit(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(backgroundColor: panel),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_modeTitle, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.1)),
              Text(_mode == GameMode.tournament
              ? 'KING’S CUP • ROUND $_tournamentRound / 3'
              : '$_difficulty • MATCH ${_mode == GameMode.golden ? 'SUDDEN DEATH' : '$_round'}', style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                const Icon(Icons.sports_soccer, color: lime, size: 15),
                const SizedBox(width: 6),
                Text('$_score', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: _mode == GameMode.tournament
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_selectedTeam.shortName+'  '+_score.toString(), style: const TextStyle(color: lime, fontSize: 10, fontWeight: FontWeight.w900)),
                  Text('VS  '+_opponentName, style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900)),
                  Text(_opponentScore.toString()+'  '+_selectedOpponent.shortName, style: const TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w900)),
                ])
              : Row(children: [
                  Expanded(child: Text(_selectedTeam.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: lime, fontSize: 9, fontWeight: FontWeight.w900))),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900))),
                  Expanded(child: Text(_selectedOpponent.name, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: gold, fontSize: 9, fontWeight: FontWeight.w900))),
                ]),
        ),
        _matchProgress(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
            child: _pitchView(),
          ),
        ),
        _matchControls(),
      ],
    );
  }

  Widget _matchProgress() {
    if (_mode == GameMode.golden) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('GOALS $_score / 3', style: const TextStyle(color: lime, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(width: 18),
          Text('SAVES $_saves / 3', style: const TextStyle(color: red, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      );
    }
    final total = (_mode == GameMode.quick || _mode == GameMode.tournament) ? 5 : 10;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: List.generate(total, (i) {
        final done = i < _shotHistory.length;
        final active = i == _attempts;
        final color = done
            ? (_shotHistory[i] == 1 ? lime : _shotHistory[i] == 2 ? red : gold.withOpacity(.75))
            : active ? gold : Colors.white.withOpacity(.09);
        return Expanded(child: Container(
          height: 5,
          margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
        ));
      })),
    );
  }

  Widget _pitchView() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _setAim(d.localPosition, size),
        onPanUpdate: (d) => _setAim(d.localPosition, size),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedBuilder(
              animation: Listenable.merge([_shotAnimation, _pulseAnimation]),
              builder: (context, _) => CustomPaint(
                painter: ProPitchPainter(
                  aim: _aim,
                  keeperKitColor: _keeperKitColor,
                  keeperLane: _keeperLane,
                  keeperVertical: _keeperVertical,
                  targetLane: _targetLane,
                  shotTaken: _shotTaken,
                  goal: _goal,
                  saved: _saved,
                  wide: _wide,
                  progress: _shotAnimation.value,
                  pulse: _pulseAnimation.value,
                ),
              ),
            ),
            Positioned(top: 13, left: 0, right: 0, child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xCC071019), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(.08))),
                child: Text(_commentary, style: TextStyle(color: _shotTaken ? (_goal ? lime : red) : Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            )),
            if (!_shotTaken)
              Positioned(left: 13, right: 13, bottom: 15, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _pitchHint(Icons.swipe_rounded, 'DRAG TO AIM'),
                _pitchHint(Icons.adjust_rounded, 'FIND THE CORNER'),
              ])),
            if (_shotTaken)
              Positioned(bottom: 20, left: 0, right: 0, child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                  decoration: BoxDecoration(color: ink.withOpacity(.86), borderRadius: BorderRadius.circular(30), border: Border.all(color: (_goal ? lime : red).withOpacity(.35))),
                  child: Text(_commentary, style: TextStyle(color: _goal ? lime : red, fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 12)),
                ),
              )),
          ]),
        ),
      );
    });
  }

  Widget _pitchHint(IconData icon, String label) => Row(children: [
    Icon(icon, color: Colors.white.withOpacity(.65), size: 14),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
  ]);

  Widget _virtualAimPad() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onPanDown: (d) => _moveAimJoystick(d.localPosition, const Size(88, 88)),
        onPanUpdate: (d) => _moveAimJoystick(d.localPosition, const Size(88, 88)),
        onPanEnd: (_) => _releaseAimJoystick(),
        onPanCancel: _releaseAimJoystick,
        child: SizedBox(
          width: 88,
          height: 88,
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF172838).withOpacity(.96),
                border: Border.all(color: Colors.white.withOpacity(.18), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.10))),
            ),
            Transform.translate(
              offset: _joystick * 25,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE7F6B7), lime, Color(0xFF83A83D)]),
                  border: Border.all(color: Colors.white.withOpacity(.55), width: 1.5),
                  boxShadow: [BoxShadow(color: lime.withOpacity(.22), blurRadius: 9)],
                ),
                child: const Icon(Icons.circle, color: Color(0xFF47621E), size: 9),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 3),
      const Text('MOVE TO AIM', style: TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
    ]);
  }

  Widget _matchControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1722),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('SHOT POWER', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const Spacer(),
          Text('${(_power * 100).round()}%', style: const TextStyle(color: lime, fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: lime,
            inactiveTrackColor: panel2,
            thumbColor: Colors.white,
            overlayColor: lime.withOpacity(.12),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: _power,
            min: .1,
            max: 1,
            onChanged: _shotTaken ? null : (v) => setState(() => _power = v),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _virtualAimPad(),
            const Spacer(),
            Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 78,
                height: 78,
                child: FilledButton(
                  onPressed: _shotTaken ? null : _shoot,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                    backgroundColor: lime,
                    disabledBackgroundColor: panel2,
                    foregroundColor: ink,
                    elevation: 5,
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.sports_soccer_rounded, size: 27),
                    SizedBox(height: 2),
                    Text('SHOOT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ]),
                ),
              ),
              const SizedBox(height: 3),
              Text(_shotTaken ? 'IN PLAY' : 'ACTION', style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .8)),
            ]),
          ],
        ),
        const SizedBox(height: 7),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.shield_outlined, color: muted, size: 12),
          const SizedBox(width: 5),
          Text('$_difficulty GOALKEEPER', style: const TextStyle(color: muted, fontSize: 8, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
          const SizedBox(width: 13),
          const Icon(Icons.flag_rounded, color: muted, size: 12),
          const SizedBox(width: 5),
          Text(_mode == GameMode.quick ? 'KICK ${_attempts + (_shotTaken ? 0 : 1)} OF 5' : 'ATTEMPT ${_attempts + 1}', style: const TextStyle(color: muted, fontSize: 8, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _resultScreen() {
    final tournamentWon = _mode == GameMode.tournament && _score > _opponentScore;
    final tournamentChampion = tournamentWon && _tournamentRound == 3;
    final title = _mode == GameMode.tournament
        ? (tournamentChampion ? 'KING’S CUP CHAMPION!' : tournamentWon ? 'ROUND WON!' : 'TOURNAMENT OVER')
        : _mode == GameMode.quick
            ? (_score >= 5 ? 'PERFECT FIVE!' : _score >= 4 ? 'ELITE FINISHER!' : _score >= 3 ? 'SOLID PERFORMANCE' : 'KEEP PRACTISING')
            : _mode == GameMode.golden
                ? (_score >= 3 ? 'GOLDEN GOAL!' : 'THE KEEPER WINS')
                : 'TRAINING COMPLETE';
    return Center(
      key: const ValueKey('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(color: gold.withOpacity(.13), shape: BoxShape.circle, border: Border.all(color: gold.withOpacity(.35))),
            child: const Icon(Icons.emoji_events_rounded, color: gold, size: 53),
          ),
          const SizedBox(height: 22),
          const Text('FULL TIME', style: TextStyle(color: muted, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11)),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 9),
          Text(_modeTitle, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.6)),
          if (_mode != GameMode.tournament) ...[
            const SizedBox(height: 13),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _teamBadge(_selectedTeam, size: 34),
              const SizedBox(width: 9),
              Flexible(child: Text(_selectedTeam.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: gold, fontSize: 9, fontWeight: FontWeight.w900))),
              Flexible(child: Text(_selectedOpponent.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
              const SizedBox(width: 9),
              _teamBadge(_selectedOpponent, size: 34),
            ]),
          ],
          if (_mode == GameMode.tournament) ...[
            const SizedBox(height: 12),
            Text('$_score  —  $_opponentScore', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: gold)),
            Text(_selectedTeam.name+'  vs  '+_opponentName, style: const TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2)),
          ],
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(23), border: Border.all(color: Colors.white.withOpacity(.06))),
            child: Column(children: [
              Text('$_score', style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: lime, height: 1)),
              const Text('GOALS SCORED', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.7)),
              const SizedBox(height: 22),
              Row(children: [
                _resultStat('ATTEMPTS', '$_attempts'),
                _resultStat('CONVERSION', '${_attempts == 0 ? 0 : (_score / _attempts * 100).round()}%'),
                _resultStat('SAVES', '$_saves'),
                _resultStat('BEST STREAK', '$_matchBestStreak'),
              ]),
            ]),
          ),
          const SizedBox(height: 15),
          if (_newRecord)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(color: lime.withOpacity(.12), borderRadius: BorderRadius.circular(30)),
              child: const Text('★  PERSONAL BEST UPDATED', style: TextStyle(color: lime, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          const SizedBox(height: 25),
          if (_mode == GameMode.tournament && tournamentWon && !tournamentChampion) ...[
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
              onPressed: _startNextTournamentRound,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('NEXT ROUND', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            )),
            const SizedBox(height: 10),
          ],
          SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
            onPressed: () => _start(_mode),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('PLAY AGAIN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 52, child: OutlinedButton.icon(
            onPressed: _returnHome,
            icon: const Icon(Icons.home_rounded),
            label: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withOpacity(.13)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          )),
        ]),
      ),
    );
  }

  Widget _resultStat(String label, String value) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .6)),
  ]));

  Widget _settingsScreen() {
    return Padding(
      key: const ValueKey('settings'),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => _screen = Screen.home), icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(width: 7),
          const Text('SETTINGS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        ]),
        const SizedBox(height: 20),
        _settingsGroup('GAMEPLAY', [
          _settingTile(Icons.speed_rounded, 'Goalkeeper difficulty', _difficulty, onTap: _cycleDifficulty),
          _settingTile(Icons.palette_rounded, 'Goalkeeper kit', keeperKitNames[_keeperKitIndex], onTap: _cycleKeeperKit),
          _settingTile(Icons.school_rounded, 'How to play', 'View tutorial', onTap: _showTutorial),
        ]),
        const SizedBox(height: 15),
        _settingsGroup('EXPERIENCE', [
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 13),
            secondary: const Icon(Icons.volume_up_rounded, color: lime),
            title: const Text('Sound effects', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            subtitle: const Text('Game audio preferences', style: TextStyle(color: muted, fontSize: 10)),
            value: _sound,
            activeColor: lime,
            onChanged: _toggleSound,
          ),
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 13),
            secondary: const Icon(Icons.vibration_rounded, color: lime),
            title: const Text('Haptic feedback', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            subtitle: const Text('Vibrate on shot outcomes', style: TextStyle(color: muted, fontSize: 10)),
            value: _vibration,
            activeColor: lime,
            onChanged: _toggleVibration,
          ),
        ]),
        const Spacer(),
        const Center(child: Text('PENALTY KINGS  •  VERSION 3.3.0', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2))),
      ]),
    );
  }

  Widget _settingsGroup(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title, style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
      Container(decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.05))), child: Column(children: children)),
    ],
  );

  Widget _settingTile(IconData icon, String title, String value, {required VoidCallback onTap}) => ListTile(
    leading: Icon(icon, color: lime),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    subtitle: Text(value, style: const TextStyle(color: muted, fontSize: 10)),
    trailing: const Icon(Icons.chevron_right_rounded, color: muted),
    onTap: onTap,
  );

  void _cycleDifficulty() {
    setState(() => _difficulty = switch (_difficulty) {
      'AMATEUR' => 'PRO',
      'PRO' => 'WORLD CLASS',
      _ => 'AMATEUR',
    });
    _saveStats();
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        title: const Text('Leave shootout?'),
        content: const Text('Your current match progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP PLAYING')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink), child: const Text('LEAVE')),
        ],
      ),
    );
    if (exit == true) _returnHome();
  }
}

class _TutorialLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TutorialLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: lime, size: 19),
    const SizedBox(width: 11),
    Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFD6E0E8), fontSize: 12, height: 1.4))),
  ]);
}

class StadiumBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..shader = RadialGradient(colors: [lime.withOpacity(.12), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(size.width * .72, size.height * .42), radius: size.width * .62));
    canvas.drawRect(Offset.zero & size, glow);
    final crowd = Paint()..color = Colors.white.withOpacity(.09);
    for (int row = 0; row < 3; row++) {
      for (int i = 0; i < 28; i++) {
        final x = size.width * i / 27;
        final y = size.height * (.18 + row * .055);
        canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * .35, crowd);
      }
    }
    final rays = Paint()..color = Colors.white.withOpacity(.12)..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      final x = size.width * (.08 + i * .2);
      canvas.drawLine(Offset(x, 0), Offset(x + 25, size.height * .45), rays);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProPitchPainter extends CustomPainter {
  final Offset aim;
  final Color keeperKitColor;
  final int keeperLane;
  final int keeperVertical;
  final int targetLane;
  final bool shotTaken;
  final bool goal;
  final bool saved;
  final bool wide;
  final double progress;
  final double pulse;

  ProPitchPainter({
    required this.aim,
    required this.keeperKitColor,
    required this.keeperLane,
    required this.keeperVertical,
    required this.targetLane,
    required this.shotTaken,
    required this.goal,
    required this.saved,
    required this.wide,
    required this.progress,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF142C39), Color(0xFF173E36), Color(0xFF0B2925), Color(0xFF0D241F)],
      stops: [0, .28, .62, 1],
    ).createShader(bounds));

    _drawStadium(canvas, size);
    _drawPitch(canvas, size);
    final goalRect = Rect.fromLTWH(size.width * .105, size.height * .155, size.width * .79, size.height * .31);
    _drawGoal(canvas, goalRect);
    _drawKeeper(canvas, size, goalRect);
    _drawAimAndBall(canvas, size);
  }

  void _drawStadium(Canvas canvas, Size size) {
    final light = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)..color = Colors.white.withOpacity(.25);
    for (int i = 0; i < 4; i++) {
      final x = size.width * (i.isEven ? .08 : .92);
      final y = size.height * (.07 + (i ~/ 2) * .025);
      canvas.drawCircle(Offset(x, y), 8, light);
      final dots = Paint()..color = Colors.white.withOpacity(.65);
      for (int j = 0; j < 5; j++) {
        canvas.drawCircle(Offset(x - 12 + j * 6, y), 1.4, dots);
      }
    }
    final crowd = Paint()..color = const Color(0xFF9FB9B2).withOpacity(.12);
    for (int row = 0; row < 4; row++) {
      for (int i = 0; i < 42; i++) {
        canvas.drawCircle(Offset(size.width * i / 41, size.height * (.08 + row * .018)), 1.2, crowd);
      }
    }
    final dark = Paint()..color = Colors.black.withOpacity(.22);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .39, size.width, size.height * .12), dark);
  }

  void _drawPitch(Canvas canvas, Size size) {
    final field = Rect.fromLTWH(size.width * .035, size.height * .39, size.width * .93, size.height * .61);
    final grass = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B5A42), Color(0xFF0C392C)]).createShader(field);
    canvas.drawRect(field, grass);
    for (int i = 0; i < 7; i++) {
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(field.left, field.top + field.height * i / 7, field.width, field.height / 7), Paint()..color = Colors.white.withOpacity(.025));
      }
    }
    final line = Paint()..color = Colors.white.withOpacity(.24)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(size.width * .07, size.height * .41, size.width * .86, size.height * .57), line);
    canvas.drawCircle(Offset(size.width * .5, size.height * .74), size.width * .18, line);
    canvas.drawCircle(Offset(size.width * .5, size.height * .74), 2.5, Paint()..color = Colors.white.withOpacity(.55));
    canvas.drawRect(Rect.fromLTWH(size.width * .18, size.height * .41, size.width * .64, size.height * .27), line);
    canvas.drawRect(Rect.fromLTWH(size.width * .33, size.height * .41, size.width * .34, size.height * .12), line);
  }

  void _drawGoal(Canvas canvas, Rect goal) {
    final shadow = Paint()..color = Colors.black.withOpacity(.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawRect(goal.shift(const Offset(0, 6)), shadow);
    final net = Paint()..color = const Color(0xFFDCE8E7).withOpacity(.32)..strokeWidth = 1;
    for (int i = 0; i <= 12; i++) {
      final x = goal.left + goal.width * i / 12;
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (int i = 0; i <= 7; i++) {
      final y = goal.top + goal.height * i / 7;
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
    final frame = Paint()..color = const Color(0xFFF3F7F5)..style = PaintingStyle.stroke..strokeWidth = 7..strokeJoin = StrokeJoin.round;
    canvas.drawRect(goal, frame);
    final inner = Paint()..color = Colors.white.withOpacity(.35)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawRect(goal.deflate(5), inner);
  }

  void _drawKeeper(Canvas canvas, Size size, Rect goalRect) {
    final lane = shotTaken ? keeperLane : 1;
    final centerX = goalRect.left + goalRect.width * (lane + .5) / 3;
    final keeperHeight = keeperVertical == 0 ? .32 : keeperVertical == 1 ? .64 : .84;
    final heightProgress = shotTaken ? Curves.easeOut.transform(progress) : 0.0;
    final baseY = goalRect.top + goalRect.height * (.77 + (keeperHeight - .77) * heightProgress);
    final dive = shotTaken ? (targetLane - keeperLane).toDouble() * progress * 36 : 0.0;
    final x = centerX + dive;
    final y = baseY - (shotTaken && keeperLane == targetLane ? math.sin(progress * math.pi) * 12 : 0);
    final bodyColor = keeperKitColor;
    final body = Paint()..color = bodyColor;
    final outline = Paint()..color = const Color(0xFF1B2931)..strokeWidth = 7..strokeCap = StrokeCap.round;
    final skin = Paint()..color = const Color(0xFFC98C68);
    canvas.drawCircle(Offset(x, y - 25), 10, skin);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 3), width: 25, height: 39), const Radius.circular(8)), body);
    canvas.drawLine(Offset(x - 8, y - 4), Offset(x - 25 - dive.sign * 8, y + 4), body..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(x + 8, y - 4), Offset(x + 25 + dive.sign * 8, y + 4), body..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(x - 28 - (dive < 0 ? -1.0 : dive > 0 ? 1.0 : 0.0) * 8, y + 4), 6, Paint()..color = const Color(0xFFF2F5F4));
    canvas.drawCircle(Offset(x + 28 + (dive < 0 ? -1.0 : dive > 0 ? 1.0 : 0.0) * 8, y + 4), 6, Paint()..color = const Color(0xFFF2F5F4));
    canvas.drawLine(Offset(x - 7, y + 19), Offset(x - 12, y + 39), outline);
    canvas.drawLine(Offset(x + 7, y + 19), Offset(x + 12, y + 39), outline);
  }

  void _drawAimAndBall(Canvas canvas, Size size) {
    final start = Offset(size.width * .5, size.height * .84);
    final target = Offset(size.width * (.5 + aim.dx * .34), size.height * (.29 + aim.dy * .13));
    if (!shotTaken) {
      final line = Paint()..color = lime.withOpacity(.75)..strokeWidth = 2..style = PaintingStyle.stroke;
      final path = Path()..moveTo(start.dx, start.dy)..quadraticBezierTo(size.width * .5, size.height * .55, target.dx, target.dy);
      canvas.drawPath(path, line);
      final ring = Paint()..color = lime.withOpacity(.18 + pulse * .15)..style = PaintingStyle.fill;
      canvas.drawCircle(target, 17 + pulse * 3, ring);
      canvas.drawCircle(target, 10, Paint()..color = lime..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(target, 3, Paint()..color = lime);
    }
    final end = shotTaken
        ? Offset(
            start.dx + (target.dx - start.dx) * Curves.easeOutCubic.transform(progress),
            start.dy + (target.dy - start.dy) * Curves.easeOutCubic.transform(progress),
          )
        : start;
    final radius = shotTaken ? 13.0 - progress * 5.0 : 13.0;
    canvas.drawCircle(end + const Offset(2, 4), radius + 2, Paint()..color = Colors.black.withOpacity(.3));
    canvas.drawCircle(end, radius, Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0xFFBBC8CE), Color(0xFF657780)]).createShader(Rect.fromCircle(center: end, radius: radius)));
    final seams = Paint()..color = const Color(0xFF1D2A31)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawCircle(end, radius * .42, seams);
    canvas.drawLine(end + Offset(-radius * .7, 0), end + Offset(radius * .7, 0), seams);
    canvas.drawLine(end + Offset(0, -radius * .7), end + Offset(0, radius * .7), seams);
  }

  @override
  bool shouldRepaint(covariant ProPitchPainter old) =>
      old.aim != aim ||
      old.keeperKitColor != keeperKitColor ||
      old.keeperLane != keeperLane ||
      old.keeperVertical != keeperVertical ||
      old.targetLane != targetLane ||
      old.shotTaken != shotTaken ||
      old.goal != goal ||
      old.saved != saved ||
      old.wide != wide ||
      old.progress != progress ||
      old.pulse != pulse;
}
