import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/shootout_game.dart';

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

class _KingsShellState extends State<KingsShell> {
  final math.Random _random = math.Random();
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
  List<TeamOption> _cupOpponents = <TeamOption>[];
  int _bestScore = 0;
  int _bestStreak = 0;
  int _careerShots = 0;
  int _careerGoals = 0;
  int _careerSaves = 0;
  int _careerWins = 0;
  int _cupsWon = 0;
  int _matchesPlayed = 0;
  int _matchSeed = 0;
  bool _newRecord = false;
  MatchResult _lastResult = const MatchResult(
    goals: 0, oppGoals: 0, attempts: 0, oppAttempts: 0, saves: 0, bestStreak: 0, won: false,
  );

  static const List<String> _cupRoundNames = <String>['QUARTER-FINAL', 'SEMI-FINAL', 'FINAL'];

  Color get _keeperKitColor => keeperKits[_keeperKitIndex.clamp(0, keeperKits.length - 1).toInt()];
  String get _modeTitle => switch (_mode) {
        GameMode.quick => 'QUICK SHOOTOUT',
        GameMode.golden => 'SUDDEN DEATH',
        GameMode.training => 'TRAINING GROUND',
        GameMode.tournament => 'KING’S CUP TOURNAMENT',
      };

  TeamOption get _currentOpponent =>
      _mode == GameMode.tournament && _cupOpponents.length >= _tournamentRound
          ? _cupOpponents[_tournamentRound - 1]
          : _selectedOpponent;

  // King's Cup gets harder every round.
  String get _matchDifficulty {
    if (_mode != GameMode.tournament) return _difficulty;
    const levels = <String>['AMATEUR', 'PRO', 'WORLD CLASS'];
    final base = levels.indexOf(_difficulty);
    final idx = math.min(2, (base < 0 ? 1 : base) + (_tournamentRound - 1));
    return levels[idx];
  }

  @override
  void initState() {
    super.initState();
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
      _careerWins = prefs.getInt('career_wins') ?? 0;
      _cupsWon = prefs.getInt('cups_won') ?? 0;
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
    await prefs.setInt('career_wins', _careerWins);
    await prefs.setInt('cups_won', _cupsWon);
    await prefs.setBool('sound', _sound);
    await prefs.setBool('vibration', _vibration);
    await prefs.setBool('tutorial_seen', _tutorialSeen);
    await prefs.setInt('keeper_kit', _keeperKitIndex);
    await prefs.setString('selected_team', _selectedTeam.id);
    await prefs.setString('selected_opponent', _selectedOpponent.id);
    await prefs.setStringList('local_leaderboard', _leaderboard);
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

  List<TeamOption> _buildCupOpponents() {
    final pool = nationalTeams.any((t) => t.id == _selectedTeam.id) ? nationalTeams : clubTeams;
    final others = pool.where((t) => t.id != _selectedTeam.id && t.id != _selectedOpponent.id).toList()
      ..shuffle(_random);
    return <TeamOption>[_selectedOpponent, others[0], others[1]];
  }

  void _start(GameMode mode) {
    setState(() {
      _mode = mode;
      _tournamentRound = 1;
      if (mode == GameMode.tournament) _cupOpponents = _buildCupOpponents();
      _matchSeed++;
      _newRecord = false;
      _screen = Screen.match;
    });
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
        title: const Text('HOW TO WIN A SHOOTOUT',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TutorialLine(icon: Icons.swipe_up_rounded, text: 'Swipe up from the ball to shoot. Swipe sideways to pick a corner, and swipe further for a higher shot.'),
              SizedBox(height: 12),
              _TutorialLine(icon: Icons.bolt_rounded, text: 'Flick quickly for power. Slow swipes are weaker; over-hit it and it can sail over the bar.'),
              SizedBox(height: 12),
              _TutorialLine(icon: Icons.gesture_rounded, text: 'Curve your swipe to bend the ball and make the keeper’s read harder.'),
              SizedBox(height: 12),
              _TutorialLine(icon: Icons.pan_tool_alt_rounded, text: 'When they shoot, you are the keeper: swipe or tap a goal zone to dive. Early is better than late.'),
              SizedBox(height: 12),
              _TutorialLine(icon: Icons.emoji_events_rounded, text: 'Five kicks each, then sudden death. Out-score the CPU to win.'),
            ],
          ),
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

  void _onMatchFinished(MatchResult r) {
    if (!mounted) return;
    setState(() {
      _lastResult = r;
      _matchesPlayed++;
      _careerShots += r.attempts;
      _careerGoals += r.goals;
      _careerSaves += r.saves;
      _newRecord = r.goals > _bestScore;
      if (_newRecord) _bestScore = r.goals;
      if (r.bestStreak > _bestStreak) _bestStreak = r.bestStreak;
      if (_mode != GameMode.training && r.won) _careerWins++;
      if (_mode == GameMode.tournament && r.won && _tournamentRound == 3) _cupsWon++;
      _recordLeaderboard(r);
      _screen = Screen.result;
    });
    _saveStats();
  }

  void _recordLeaderboard(MatchResult r) {
    if (_mode == GameMode.training || _mode == GameMode.golden) return;
    final label = (_mode == GameMode.tournament ? 'KING’S CUP R$_tournamentRound' : 'QUICK SHOOTOUT') +
        (r.won ? ' • WIN' : ' • LOSS');
    _leaderboard.add('${r.goals}|${r.attempts}|$label');
    _leaderboard.sort((a, b) {
      final aScore = int.tryParse(a.split('|').first) ?? 0;
      final bScore = int.tryParse(b.split('|').first) ?? 0;
      return bScore.compareTo(aScore);
    });
    if (_leaderboard.length > 5) _leaderboard.removeRange(5, _leaderboard.length);
  }

  void _startNextTournamentRound() {
    if (_tournamentRound >= 3 || !_lastResult.won) return;
    setState(() {
      _tournamentRound++;
      _matchSeed++;
      _newRecord = false;
      _screen = Screen.match;
    });
  }

  void _cycleKeeperKit() {
    setState(() => _keeperKitIndex = (_keeperKitIndex + 1) % keeperKits.length);
    _saveStats();
  }

  void _returnHome() {
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
                subtitle: '5 kicks each • Shoot, then save • Win on penalties',
                tag: 'CLASSIC',
                onTap: () => _chooseTeamsAndStart(GameMode.quick),
                accent: lime,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.workspace_premium_rounded,
                title: 'SUDDEN DEATH',
                subtitle: 'Sudden death • One miss can end it',
                tag: 'SUDDEN DEATH',
                onTap: () => _chooseTeamsAndStart(GameMode.golden),
                accent: gold,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.emoji_events_rounded,
                title: 'KING’S CUP',
                subtitle: 'Quarter • Semi • Final • Win the trophy',
                tag: 'TOURNAMENT',
                onTap: () => _chooseTeamsAndStart(GameMode.tournament),
                accent: gold,
              ),
              const SizedBox(height: 10),
              _modeCard(
                icon: Icons.sports_soccer_rounded,
                title: 'TRAINING GROUND',
                subtitle: '10 free kicks • Master swipe, power & curve',
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
      ('Safe Hands', 'Make 10 saves as the keeper', _careerSaves >= 10, Icons.pan_tool_alt_rounded),
      ('Penalty King', 'Win 5 shootouts', _careerWins >= 5, Icons.workspace_premium_rounded),
      ('Cup Winner', 'Win the King’s Cup', _cupsWon >= 1, Icons.emoji_events_rounded),
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
            _careerStat('SAVES MADE', '$_careerSaves', Icons.pan_tool_alt_rounded, red),
            _careerStat('CONVERSION', '$accuracy%', Icons.gps_fixed_rounded, lime),
            _careerStat('BEST STREAK', '$_bestStreak', Icons.local_fire_department_rounded, red),
            _careerStat('SHOOTOUT WINS', '$_careerWins', Icons.military_tech_rounded, gold),
            _careerStat('CUPS WON', '$_cupsWon', Icons.emoji_events_rounded, lime),
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
    final opp = _currentOpponent;
    final format = switch (_mode) {
      GameMode.quick || GameMode.tournament => MatchFormat.shootout,
      GameMode.golden => MatchFormat.suddenDeath,
      GameMode.training => MatchFormat.training,
    };
    final isCup = _mode == GameMode.tournament;
    return ShootoutMatch(
      key: ValueKey('match$_matchSeed'),
      setup: MatchSetup(
        format: format,
        title: isCup ? 'KING’S CUP' : _modeTitle,
        subtitle: isCup
            ? '${_cupRoundNames[_tournamentRound - 1]} • ROUND $_tournamentRound / 3 • $_matchDifficulty'
            : '$_matchDifficulty OPPONENT',
        homeName: _selectedTeam.name,
        homeShort: _selectedTeam.shortName,
        awayName: opp.name,
        awayShort: opp.shortName,
        homeColor: _selectedTeam.color,
        awayColor: opp.color,
        keeperColor: _keeperKitColor,
        difficulty: _matchDifficulty,
        vibration: _vibration,
        sound: _sound,
      ),
      onFinished: _onMatchFinished,
      onExit: _returnHome,
    );
  }

  Widget _resultScreen() {
    final r = _lastResult;
    final isCup = _mode == GameMode.tournament;
    final training = _mode == GameMode.training;
    final champion = isCup && r.won && _tournamentRound == 3;
    final title = isCup
        ? (champion ? 'KING’S CUP CHAMPION!' : r.won ? 'ROUND WON!' : 'KNOCKED OUT')
        : training
            ? (r.goals >= 8 ? 'ELITE FINISHING!' : r.goals >= 5 ? 'SOLID SESSION' : 'KEEP PRACTISING')
            : (r.won ? 'VICTORY!' : 'DEFEAT');
    final accent = training || r.won ? gold : red;
    final opp = _currentOpponent;
    return Center(
      key: const ValueKey('result'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 92, height: 92,
            decoration: BoxDecoration(color: accent.withOpacity(.13), shape: BoxShape.circle, border: Border.all(color: accent.withOpacity(.35))),
            child: Icon(r.won || training ? Icons.emoji_events_rounded : Icons.sports_soccer_rounded, color: accent, size: 53),
          ),
          const SizedBox(height: 22),
          const Text('FULL TIME', style: TextStyle(color: muted, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 11)),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: .6)),
          const SizedBox(height: 9),
          Text(isCup ? 'KING’S CUP • ${_cupRoundNames[_tournamentRound - 1]}' : _modeTitle, style: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1.6)),
          if (!training) ...[
            const SizedBox(height: 13),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _teamBadge(_selectedTeam, size: 34),
              const SizedBox(width: 9),
              Flexible(child: Text(_selectedTeam.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('VS', style: TextStyle(color: gold, fontSize: 9, fontWeight: FontWeight.w900))),
              Flexible(child: Text(opp.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
              const SizedBox(width: 9),
              _teamBadge(opp, size: 34),
            ]),
            const SizedBox(height: 12),
            Text('${r.goals}  —  ${r.oppGoals}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: accent)),
            const Text('PENALTY SHOOTOUT', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.4)),
          ],
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(23), border: Border.all(color: Colors.white.withOpacity(.06))),
            child: Column(children: [
              Text('${r.goals}', style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: lime, height: 1)),
              const Text('GOALS SCORED', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.7)),
              const SizedBox(height: 22),
              Row(children: [
                _resultStat('KICKS', '${r.attempts}'),
                _resultStat('CONVERSION', '${r.attempts == 0 ? 0 : (r.goals / r.attempts * 100).round()}%'),
                if (!training) _resultStat('SAVES', '${r.saves}'),
                _resultStat('BEST STREAK', '${r.bestStreak}'),
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
          if (isCup && r.won && !champion) ...[
            SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(
              onPressed: _startNextTournamentRound,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('NEXT: ${_cupRoundNames[_tournamentRound]}', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
          _settingTile(Icons.speed_rounded, 'Opponent difficulty', _difficulty, onTap: _cycleDifficulty),
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
        const Center(child: Text('PENALTY KINGS  •  VERSION 4.0.0', style: TextStyle(color: muted, fontSize: 9, letterSpacing: 1.2))),
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
