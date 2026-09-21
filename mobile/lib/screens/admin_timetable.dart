
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/admin_api.dart';

class AdminTimetable extends StatefulWidget {
  final String token;

  const AdminTimetable({
    super.key,
    required this.token,
  });

  @override
  State<AdminTimetable> createState() => _AdminTimetableState();
}

class _AdminTimetableState extends State<AdminTimetable> {
  late Future<List<dynamic>> future;

  bool uploading = false;

  @override
  void initState() {
    super.initState();
    future = AdminApi.timetable(widget.token);
  }

  void reload() {
    setState(() {
      future = AdminApi.timetable(widget.token);
    });
  }

  Future<void> upload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['xlsx', 'xlsm', 'xls'],
  withData: true,
);

      if (result == null) {
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        _msg('Could not read the selected Excel file.');
        return;
      }

      setState(() {
        uploading = true;
      });

      final response = await AdminApi.uploadTimetable(
        widget.token,
        file.name,
        file.bytes!,
      );

      final created = response['created_count'] ?? 0;
      final skipped = response['skipped_count'] ?? 0;
      final errors = response['error_count'] ?? 0;

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Timetable Import Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Created entries: $created'),
                const SizedBox(height: 8),
                Text('Skipped entries: $skipped'),
                const SizedBox(height: 8),
                Text('Errors: $errors'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      reload();
    } catch (e) {
      if (!mounted) return;

      _msg(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  void _msg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: uploading ? null : reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Upload Excel',
            onPressed: uploading ? null : upload,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: uploading ? null : upload,
        icon: uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(
          uploading
              ? 'Importing...'
              : 'Upload Excel',
        ),
      ),

      body: FutureBuilder<List<dynamic>>(
        future: future,

        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error loading timetable:\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final rows = snapshot.data ?? [];

          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No timetable entries found.\n\n'
                  'Use "Upload Excel" to import the university timetable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },

            child: ListView.builder(
              padding: const EdgeInsets.only(
                bottom: 100,
                top: 10,
              ),

              itemCount: rows.length,

              itemBuilder: (context, index) {
                final item =
                    Map<String, dynamic>.from(rows[index]);

                final mode =
                    (item['class_mode'] ?? 'PHYSICAL')
                        .toString()
                        .toUpperCase();

                final physical =
                    mode == 'PHYSICAL';

                final courseCode =
                    item['course_code'] ?? '';

                final courseTitle =
                    item['course_title'] ?? '';

                final day =
                    item['day'] ?? '';

                final start =
                    item['start'] ?? '';

                final end =
                    item['end'] ?? '';

                final room =
                    item['room'] ?? 'Room TBA';

                final group =
                    item['group'] ?? '';

                final block =
                    item['block'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        physical
                            ? Icons.school
                            : Icons.wifi,
                      ),
                    ),

                    title: Text(
                      '$courseCode - $courseTitle',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Padding(
                      padding:
                          const EdgeInsets.only(top: 6),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            '$day • $start - $end',
                          ),

                          const SizedBox(height: 3),

                          Text(
                            physical
                                ? 'Room: $room'
                                : 'ONLINE',
                          ),

                          if (group
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 3,
                              ),
                              child: Text(
                                'Group: $group',
                              ),
                            ),

                          if (block
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top: 3,
                              ),
                              child: Text(
                                'Block: $block',
                              ),
                            ),
                        ],
                      ),
                    ),

                    trailing:
                        PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value != 'delete') {
                          return;
                        }

                        final id = item['id'];

                        if (id == null) {
                          _msg(
                            'This timetable entry has no ID.',
                          );
                          return;
                        }

                        try {
                          await AdminApi.deleteTimetable(
                            widget.token,
                            int.parse(id.toString()),
                          );

                          reload();

                          _msg(
                            'Timetable entry removed.',
                          );
                        } catch (e) {
                          _msg(
                            e.toString().replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          );
                        }
                      },

                      itemBuilder: (context) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Remove entry',
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
