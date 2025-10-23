import 'package:flutter/material.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../parts/diagonal_slash_painter.dart';

class CrossCalendarAlert extends StatefulWidget {
  const CrossCalendarAlert({
    super.key,
    required this.years,
    required this.monthDays,
    required this.data,
    required this.headerHeight,
    required this.leftColWidth,
    required this.rowHeights,
    required this.colWidths,
  }) : assert(rowHeights.length == years.length + 1),
       assert(colWidths.length == monthDays.length + 1);

  final List<String> years;

  final List<String> monthDays;

  final Map<String, Map<String, String>> data;

  final double headerHeight;
  final double leftColWidth;
  final List<double> rowHeights;

  final List<double> colWidths;

  @override
  State<CrossCalendarAlert> createState() => _CrossCalendarAlertState();
}

class _CrossCalendarAlertState extends State<CrossCalendarAlert> {
  late final AutoScrollController _hHeaderCtrl;
  late final AutoScrollController _hBodyCtrl;

  final ScrollController _vLeftCtrl = ScrollController();
  final ScrollController _vBodyCtrl = ScrollController();

  final ScrollController _monthBarCtrl = ScrollController();
  final List<GlobalKey> _monthKeys = List<GlobalKey>.generate(12, (_) => GlobalKey());

  late final List<GlobalKey> _yearKeys;

  bool _syncingH = false;
  bool _syncingV = false;

  int _currentMonth = 1;

  late final Map<int, int> _monthStartIndex;

  late final Map<String, int> _dayIndex;

  late final List<double> _prefixWidths;

  ///
  double get _bodyTotalHeight {
    double sum = 0;

    for (int r = 1; r < widget.rowHeights.length; r++) {
      sum += widget.rowHeights[r];
    }

    return sum;
  }

  ///
  @override
  void initState() {
    super.initState();

    _hHeaderCtrl = AutoScrollController(axis: Axis.horizontal);

    _hBodyCtrl = AutoScrollController(axis: Axis.horizontal);

    final DateTime now = DateTime.now();

    _currentMonth = now.month;

    _yearKeys = List<GlobalKey>.generate(widget.years.length, (_) => GlobalKey());

    _monthStartIndex = <int, int>{
      for (int m = 1; m <= 12; m++)
        m: widget.monthDays.indexWhere((String md) => md.startsWith('${m.toString().padLeft(2, '0')}-')),
    };

    _dayIndex = <String, int>{for (int i = 0; i < widget.monthDays.length; i++) widget.monthDays[i]: i};

    _prefixWidths = List<double>.filled(widget.monthDays.length + 1, 0);

    for (int i = 1; i <= widget.monthDays.length; i++) {
      _prefixWidths[i] = _prefixWidths[i - 1] + widget.colWidths[i];
    }

    _hHeaderCtrl.addListener(() {
      if (_syncingH) {
        return;
      }

      _syncingH = true;

      if (_hBodyCtrl.hasClients) {
        _hBodyCtrl.jumpTo(_hHeaderCtrl.offset);
      }

      _syncingH = false;

      _updateCurrentMonthByOffset(_hHeaderCtrl.offset);
    });

    _hBodyCtrl.addListener(() {
      if (_syncingH) {
        return;
      }

      _syncingH = true;

      if (_hHeaderCtrl.hasClients) {
        _hHeaderCtrl.jumpTo(_hBodyCtrl.offset);
      }

      _syncingH = false;

      _updateCurrentMonthByOffset(_hBodyCtrl.offset);
    });

    _vLeftCtrl.addListener(() {
      if (_syncingV) {
        return;
      }

      _syncingV = true;

      if (_vBodyCtrl.hasClients) {
        _vBodyCtrl.jumpTo(_vLeftCtrl.offset);
      }

      _syncingV = false;
    });

    _vBodyCtrl.addListener(() {
      if (_syncingV) {
        return;
      }

      _syncingV = true;

      if (_vLeftCtrl.hasClients) {
        _vLeftCtrl.jumpTo(_vBodyCtrl.offset);
      }

      _syncingV = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _scrollToTodayDay(fromInit: true);
    });
  }

  ///
  void _updateCurrentMonthByOffset(double dx) {
    int lo = 0, hi = widget.monthDays.length;

    while (lo < hi) {
      final int mid = (lo + hi) >> 1;
      if (_prefixWidths[mid] <= dx) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    final int idx = (lo - 1).clamp(0, widget.monthDays.length - 1);

    final String md = widget.monthDays[idx];

    final int m = int.tryParse(md.substring(0, 2)) ?? 1;

    if (m != _currentMonth) {
      setState(() => _currentMonth = m);

      _ensureMonthButtonVisible(m);
    }
  }

  ///
  Future<void> _scrollToMonth(int month) async {
    final int idx = _monthStartIndex[month] ?? 0;

    _syncingH = true;

    // ignore: strict_raw_type, always_specify_types
    await Future.wait(<Future>[
      _hHeaderCtrl.scrollToIndex(
        idx,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 260),
      ),
      _hBodyCtrl.scrollToIndex(
        idx,
        preferPosition: AutoScrollPosition.begin,
        duration: const Duration(milliseconds: 260),
      ),
    ]);

    _syncingH = false;

    if (_currentMonth != month) {
      setState(() => _currentMonth = month);
    }

    _ensureMonthButtonVisible(month);
  }

  ///
  Future<void> _scrollToTodayDay({bool fromInit = false}) async {
    final DateTime now = DateTime.now();

    final String md = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final int? idx = _dayIndex[md];

    if (idx != null) {
      _syncingH = true;

      // ignore: strict_raw_type, always_specify_types
      await Future.wait(<Future>[
        _hHeaderCtrl.scrollToIndex(
          idx,
          preferPosition: AutoScrollPosition.begin,
          duration: const Duration(milliseconds: 260),
        ),
        _hBodyCtrl.scrollToIndex(
          idx,
          preferPosition: AutoScrollPosition.begin,
          duration: const Duration(milliseconds: 260),
        ),
      ]);

      _syncingH = false;
    } else {
      await _scrollToMonth(now.month);
    }

    if (_currentMonth != now.month) {
      setState(() => _currentMonth = now.month);
    }

    _ensureMonthButtonVisible(now.month, alignment: fromInit ? (now.month >= 7 ? 1.0 : 0.0) : 0.5, animate: !fromInit);

    _ensureYearVisible(_closestYearTo(now.year), animate: !fromInit);
  }

  ///
  void _ensureMonthButtonVisible(int month, {double alignment = 0.5, bool animate = true}) {
    final int i = (month - 1).clamp(0, 11);

    final BuildContext? ctx = _monthKeys[i].currentContext;

    if (ctx == null) {
      return;
    }

    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,

      duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  ///
  void _ensureYearVisible(int year, {double alignment = 0.5, bool animate = true}) {
    final int idx = widget.years.indexOf(year.toString());

    if (idx < 0 || idx >= _yearKeys.length) {
      return;
    }

    final BuildContext? ctx = _yearKeys[idx].currentContext;

    if (ctx == null) {
      return;
    }

    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,

      duration: animate ? const Duration(milliseconds: 240) : Duration.zero,
      curve: Curves.easeOut,
    );
  }

  ///
  int _closestYearTo(int y) {
    final int idx = widget.years.indexOf(y.toString());

    if (idx >= 0) {
      return y;
    }

    final List<int> nums = widget.years.map(int.parse).toList()..sort();

    int best = nums.first, diff = (nums.first - y).abs();

    for (final int v in nums) {
      final int d = (v - y).abs();

      if (d < diff) {
        best = v;

        diff = d;
      }
    }

    return best;
  }

  ///
  @override
  void dispose() {
    _hHeaderCtrl.dispose();

    _hBodyCtrl.dispose();

    _vLeftCtrl.dispose();

    _vBodyCtrl.dispose();

    _monthBarCtrl.dispose();

    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    final double headerH = widget.headerHeight;

    final double leftW = widget.leftColWidth;

    return Column(
      children: <Widget>[
        SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ListView.separated(
                  controller: _monthBarCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: 12,
                  itemBuilder: (BuildContext context, int i) {
                    final int month = i + 1;

                    final bool selected = month == _currentMonth;

                    return Container(
                      key: _monthKeys[i],
                      child: GestureDetector(
                        onTap: () => _scrollToMonth(month),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: selected ? Colors.blue : Colors.grey.shade300,
                          foregroundColor: selected ? Colors.white : Colors.black87,
                          child: Text('$month月'),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Wrap(
                  spacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _scrollToMonth(DateTime.now().month),
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('今月'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(72, 40)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _scrollToTodayDay(),
                      icon: const Icon(Icons.today, size: 18),
                      label: const Text('今日'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(72, 40)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                width: leftW,
                height: headerH,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F7),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE0E0E0)),
                      right: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Center(
                    child: Text(r'Year \ Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),

              Positioned(
                left: leftW,
                right: 0,
                top: 0,
                height: headerH,
                child: ListView.builder(
                  controller: _hHeaderCtrl,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.monthDays.length,
                  itemBuilder: (_, int idx) => AutoScrollTag(
                    // ignore: always_specify_types
                    key: ValueKey('hheader_$idx'),
                    controller: _hHeaderCtrl,
                    index: idx,
                    child: _headerCell(width: widget.colWidths[idx + 1], md: widget.monthDays[idx]),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                top: headerH,
                bottom: 0,
                width: leftW,
                child: Scrollbar(
                  controller: _vLeftCtrl,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _vLeftCtrl,
                    itemCount: widget.years.length,
                    itemBuilder: (BuildContext context, int i) {
                      final int row = i + 1;
                      final String year = widget.years[i];
                      return Container(
                        key: _yearKeys[i],
                        height: widget.rowHeights[row],
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F8FA),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFEAEAEA)),
                            right: BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(year, style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                left: leftW,
                top: headerH,
                right: 0,
                bottom: 0,
                child: Scrollbar(
                  controller: _vBodyCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vBodyCtrl,

                    child: SizedBox(
                      height: _bodyTotalHeight,
                      child: ListView.builder(
                        controller: _hBodyCtrl,
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.monthDays.length,
                        itemBuilder: (_, int colIdx) => AutoScrollTag(
                          // ignore: always_specify_types
                          key: ValueKey('hbody_$colIdx'),
                          controller: _hBodyCtrl,
                          index: colIdx,
                          child: _buildColumnOfYear(
                            md: widget.monthDays[colIdx],
                            colWidth: widget.colWidths[colIdx + 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ///
  Widget _headerCell({required double width, required String md}) {
    final String label = _mdToSlash(md);

    final bool isLeapDay = (md == '02-29');

    return Container(
      width: width,
      height: widget.headerHeight,
      decoration: BoxDecoration(
        color: isLeapDay ? const Color(0xFFFAFAFA) : const Color(0xFFF5F5F7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
          right: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  ///
  Widget _buildColumnOfYear({required String md, required double colWidth}) {
    final DateTime today = DateTime.now();

    final String todayMd = '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final String todayYear = today.year.toString();

    return SizedBox(
      width: colWidth,
      child: Column(
        children: <Widget>[
          for (int r = 0; r < widget.years.length; r++)
            _bodyCell(
              width: colWidth,
              height: widget.rowHeights[r + 1],
              isDisabled: _isNonLeapFeb29(widget.years[r], md),
              isToday: widget.years[r] == todayYear && md == todayMd,
              child: _isNonLeapFeb29(widget.years[r], md) ? const SizedBox.shrink() : _cellContent(widget.years[r], md),
            ),
        ],
      ),
    );
  }

  ///
  Widget _cellContent(String year, String md) {
    final String? v = widget.data[year]?[md];

    final String fallback = _ymdJP(year, md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[Text(v ?? fallback, maxLines: 2, overflow: TextOverflow.ellipsis)],
    );
  }

  ///
  bool _isNonLeapFeb29(String year, String md) {
    if (md != '02-29') {
      return false;
    }

    final int y = int.tryParse(year) ?? 0;

    final bool isLeap = (y % 400 == 0) || (y % 4 == 0 && y % 100 != 0);

    return !isLeap;
  }

  ///
  String _mdToSlash(String md) {
    final int m = int.tryParse(md.substring(0, 2)) ?? 1;

    final int d = int.tryParse(md.substring(3, 5)) ?? 1;

    return '$m/$d';
  }

  ///
  String _ymdJP(String year, String md) {
    final int m = int.tryParse(md.substring(0, 2)) ?? 1;

    final int d = int.tryParse(md.substring(3, 5)) ?? 1;

    return '$year年$m月$d日';
  }

  ///
  Widget _bodyCell({
    required double width,
    required double height,
    required Widget child,
    bool isDisabled = false,
    bool isToday = false,
  }) {
    final Container frame = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAEAEA)),
          right: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );

    if (isDisabled) {
      return Stack(
        children: <Widget>[
          Container(width: width, height: height, color: const Color(0xFFF0F0F0)),
          CustomPaint(size: Size(width, height), painter: DiagonalSlashPainter()),
          frame,
        ],
      );
    }

    final Container base = Container(width: width, height: height, color: isToday ? const Color(0xFFFFF9C4) : null);

    return Stack(
      children: <Widget>[
        base,
        frame,
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: child),
      ],
    );
  }
}
