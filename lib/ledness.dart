import 'dart:math';

import 'package:flutter/material.dart';





/// Цвета и темы под баннер
class AppColors {
  static const Color bgOuter = Color(0xFF05060B);
  static const Color headerTop = Color(0xFF111219);
  static const Color headerBottom = Color(0xFF181A22);
  static const Color panel = Color(0xFF151720);
  static const Color panelSoft = Color(0xFF1C1F2A);
  static const Color chip = Color(0xFF10131D);
  static const Color borderSoft = Color(0xFF262938);
  static const Color textMain = Color(0xFFF7F8FF);
  static const Color textSoft = Color(0xFFC5C8DE);
  static const Color textMuted = Color(0xFF8F92AA);
  static const Color gold = Color(0xFFE2C27E);
  static const Color goldSoft = Color(0xFFF3D9A1);
  static const Color blue = Color(0xFF6EB5FF);
  static const Color blueSoft = Color(0xFF9BCBFF);
}

class LoungeOfIdlenessApp extends StatelessWidget {
  const LoungeOfIdlenessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lounge of Idleness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgOuter,
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textMain),
        ),
      ),
      home: const LoungeHomePage(),
    );
  }
}

/// Модели данных
class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.minutes,
    required this.mood,
    required this.date,
    this.hasMockPhoto = false,
  });

  final int id;
  String title;
  String description;
  int minutes;
  String mood;
  DateTime date;
  bool hasMockPhoto;
}

class LazyTask {
  LazyTask({
    required this.id,
    required this.title,
    this.description = '',
    this.minutes = 0,
    this.category = 'Screens',
    this.completed = false,
  });

  final int id;
  String title;
  String description;
  int minutes;
  String category;
  bool completed;
}

class ProfileData {
  String name;
  String height;
  String weight;
  String favorite;

  ProfileData({
    this.name = 'Couch Royalty',
    this.height = '175 cm',
    this.weight = '70 kg',
    this.favorite = 'Netflix Binging 📺',
  });
}

class LoungeHomePage extends StatefulWidget {
  const LoungeHomePage({super.key});

  @override
  State<LoungeHomePage> createState() => _LoungeHomePageState();
}

class _LoungeHomePageState extends State<LoungeHomePage> {
  int _tabIndex = 0;

  // Состояние приложения
  final List<DiaryEntry> _diary = [];
  final List<LazyTask> _plan = [];
  ProfileData _profile = ProfileData();

  bool _attachMockPhoto = false;

  // Поля ввода дневника
  final TextEditingController _diaryTitleCtrl = TextEditingController();
  final TextEditingController _diaryDescCtrl = TextEditingController();
  final TextEditingController _diaryMinutesCtrl = TextEditingController();
  String _diaryMood = 'Chill';

  // Поля ввода плана
  final TextEditingController _planTitleCtrl = TextEditingController();
  final TextEditingController _planDescCtrl = TextEditingController();
  final TextEditingController _planMinutesCtrl = TextEditingController();
  String _planCategory = 'Screens';

  // Профиль
  final TextEditingController _profileNameCtrl =
  TextEditingController(text: 'Couch Royalty');
  final TextEditingController _profileHeightCtrl =
  TextEditingController(text: '175 cm');
  final TextEditingController _profileWeightCtrl =
  TextEditingController(text: '70 kg');
  final TextEditingController _profileFavoriteCtrl =
  TextEditingController(text: 'Netflix Binging 📺');

  // Challenge of the day
  String _challengeTitle = 'The Nap Master';
  String _challengeDesc =
      'Take a 30‑minute mid‑day nap. Bonus points for pillow marks.';
  int _challengeMinutes = 30;
  String _challengeCategory = 'Pure nothingness';

  final _random = Random();

  // Идеи и челленджи
  final List<Map<String, dynamic>> _lazyIdeas = [
    {
      'title': 'Stare out of the window',
      'desc': 'Watch the world move while you heroically remain still.',
      'minutes': 20,
      'category': 'Pure nothingness',
    },
    {
      'title': 'Scroll social media for no reason',
      'desc': 'Scroll until you forget why you opened the app.',
      'minutes': 45,
      'category': 'Screens',
    },
    {
      'title': 'Order food instead of cooking',
      'desc': 'Use all your energy to tap “Confirm order”.',
      'minutes': 30,
      'category': 'Food & Drinks',
    },
    {
      'title': 'Rewatch your favourite movie',
      'desc': 'Laugh at the same jokes for the 10th time.',
      'minutes': 120,
      'category': 'Screens',
    },
    {
      'title': 'Lie on the floor and do nothing',
      'desc': 'Bonus points if you forget your to‑do list exists.',
      'minutes': 15,
      'category': 'Pure nothingness',
    },
  ];

  final List<Map<String, dynamic>> _lazyChallenges = [
    {
      'title': 'The Nap Master',
      'desc':
      'Take a 30‑minute mid‑day nap. Bonus points for pillow marks on your face.',
      'minutes': 30,
      'category': 'Pure nothingness',
    },
    {
      'title': 'Infinite Scroll',
      'desc':
      'Scroll through memes for 40 minutes. Stop only if your thumb protests.',
      'minutes': 40,
      'category': 'Screens',
    },
    {
      'title': 'Snack Strategist',
      'desc':
      'Spend at least 25 minutes deciding on the perfect snack combo.',
      'minutes': 25,
      'category': 'Food & Drinks',
    },
    {
      'title': 'Ghost Mode',
      'desc':
      'Read group chats for 20 minutes without replying to a single message.',
      'minutes': 20,
      'category': 'Social',
    },
  ];

  @override
  void dispose() {
    _diaryTitleCtrl.dispose();
    _diaryDescCtrl.dispose();
    _diaryMinutesCtrl.dispose();
    _planTitleCtrl.dispose();
    _planDescCtrl.dispose();
    _planMinutesCtrl.dispose();
    _profileNameCtrl.dispose();
    _profileHeightCtrl.dispose();
    _profileWeightCtrl.dispose();
    _profileFavoriteCtrl.dispose();
    super.dispose();
  }

  // ---------- helpers ----------

  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ---------- actions ----------

  void _saveDiaryEntry() {
    final title = _diaryTitleCtrl.text.trim();
    final desc = _diaryDescCtrl.text.trim();
    final minutes = int.tryParse(_diaryMinutesCtrl.text.trim()) ?? 0;

    if (title.isEmpty || minutes <= 0) {
      _showSnack('Enter at least title and positive minutes');
      return;
    }

    final entry = DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: desc,
      minutes: minutes,
      mood: _diaryMood,
      date: _today(),
      hasMockPhoto: _attachMockPhoto,
    );

    setState(() {
      _diary.insert(0, entry);
      _diaryTitleCtrl.clear();
      _diaryDescCtrl.clear();
      _diaryMinutesCtrl.clear();
      _attachMockPhoto = false;
    });

    _showSnack('Entry saved');
  }

  void _updateDiaryEntry(DiaryEntry entry) async {
    final titleCtrl = TextEditingController(text: entry.title);
    final minutesCtrl =
    TextEditingController(text: entry.minutes.toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: minutesCtrl,
              decoration: const InputDecoration(labelText: 'Minutes'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              final m = int.tryParse(minutesCtrl.text.trim()) ?? entry.minutes;
              if (t.isNotEmpty && m > 0) {
                setState(() {
                  entry.title = t;
                  entry.minutes = m;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteDiaryEntry(DiaryEntry entry) {
    setState(() {
      _diary.removeWhere((e) => e.id == entry.id);
    });
  }

  void _addTaskFromForm() {
    final title = _planTitleCtrl.text.trim();
    final desc = _planDescCtrl.text.trim();
    final minutes = int.tryParse(_planMinutesCtrl.text.trim()) ?? 0;

    if (title.isEmpty) {
      _showSnack('Enter task title');
      return;
    }

    final task = LazyTask(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: desc,
      minutes: max(0, minutes),
      category: _planCategory,
    );

    setState(() {
      _plan.add(task);
      _planTitleCtrl.clear();
      _planDescCtrl.clear();
      _planMinutesCtrl.clear();
    });
  }

  void _toggleTask(LazyTask task) {
    setState(() {
      task.completed = !task.completed;
    });
  }

  void _editTask(LazyTask task) async {
    final tCtrl = TextEditingController(text: task.title);
    final mCtrl = TextEditingController(text: task.minutes.toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: mCtrl,
              decoration: const InputDecoration(labelText: 'Minutes'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final t = tCtrl.text.trim();
              final m = int.tryParse(mCtrl.text.trim()) ?? task.minutes;
              if (t.isNotEmpty && m >= 0) {
                setState(() {
                  task.title = t;
                  task.minutes = m;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _deleteTask(LazyTask task) {
    setState(() {
      _plan.removeWhere((t) => t.id == task.id);
    });
  }

  void _applyRandomIdea() {
    final idea = _lazyIdeas[_random.nextInt(_lazyIdeas.length)];
    setState(() {
      _planTitleCtrl.text = idea['title'] as String;
      _planDescCtrl.text = idea['desc'] as String;
      _planMinutesCtrl.text = (idea['minutes'] as int).toString();
      _planCategory = idea['category'] as String;
    });
  }

  void _newChallenge() {
    final c = _lazyChallenges[_random.nextInt(_lazyChallenges.length)];
    setState(() {
      _challengeTitle = c['title'] as String;
      _challengeDesc = c['desc'] as String;
      _challengeMinutes = c['minutes'] as int;
      _challengeCategory = c['category'] as String;
    });
  }

  void _acceptChallengeAsTask() {
    final task = LazyTask(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _challengeTitle,
      description: _challengeDesc,
      minutes: _challengeMinutes,
      category: _challengeCategory,
    );
    setState(() {
      _plan.add(task);
      _tabIndex = 1;
    });
  }

  void _saveProfile() {
    setState(() {
      _profile = ProfileData(
        name: _profileNameCtrl.text.trim().isEmpty
            ? 'Couch Royalty'
            : _profileNameCtrl.text.trim(),
        height: _profileHeightCtrl.text.trim(),
        weight: _profileWeightCtrl.text.trim(),
        favorite: _profileFavoriteCtrl.text.trim(),
      );
    });
    _showSnack('Profile saved (in memory for this session)');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
      ),
    );
  }

  // ---------- analytics ----------

  int get _totalMinutes =>
      _diary.fold(0, (sum, e) => sum + (e.minutes));

  Map<String, int> _buckets() {
    final Map<String, int> buckets = {
      'Screens': 0,
      'Mobile Gaming': 0,
      'Social': 0,
      'Pure nothingness': 0,
    };
    for (final e in _diary) {
      final text = (e.title + ' ' + e.description).toLowerCase();
      if (text.contains('tiktok') ||
          text.contains('scroll') ||
          text.contains('social') ||
          text.contains('feed') ||
          text.contains('reddit')) {
        buckets['Screens'] = buckets['Screens']! + e.minutes;
      } else if (text.contains('game') || text.contains('gaming')) {
        buckets['Mobile Gaming'] = buckets['Mobile Gaming']! + e.minutes;
      } else if (text.contains('chat') || text.contains('call')) {
        buckets['Social'] = buckets['Social']! + e.minutes;
      } else {
        buckets['Pure nothingness'] =
            buckets['Pure nothingness']! + e.minutes;
      }
    }
    return buckets;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOuter,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderCard(context),

            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildDiaryTab(),
                  _buildPlanTab(),
                  _buildStatsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerTop, AppColors.headerBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          // tiny menu / "logo"

          const SizedBox(height: 10),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: const Color(0xFF04101B),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 14,
                shadowColor: AppColors.blue.withOpacity(0.9),
              ),
              onPressed: () {
                setState(() {
                  _tabIndex = 1;
                });
              },
              child: const Text(
                'JOIN THE LAZY LOUNGE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Icon(icon, size: 18, color: AppColors.textSoft),
    );
  }



  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _tabIndex,
      onTap: (i) => setState(() => _tabIndex = i),
      backgroundColor: Colors.black.withOpacity(0.9),
      selectedItemColor: AppColors.blueSoft,
      unselectedItemColor: AppColors.textSoft,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book),
          label: 'Diary',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_note),
          label: 'Plan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Stats',
        ),
      ],
    );
  }

  // --------- TAB 1: DIARY ---------
  Widget _buildDiaryTab() {
    final today = _today();
    final todays = _diary.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return d == today;
    }).toList();
    final older = _diary.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return d != today;
    }).toList();

    final todayMinutes =
    todays.fold<int>(0, (s, e) => s + e.minutes);

    return Container(
      color: AppColors.bgOuter,
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Форма создания записи
            _buildDiaryForm(todayMinutes),
            const SizedBox(height: 16),
            const Text(
              'Today',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (todays.isEmpty)
              const Text(
                'No entries yet. Log your first legendary lazy moment.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              ...todays.map(_buildDiaryCard),
            const SizedBox(height: 12),
            const Text(
              'Earlier entries',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (older.isEmpty)
              const Text(
                'Your past laziness will appear here.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              ...older.map(_buildDiaryCard),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryForm(int todayMinutes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Slacker\'s Diary',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Log your most gloriously wasted moments',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
          ),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NEW DIARY ENTRY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.textSoft,
                ),
              ),
              const SizedBox(height: 8),
              _appTextField(
                controller: _diaryTitleCtrl,
                label: 'Activity title',
                hint: 'Scrolled TikTok for no reason',
              ),
              const SizedBox(height: 8),
              _appTextField(
                controller: _diaryDescCtrl,
                label: 'Description',
                hint:
                'What were you doing and how did it feel?',
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _appTextField(
                      controller: _diaryMinutesCtrl,
                      label: 'Wasted time (min)',
                      hint: '45',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mood',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.chip,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.borderSoft),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _diaryMood,
                              dropdownColor: AppColors.panel,
                              isExpanded: true,
                              items: const [
                                'Chill',
                                'Blissful',
                                'Guilty but happy',
                                'Totally numb',
                                'Hilarious',
                              ]
                                  .map(
                                    (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMain,
                                    ),
                                  ),
                                ),
                              )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _diaryMood = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _attachMockPhoto = !_attachMockPhoto;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(16),
                        border:
                        Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachMockPhoto
                                ? Icons.camera_alt
                                : Icons.camera_alt_outlined,
                            size: 14,
                            color: AppColors.textSoft,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Attach mock photo',
                            style: TextStyle(
                                fontSize: 11,
                                color: _attachMockPhoto
                                    ? AppColors.blueSoft
                                    : AppColors.textSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${DateTime.now().weekdayName()}, '
                        '${DateTime.now().day} '
                        '${DateTime.now().monthNameShort()}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (_attachMockPhoto)
                const Padding(
                  padding: EdgeInsets.only(top: 6.0),
                  child: Text(
                    '📸 1 mock photo will be attached to this entry.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.blueSoft),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: const Color(0xFF020812),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    elevation: 14,
                    shadowColor: AppColors.blue.withOpacity(0.8),
                  ),
                  onPressed: _saveDiaryEntry,
                  child: const Text(
                    'Save entry',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Quick stats
        Container(
          decoration: BoxDecoration(
            color: AppColors.panelSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
          ),
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'QUICK STATS (DEMO)',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickStatsBlock(
                    value: _diary.length.toString(),
                    label: 'Entries',
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.borderSoft,
                  ),
                  _quickStatsBlock(
                    value: _formatMinutes(todayMinutes),
                    label: 'Today',
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.borderSoft,
                  ),
                  _quickStatsBlock(
    value: '🏆',
    label: 'Master',
    ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _quickStatsBlock({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDiaryCard(DiaryEntry e) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _updateDiaryEntry(e),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.description.isEmpty
                            ? 'No description. The laziness speaks for itself.'
                            : e.description,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSoft),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textMuted),
                onPressed: () async {
                  final action = await showModalBottomSheet<String>(
                    context: context,
                    backgroundColor: AppColors.panel,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit,
                              color: AppColors.textMain),
                          title: const Text('Edit'),
                          onTap: () => Navigator.pop(context, 'edit'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete,
                              color: Colors.redAccent),
                          title: const Text('Delete'),
                          onTap: () =>
                              Navigator.pop(context, 'delete'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                  if (action == 'edit') {
                    _updateDiaryEntry(e);
                  } else if (action == 'delete') {
                    _deleteDiaryEntry(e);
                  }
                },
              ),
            ],
          ),
          if (e.hasMockPhoto) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 1,
                itemBuilder: (_, i) => Container(
                  width: 60,
                  margin: EdgeInsets.only(right: i == 0 ? 8 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2C323E),
                        Color(0xFF1A1C26),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(child: Text('📸')),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 13, color: AppColors.goldSoft),
                  const SizedBox(width: 4),
                  Text(
                    _formatMinutes(e.minutes),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.goldSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  const Icon(Icons.sentiment_satisfied,
                      size: 13, color: AppColors.textSoft),
                  const SizedBox(width: 4),
                  Text(
                    e.mood,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSoft,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${e.date.day} ${e.date.monthNameShort()}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------- TAB 2: PLAN ---------
  Widget _buildPlanTab() {
    final total = _plan.length;
    final done = _plan.where((t) => t.completed).length;
    final percent = total == 0 ? 0.0 : done / total;

    String progressText;
    if (total == 0) {
      progressText =
      'Add tasks and then proudly avoid productivity.';
    } else if (done == 0) {
      progressText = 'A fresh canvas of potential procrastination.';
    } else if (done < total) {
      progressText =
      'Already $done tasks lazily completed. Impressive.';
    } else {
      progressText =
      'Flawlessly lazy execution. You did every lazy thing you promised.';
    }

    return Container(
      color: AppColors.bgOuter,
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Idleness Plan',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Master the art of scheduled laziness',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            // Progress
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TODAY\'S PROGRESS',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: AppColors.textSoft,
                        ),
                      ),
                      Text(
                        '$done/$total Complete',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.goldSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 6,
                      color: AppColors.chip,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: percent,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.blue, Color(0xFF3D7CD9)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    progressText,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Form
            Container(
              decoration: BoxDecoration(
                color: AppColors.panelSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ADD LAZY TASK',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: AppColors.textSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _appTextField(
                    controller: _planTitleCtrl,
                    label: 'Task title',
                    hint: 'Watch 3 episodes of random show',
                  ),
                  const SizedBox(height: 8),
                  _appTextField(
                    controller: _planDescCtrl,
                    label: 'Description (optional)',
                    hint:
                    'Extra details about how you will gloriously avoid work...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _appTextField(
                          controller: _planMinutesCtrl,
                          label: 'Planned time (min)',
                          hint: '60',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.8,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.chip,
                                borderRadius:
                                BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.borderSoft),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _planCategory,
                                  dropdownColor: AppColors.panel,
                                  isExpanded: true,
                                  items: const [
                                    'Screens',
                                    'Food & Drinks',
                                    'Social',
                                    'Pure nothingness',
                                  ]
                                      .map(
                                        (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color:
                                          AppColors.textMain,
                                        ),
                                      ),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (v) => setState(
                                          () => _planCategory = v!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _applyRandomIdea,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.chip,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.borderSoft),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.auto_awesome,
                                  size: 14,
                                  color: AppColors.textSoft),
                              SizedBox(width: 6),
                              Text(
                                'Random lazy idea',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSoft,
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: const Color(0xFF020812),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(100),
                          ),
                          elevation: 14,
                          shadowColor:
                          AppColors.blue.withOpacity(0.8),
                        ),
                        onPressed: _addTaskFromForm,
                        child: const Text(
                          'Add task',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Challenge of the day
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lazy Challenge of the Day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _newChallenge,
                  icon: const Icon(Icons.refresh,
                      size: 14, color: AppColors.blueSoft),
                  label: const Text(
                    'New',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.blueSoft),
                  ),
                )
              ],
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _challengeTitle,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _challengeDesc,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSoft),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor:
                            const Color(0xFF020812),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(100),
                            ),
                            elevation: 14,
                            shadowColor: AppColors.blue
                                .withOpacity(0.8),
                          ),
                          onPressed: _acceptChallengeAsTask,
                          child: const Text(
                            'Accept Challenge (adds as task)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'TODAY\'S LAZY TASKS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_plan.isEmpty)
              const Text(
                'No tasks yet. Add a few and then heroically complete them.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              ..._plan.map(_buildTaskCard),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(LazyTask t) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleTask(t),
            child: Container(
              margin: const EdgeInsets.only(top: 3),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color:
                t.completed ? AppColors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: t.completed
                      ? AppColors.blue
                      : AppColors.borderSoft,
                  width: 2,
                ),
              ),
              child: t.completed
                  ? const Icon(Icons.check,
                  size: 14, color: Colors.black)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _editTask(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: t.completed
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: t.completed
                          ? AppColors.textSoft.withOpacity(0.7)
                          : AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.description.isEmpty
                        ? 'No description. Just vibes.'
                        : t.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.completed
                          ? AppColors.textSoft.withOpacity(0.7)
                          : AppColors.textSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: t.completed
                            ? AppColors.goldSoft
                            : AppColors.textSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.minutes > 0
                            ? '${_formatMinutes(t.minutes)} planned'
                            : 'No time limit',
                        style: TextStyle(
                          fontSize: 11,
                          color: t.completed
                              ? AppColors.goldSoft
                              : AppColors.textSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit,
                    size: 16, color: AppColors.textMuted),
                onPressed: () => _editTask(t),
              ),
              IconButton(
                icon: const Icon(Icons.delete,
                    size: 16, color: Colors.redAccent),
                onPressed: () => _deleteTask(t),
              ),
            ],
          )
        ],
      ),
    );
  }

  // --------- TAB 3: STATS / PROFILE ---------
  Widget _buildStatsTab() {
    final totalMinutes = _totalMinutes;
    final buckets = _buckets();
    final totalBucketMinutes = buckets.values
        .fold<int>(0, (sum, m) => sum + m);

    return Container(
      color: AppColors.bgOuter,
      child: SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile & Analytics',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save,
                      size: 16, color: AppColors.blueSoft),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.blueSoft),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const _AvatarIcon(left: true),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _profileNameCtrl,
                              style: const TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration:
                              const InputDecoration.collapsed(
                                  hintText: 'Name'),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Professional Time Waster',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSoft),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius:
                                BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Master Level',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Height',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSoft),
                              ),
                              TextField(
                                controller: _profileHeightCtrl,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                decoration:
                                const InputDecoration.collapsed(
                                    hintText: '175 cm'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weight',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSoft),
                              ),
                              TextField(
                                controller: _profileWeightCtrl,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                                decoration:
                                const InputDecoration.collapsed(
                                    hintText: '70 kg'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.panelSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Favorite Waste of Time',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSoft),
                        ),
                        TextField(
                          controller: _profileFavoriteCtrl,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          decoration:
                          const InputDecoration.collapsed(
                              hintText: 'Netflix Binging 📺'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Time Wasted Analytics',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TOTAL TIME WASTED (ALL ENTRIES)',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatMinutes(totalMinutes),
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _diary.isEmpty
                        ? 'You haven\'t logged any glorious laziness yet.'
                        : 'Keep going, your couch believes in you 📈',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.goldSoft),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Estimated daily avg (30 days)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMinutes(
                                    (totalMinutes / 30).round()),
                                style: const TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.panelSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Entries logged',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSoft,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _diary.length.toString(),
                                style: const TextStyle(
                                  fontFamily: 'Playfair Display',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Top Time-Wasting Buckets',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (totalBucketMinutes == 0)
              const Text(
                'As you add diary entries, your top time-wasters will appear here.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              ...buckets.entries
                  .where((e) => e.value > 0)
                  .toList()
                  .map((e) {
                final percent =
                (e.value / totalBucketMinutes * 100).round();
                final emoji = e.key == 'Screens'
                    ? '📱'
                    : e.key == 'Mobile Gaming'
                    ? '🎮'
                    : e.key == 'Social'
                    ? '💬'
                    : '💭';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.panelSoft,
                    borderRadius: BorderRadius.circular(18),
                    border:
                    Border.all(color: AppColors.borderSoft),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${_formatMinutes(e.value)} logged',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSoft),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.goldSoft,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 6,
                          color: AppColors.chip,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percent / 100,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold,
                                    AppColors.blue
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            const Text(
              'Achievements & Badges',
              style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _achievementCard(
                  emoji: '👑',
                  title: 'King of the Couch',
                  description: '50+ hours lounging',
                  unlocked: true,
                ),
                _achievementCard(
                  emoji: '🏆',
                  title: 'Master of Procrastination',
                  description: '100+ hours wasted',
                  unlocked: true,
                ),
                _achievementCard(
                  emoji: '📱',
                  title: 'Scrolling Champion',
                  description: '10,000+ swipes',
                  unlocked: true,
                ),
                _achievementCard(
                  emoji: '🛌',
                  title: 'Sleep Emperor',
                  description: 'Need 12h nap time',
                  unlocked: false,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _achievementCard({
    required String emoji,
    required String title,
    required String description,
    required bool unlocked,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 8) / 2,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
          unlocked ? AppColors.gold.withOpacity(0.7) : AppColors.borderSoft,
        ),
        boxShadow: unlocked
            ? const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSoft,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.gold
                  : AppColors.panelSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unlocked ? 'Unlocked' : 'Locked',
              style: TextStyle(
                fontSize: 10,
                color: unlocked ? Colors.black : AppColors.textSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- common widgets ----------

  Widget _appTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.chip,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Иконка‑силуэт как на референсе (левая/правая)
class _AvatarIcon extends StatelessWidget {
  const _AvatarIcon({required this.left});

  final bool left;

  @override
  Widget build(BuildContext context) {
    final baseGradient = left
        ? const [Color(0xFF39455C), Color(0xFF1E212C)]
        : const [Color(0xFF4A3F55), Color(0xFF221822)];

    final bodyTop = left
        ? const [Color(0xFFF6F3F0), Color(0xFFD4C7BD), Color(0xFF7C6A5A)]
        : const [Color(0xFFFFEDEE), Color(0xFFE7B6B8), Color(0xFF8E5860)];

    final headTop = left
        ? const [Color(0xFFFDF7F1), Color(0xFFD2C3B4)]
        : const [Color(0xFFFFF7F7), Color(0xFFE2C0C3)];

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: baseGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 18,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 34,
          height: 38,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 34,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: bodyTop,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: headTop,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------- extensions for date formatting -----------

extension _DateExt on DateTime {
  String weekdayName() {
    const names = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return names[weekday - 1];
  }

  String monthNameShort() {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}