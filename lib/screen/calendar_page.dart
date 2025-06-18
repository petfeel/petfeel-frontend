// lib/screen/calendar_page.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'home_connected_page.dart';

class Calendar extends StatefulWidget {
  final Map<String, dynamic> petData;
  const Calendar({Key? key, required this.petData}) : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late Map<String, dynamic> data;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 기본 카테고리 목록
  static final List<Map<String, dynamic>> _categories = [
    {'label': '건강검진', 'color': const Color(0xFFB2E5FA)},
    {'label': '미용', 'color': const Color(0xFFD9B8F5)},
    {'label': '애견카페', 'color': const Color(0xFFA8D68D)},
    {'label': '영양제', 'color': const Color(0xFFF7B1A4)},
    {'label': '예방접종', 'color': const Color(0xFFFFF0B3)},
  ];

  // 기본 일간 아이템 (항상 보여줄 체크박스용)
  static const _defaultDailyItems = [
    {'category': '산책', 'color': Color(0xFF9EDFCF), 'content': '', 'checked': false},
    {'category': '밥 주기', 'color': Color(0xFFB0BEC5), 'content': '', 'checked': false},
  ];
  static const _defaultCats = {'산책', '밥 주기'};
  static final Map<String, List<Map<String, dynamic>>> _itemsPerDate = {};

  String? _selectedCategoryLabel;

  @override
  void initState() {
    super.initState();
    data = widget.petData;
    _selectedDay = _focusedDay;
    _ensureDefaults(_selectedDay!.toIso8601String().split('T').first);
  }

  void _ensureDefaults(String key) {
    _itemsPerDate.putIfAbsent(
      key,
          () => _defaultDailyItems.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  void _showAddItemDialog() {
    if (_categories.isNotEmpty) {
      _selectedCategoryLabel = _categories.first['label'] as String;
    }
    String content = '';
    bool isContentValid = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          // 화면 너비를 가져와서 카테고리 박스 크기 계산
          final screenWidth = MediaQuery.of(context).size.width;
          // 아래 계산식은 좌우 패딩 16씩, Wrap의 spacing 8씩 총 4개(아이템이 5개일 때) 가정.
          // (screenWidth - (패딩 16*2) - (spacing 8*4)) / 5
          final double itemSize = (screenWidth - 32 - 32) / 5;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // “카테고리 선택” 영역
                  Row(
                    children: [
                      const Text(
                        '카테고리 선택',
                        style: TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          String temp = '';
                          await showDialog<String>(
                            context: context,
                            builder: (_) {
                              return StatefulBuilder(
                                builder: (context, setDialogState) {
                                  return AlertDialog(
                                    backgroundColor: Colors.white,
                                    title: const Text(
                                      '새 카테고리 추가',
                                      style: TextStyle(
                                        fontFamily: 'LGSmartUI',
                                        fontSize: 14,
                                      ),
                                    ),
                                    content: TextField(
                                      autofocus: true,
                                      onChanged: (v) {
                                        temp = v.trim();
                                        setDialogState(() {});
                                      },
                                      decoration: const InputDecoration(
                                        hintText: '카테고리 이름 입력',
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          '취소',
                                          style: TextStyle(
                                            fontFamily: 'LGSmartUI',
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: temp.isNotEmpty
                                            ? () => Navigator.pop(context, temp)
                                            : null,
                                        style: TextButton.styleFrom(
                                          foregroundColor: temp.isNotEmpty
                                              ? Colors.deepPurple
                                              : Colors.grey,
                                        ),
                                        child: const Text(
                                          '추가',
                                          style: TextStyle(
                                            fontFamily: 'LGSmartUI',
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ).then((newLabel) {
                            if (newLabel != null &&
                                newLabel.isNotEmpty &&
                                !_defaultCats.contains(newLabel) &&
                                !_categories.any((c) => c['label'] == newLabel)) {
                              final newColor =
                              Color((0xFF << 24) | (newLabel.hashCode & 0x00FFFFFF));
                              setState(() {
                                _categories.add({'label': newLabel, 'color': newColor});
                                _selectedCategoryLabel = newLabel;
                              });
                              setModalState(() {});
                            }
                          });
                        },
                        child: const Text(
                          '카테고리 추가',
                          style: TextStyle(
                            fontFamily: 'LGSmartUI',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Wrap 내에서 각각의 카테고리 박스 크기를 itemSize로 동적으로 지정
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((cat) {
                      final isSel = _selectedCategoryLabel == cat['label'];
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                setModalState(() => _selectedCategoryLabel = cat['label']),
                            child: Container(
                              width: itemSize,  // 동적 계산된 너비
                              height: itemSize, // 동적 계산된 높이
                              decoration: BoxDecoration(
                                color: isSel ? Colors.grey.shade200 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? Colors.black : Colors.transparent,
                                  width: isSel ? 1.5 : 0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 20,  // 아이콘 원 크기 유지
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: cat['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat['label'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'LGSmartUI',
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setState(
                                      () => _categories.removeWhere(
                                        (c) => c['label'] == cat['label'],
                                  ),
                                );
                                setModalState(() {});
                              },
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    '내용 입력',
                    style: TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    onChanged: (v) {
                      content = v.trim();
                      setModalState(() => isContentValid = content.isNotEmpty);
                    },
                    decoration: const InputDecoration(
                      hintText: '내용을 입력하세요',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'LGSmartUI',
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isContentValid ? const Color(0xFFF1F1F1) : Colors.grey.shade300,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: isContentValid
                          ? () {
                        final key =
                            _selectedDay!.toIso8601String().split('T').first;
                        if (_selectedCategoryLabel == null) return;
                        final category = _categories.firstWhere(
                              (c) => c['label'] == _selectedCategoryLabel,
                          orElse: () => {},
                        );
                        if (category.isEmpty) return;

                        _ensureDefaults(key);
                        _itemsPerDate[key]!.insert(0, {
                          'category': category['label'],
                          'color': category['color'],
                          'content': content,
                          'checked': false,
                        });
                        setState(() {});
                        Navigator.pop(context);
                      }
                          : null,
                      child: const Text('+ 추가'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _selectedDay?.toIso8601String().split('T').first ?? '';
    if (selectedKey.isNotEmpty) _ensureDefaults(selectedKey);
    final items = selectedKey.isNotEmpty ? (_itemsPerDate[selectedKey] ?? []) : [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        title: const Text(
          '캘린더',
          style: TextStyle(
            fontFamily: 'LGSmartUI',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _ensureDefaults(selectedDay.toIso8601String().split('T').first);
              });
            },
            eventLoader: (day) {
              final key = day.toIso8601String().split('T').first;
              _ensureDefaults(key);
              return (_itemsPerDate[key] ?? [])
                  .where((e) => !_defaultCats.contains(e['category']))
                  .toList();
            },
            calendarBuilders: CalendarBuilders(
              todayBuilder: (context, day, _) {
                final bool isSelected = isSameDay(_selectedDay, day);
                if (isSelected) {
                  return Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: const TextStyle(
                          fontFamily: 'LGSmartUI',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                } else {
                  return Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        fontFamily: 'LGSmartUI',
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
              },
              selectedBuilder: (context, day, _) {
                final bool isToday = isSameDay(day, DateTime.now());
                final Color bg = isToday ? Colors.red : Colors.black;
                return Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                        fontFamily: 'LGSmartUI',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 4,
                  child: Row(
                    children: events.reversed.take(4).map((e) {
                      final map = e as Map<String, dynamic>;
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: map['color'] as Color? ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            headerStyle:
            const HeaderStyle(titleCentered: true, formatButtonVisible: false),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(),
              selectedDecoration: BoxDecoration(),
              defaultTextStyle: TextStyle(fontFamily: 'LGSmartUI'),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F1F1),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(
                    fontFamily: 'LGSmartUI',
                    fontSize: 14,
                  ),
                ),
                onPressed: _showAddItemDialog,
                child: const Text('+ 항목 추가'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.hashCode),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      final key = _selectedDay
                          ?.toIso8601String()
                          .split('T')
                          .first;
                      final list = key != null ? _itemsPerDate[key] : null;
                      if (list != null && index < list.length) {
                        setState(() => list.removeAt(index));
                      }
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.redAccent,
                      child: const Icon(Icons.delete, color: Colors.white, size: 20),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color?)?.withOpacity(0.3) ??
                            Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Transform.scale(
                                scale: 0.85,
                                child: Checkbox(
                                  value: item['checked'] as bool? ?? false,
                                  onChanged: (v) {
                                    final key = _selectedDay
                                        ?.toIso8601String()
                                        .split('T')
                                        .first;
                                    final list = key != null ? _itemsPerDate[key] : null;
                                    if (list != null && index < list.length) {
                                      setState(() => list[index]['checked'] = v ?? false);
                                    }
                                  },
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item['category'] ?? '',
                                style: const TextStyle(
                                  fontFamily: 'LGSmartUI',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              item['content'] ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'LGSmartUI',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
