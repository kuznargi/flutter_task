class Note {
  final int id;
  final String name;

  Note({required this.id, required this.name});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      name: json['name'],
    );
  }
}

class Piano {
  final int id;
  final String time;
  final Note note;

  Piano({required this.id, required this.time, required this.note});

  factory Piano.fromJson(Map<String, dynamic> json) {
    return Piano(
      id: json['id'],
      time: json['time'],
      note: Note.fromJson(json['note']),
    );
  }
}