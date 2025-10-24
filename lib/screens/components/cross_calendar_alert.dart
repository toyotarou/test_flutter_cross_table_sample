import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../extensions/extensions.dart';
import '../parts/diagonal_slash_painter.dart';

class CrossCalendar extends ConsumerStatefulWidget {
  const CrossCalendar({
    super.key,
    required this.years,
    required this.monthDays,
    required this.headerHeight,
    required this.leftColWidth,
    required this.rowHeights,
    required this.colWidths,
  }) : assert(rowHeights.length == years.length + 1),
       assert(colWidths.length == monthDays.length + 1);

  final List<String> years;
  final List<String> monthDays;

  final double headerHeight;
  final double leftColWidth;
  final List<double> rowHeights;
  final List<double> colWidths;

  @override
  ConsumerState<CrossCalendar> createState() => _CrossCalendarState();
}

class _CrossCalendarState extends ConsumerState<CrossCalendar> {
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

  final Map<String, String> _weekdayCache = <String, String>{};

  final Map<String, Color> _lifetimeColorCache = <String, Color>{};

  final Map<String, bool> _holidayCache = <String, bool>{};

  static const TextStyle _text12 = TextStyle(fontSize: 12);
  static const TextStyle _text12Bold = TextStyle(fontSize: 12, fontWeight: FontWeight.bold);
  static const EdgeInsets _cellPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

  ///
  double get _bodyTotalHeight => widget.rowHeights
      .asMap()
      .entries
      .where((MapEntry<int, double> e) => e.key > 0)
      .fold<double>(0, (double sum, MapEntry<int, double> e) => sum + e.value);

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
  String _weekdayOf(String y, String md) {
    final String key = '$y-$md';
    final String? cached = _weekdayCache[key];
    if (cached != null) {
      return cached;
    }

    final int yy = int.parse(y);
    final int mm = int.parse(md.substring(0, 2));
    final int dd = int.parse(md.substring(3, 5));

    final String val = DateTime(yy, mm, dd).youbiStr;

    _weekdayCache[key] = val;
    return val;
  }

  ///
  bool _isHoliday(String date, String youbi) {
    final bool? c = _holidayCache[date];
    if (c != null) {
      return c;
    }

    final bool v = youbi == 'Saturday' || youbi == 'Sunday';
    _holidayCache[date] = v;
    return v;
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

    final double lifetimeTileW = MediaQuery.of(context).size.width / 30;

    return Column(
      children: <Widget>[
        getMonthSelectButton(),
        const Divider(height: 1),

        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                width: leftW,
                height: headerH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      right: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: const Center(child: Text(r'Year \ Date', style: _text12Bold)),
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
                  cacheExtent: 400,

                  addAutomaticKeepAlives: false,
                  addSemanticIndexes: false,
                  itemBuilder: (_, int idx) => AutoScrollTag(
                    // ignore: always_specify_types
                    key: ValueKey('hheader_$idx'),
                    controller: _hHeaderCtrl,
                    index: idx,
                    child: getHeaderCellContent(width: widget.colWidths[idx + 1], md: widget.monthDays[idx]),
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
                    addAutomaticKeepAlives: false,
                    addSemanticIndexes: false,
                    itemBuilder: (BuildContext context, int i) {
                      final String year = widget.years[i];
                      return SizedBox(
                        key: _yearKeys[i],
                        height: widget.rowHeights[i + 1],
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                          ),
                          child: Center(child: Text(year, style: _text12Bold)),
                        ),
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
                        cacheExtent: 400,
                        addAutomaticKeepAlives: false,
                        addSemanticIndexes: false,
                        itemBuilder: (_, int colIdx) => AutoScrollTag(
                          // ignore: always_specify_types
                          key: ValueKey('hbody_$colIdx'),
                          controller: _hBodyCtrl,
                          index: colIdx,
                          child: RepaintBoundary(
                            child: _buildColumnOfYear(
                              md: widget.monthDays[colIdx],
                              colWidth: widget.colWidths[colIdx + 1],
                              lifetimeTileW: lifetimeTileW,
                            ),
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
  Widget getMonthSelectButton() {
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              controller: _monthBarCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: 12,
              cacheExtent: 200,
              addAutomaticKeepAlives: false,
              addSemanticIndexes: false,
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
          OutlinedButton.icon(
            onPressed: () => _scrollToTodayDay(),
            icon: const Icon(Icons.today, size: 18),
            label: const Text('今日'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  ///
  Widget getHeaderCellContent({required double width, required String md}) {
    return SizedBox(
      width: width,
      height: widget.headerHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
        ),
        child: Center(child: Text(md, style: _text12Bold)),
      ),
    );
  }

  ///
  Widget _buildColumnOfYear({required String md, required double colWidth, required double lifetimeTileW}) {
    final DateTime today = DateTime.now();
    final String todayMd = '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final String todayYear = today.year.toString();

    double sum = 0;
    for (int r = 0; r < widget.years.length; r++) {
      sum += widget.rowHeights[r + 1];
    }
    if ((sum - _bodyTotalHeight).abs() > 0.5) {
      debugPrint('[CrossCalendar] ⚠ sumRows=$sum  bodyTotal=$_bodyTotalHeight  (md:$md)');
    }

    return SizedBox(
      width: colWidth,
      height: _bodyTotalHeight,

      child: Column(
        children: <Widget>[
          for (int r = 0; r < widget.years.length; r++)
            _bodyCell(
              width: colWidth,
              height: widget.rowHeights[r + 1],
              isDisabled: _isNonLeapFeb29(widget.years[r], md),
              isCurrentYear: widget.years[r] == todayYear,
              isToday: widget.years[r] == todayYear && md == todayMd,
              child: _isNonLeapFeb29(widget.years[r], md)
                  ? const SizedBox.shrink()
                  : getOneCellContent(widget.years[r], md, lifetimeTileW: lifetimeTileW),
            ),
        ],
      ),
    );
  }

  ///
  Widget getOneCellContent(String year, String md, {required double lifetimeTileW}) {
    final String date = '$year-$md';

    final String youbi = _weekdayOf(year, md);

    final bool isHoliday = _isHoliday(date, youbi);

    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: _text12),
                Text(youbi.substring(0, 3), style: _text12),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }

  ///
  Widget getLifetimeDisplayCellForCrossCalendar({
    required String date,
    required List<String> lifetimeData,
    required double tileW,
  }) {
    final List<Widget> rows = <Widget>[];
    int i = 0;

    while (i < lifetimeData.length) {
      final int end = (i + 6 <= lifetimeData.length) ? i + 6 : lifetimeData.length;
      final List<Widget> line = <Widget>[];

      for (int j = i; j < end; j++) {
        final String value = lifetimeData[j];

        line.add(
          Padding(
            padding: const EdgeInsets.all(1),

            child: SizedBox(
              width: tileW,
              child: Center(
                child: Text((j % 6 == 0) ? j.toString().padLeft(2, '0') : '', style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
        );
      }

      rows.add(Row(children: line));
      i = end;
    }

    return Column(children: rows);
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
  Widget _bodyCell({
    required double width,
    required double height,
    required Widget child,
    bool isDisabled = false,
    bool isCurrentYear = false,
    bool isToday = false,
  }) {
    Color? bg;
    if (isDisabled) {
      bg = Colors.black.withValues(alpha: 0.2);
    } else if (isToday) {
      bg = Colors.white.withValues(alpha: 0.2);
    } else if (isCurrentYear) {
      bg = Colors.white.withValues(alpha: 0.1);
    }

    BorderSide borderColor;
    if (isToday) {
      borderColor = BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3), width: 5);
    } else if (isCurrentYear) {
      borderColor = BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.2), width: 1.5);
    } else {
      borderColor = BorderSide(color: Colors.white.withValues(alpha: 0.2));
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            if (bg != null) const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
            if (bg != null) Positioned.fill(child: ColoredBox(color: bg)),

            if (isDisabled) CustomPaint(size: Size(width, height), painter: DiagonalSlashPainter()),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: Padding(
                padding: _cellPadding,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(bottom: borderColor, right: borderColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
