import 'package:flutter/material.dart';

class GenreFilterSheet extends StatefulWidget {
  const GenreFilterSheet({
    super.key,
    required this.genres,
    required this.initialSelected,
    required this.scrollController,
  });

  final List<String> genres;
  final Set<String> initialSelected;
  final ScrollController scrollController;

  @override
  State<GenreFilterSheet> createState() => _GenreFilterSheetState();
}

class _GenreFilterSheetState extends State<GenreFilterSheet> {
  // Sheet 내부 임시 선택 상태 (확인 버튼 전까지 목록에 반영하지 않음)
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('장르 선택', style: Theme.of(context).textTheme.titleMedium),
        ),
        // 목록만 스크롤되고, 아래 확인 버튼은 고정됨
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: widget.genres.length,
            itemBuilder: (context, index) {
              final genre = widget.genres[index];
              return CheckboxListTile(
                title: Text(genre),
                value: _selected.contains(genre),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(genre);
                  } else {
                    _selected.remove(genre);
                  }
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, Set<String>.of(_selected)),
              child: const Text('확인'),
            ),
          ),
        ),
      ],
    );
  }
}