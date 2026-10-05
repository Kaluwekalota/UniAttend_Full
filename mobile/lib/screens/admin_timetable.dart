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

  // ============================================================
  // UPLOAD TIMETABLE
  // ============================================================

  Future<void> upload() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'xlsx',
          'xlsm',
          'xls',
        ],
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _msg('Could not read the selected Excel file.');
        return;
      }

      if (!mounted) return;

      setState(() {
        uploading = true;
      });

      final response = await AdminApi.uploadTimetable(
        widget.token,
        file.name,
        bytes,
      );

      final created = response['created_count'] ?? 0;
      final skipped = response['skipped_count'] ?? 0;
      final errors = response['error_count'] ?? 0;

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Timetable Import Complete',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Created entries: $created',
                ),
                const SizedBox(height: 8),
                Text(
                  'Skipped entries: $skipped',
                ),
                const SizedBox(height: 8),
                Text(
                  'Errors: $errors',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
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

  // ============================================================
  // SET CLASSROOM LOCATION
  // ============================================================

  Future<void> setLocation(
    Map<String, dynamic> item,
  ) async {
    final id = item['id'];

    if (id == null) {
      _msg('This timetable entry has no ID.');
      return;
    }

    final latitudeController = TextEditingController(
      text: item['latitude']?.toString() ?? '',
    );

    final longitudeController = TextEditingController(
      text: item['longitude']?.toString() ?? '',
    );

    final radiusController = TextEditingController(
      text: item['allowed_radius']?.toString() ?? '50',
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Classroom Location',
          ),

          content: Form(
            key: formKey,

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item['course_code'] ?? ''} - '
                    '${item['course_title'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Room: ${item['room'] ?? 'TBA'}',
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // LATITUDE
                  // ------------------------------------------------

                  TextFormField(
                    controller: latitudeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '-12.9708',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.location_on,
                      ),
                    ),
                    validator: (value) {
                      final number =
                          double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (number == null) {
                        return 'Enter a valid latitude.';
                      }

                      if (number < -90 ||
                          number > 90) {
                        return 'Latitude must be between -90 and 90.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // ------------------------------------------------
                  // LONGITUDE
                  // ------------------------------------------------

                  TextFormField(
                    controller: longitudeController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: '28.6337',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.location_on,
                      ),
                    ),
                    validator: (value) {
                      final number =
                          double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (number == null) {
                        return 'Enter a valid longitude.';
                      }

                      if (number < -180 ||
                          number > 180) {
                        return 'Longitude must be between -180 and 180.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  // ------------------------------------------------
                  // RADIUS
                  // ------------------------------------------------

                  TextFormField(
                    controller: radiusController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Allowed Radius (metres)',
                      hintText: '50',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.radar,
                      ),
                    ),
                    validator: (value) {
                      final number =
                          double.tryParse(
                        value?.trim() ?? '',
                      );

                      if (number == null) {
                        return 'Enter a valid radius.';
                      }

                      if (number <= 0) {
                        return 'Radius must be greater than 0.';
                      }

                      if (number > 1000) {
                        return 'Radius cannot exceed 1000 metres.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'Students must be within this radius '
                    'of the classroom to mark attendance.',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final latitude =
                    double.parse(
                  latitudeController.text.trim(),
                );

                final longitude =
                    double.parse(
                  longitudeController.text.trim(),
                );

                final radius =
                    double.parse(
                  radiusController.text.trim(),
                );

                try {
                  await AdminApi.updateTimetableLocation(
                    widget.token,
                    int.parse(id.toString()),
                    latitude,
                    longitude,
                    radius,
                  );

                  if (context.mounted) {
                    Navigator.pop(
                      context,
                      true,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst(
                            'Exception: ',
                            '',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(
                Icons.save,
              ),
              label: const Text(
                'Save Location',
              ),
            ),
          ],
        );
      },
    );

    latitudeController.dispose();
    longitudeController.dispose();
    radiusController.dispose();

    if (result == true && mounted) {
      reload();

      _msg(
        'Classroom location saved successfully.',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _msg(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Timetable Management',
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed:
                uploading ? null : reload,
            icon: const Icon(
              Icons.refresh,
            ),
          ),

          IconButton(
            tooltip: 'Upload Excel',
            onPressed:
                uploading ? null : upload,
            icon: const Icon(
              Icons.upload_file,
            ),
          ),
        ],
      ),

      // ========================================================
      // FLOATING UPLOAD BUTTON
      // ========================================================

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            uploading ? null : upload,

        icon: uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.upload_file,
              ),

        label: Text(
          uploading
              ? 'Importing...'
              : 'Upload Excel',
        ),
      ),

      // ========================================================
      // TIMETABLE
      // ========================================================

      body: FutureBuilder<List<dynamic>>(
        future: future,

        builder: (
          context,
          snapshot,
        ) {
          // ----------------------------------------------------
          // LOADING
          // ----------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Text(
                  'Error loading timetable:\n\n'
                  '${snapshot.error}',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          final rows =
              snapshot.data ?? [];

          // ----------------------------------------------------
          // EMPTY
          // ----------------------------------------------------

          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding:
                    EdgeInsets.all(20),
                child: Text(
                  'No timetable entries found.\n\n'
                  'Use "Upload Excel" to import '
                  'the university timetable.',
                  textAlign:
                      TextAlign.center,
                ),
              ),
            );
          }

          // ----------------------------------------------------
          // TIMETABLE LIST
          // ----------------------------------------------------

          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await future;
            },

            child: ListView.builder(
              padding:
                  const EdgeInsets.only(
                bottom: 100,
                top: 10,
              ),

              itemCount: rows.length,

              itemBuilder:
                  (context, index) {
                final item =
                    Map<String, dynamic>.from(
                  rows[index],
                );

                final mode =
                    (item['class_mode'] ??
                            'PHYSICAL')
                        .toString()
                        .toUpperCase();

                final physical =
                    mode == 'PHYSICAL';

                final courseCode =
                    item['course_code'] ??
                        '';

                final courseTitle =
                    item['course_title'] ??
                        '';

                final day =
                    item['day'] ?? '';

                final start =
                    item['start'] ?? '';

                final end =
                    item['end'] ?? '';

                final room =
                    item['room'] ??
                        'Room TBA';

                final group =
                    item['group'] ?? '';

                final block =
                    item['block'] ?? '';

                final latitude =
                    item['latitude'];

                final longitude =
                    item['longitude'];

                final radius =
                    item['allowed_radius'];

                final locationConfigured =
                    latitude != null &&
                    longitude != null;

                // ------------------------------------------------
                // CARD
                // ------------------------------------------------

                return Card(
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),

                  child: ListTile(
                    // --------------------------------------------
                    // ICON
                    // --------------------------------------------

                    leading:
                        CircleAvatar(
                      child: Icon(
                        physical
                            ? Icons.school
                            : Icons.wifi,
                      ),
                    ),

                    // --------------------------------------------
                    // COURSE
                    // --------------------------------------------

                    title: Text(
                      '$courseCode - $courseTitle',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    // --------------------------------------------
                    // DETAILS
                    // --------------------------------------------

                    subtitle: Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 6,
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          Text(
                            '$day • '
                            '$start - $end',
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            physical
                                ? 'Room: $room'
                                : 'ONLINE',
                          ),

                          // --------------------------------------
                          // GROUP
                          // --------------------------------------

                          if (group
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 3,
                              ),
                              child: Text(
                                'Group: $group',
                              ),
                            ),

                          // --------------------------------------
                          // BLOCK
                          // --------------------------------------

                          if (block
                              .toString()
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 3,
                              ),
                              child: Text(
                                'Block: $block',
                              ),
                            ),

                          // --------------------------------------
                          // LOCATION STATUS
                          // --------------------------------------

                          if (physical)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 8,
                              ),

                              child: Row(
                                children: [
                                  Icon(
                                    locationConfigured
                                        ? Icons
                                            .location_on
                                        : Icons
                                            .location_off,
                                    size: 18,
                                  ),

                                  const SizedBox(
                                    width: 5,
                                  ),

                                  Expanded(
                                    child: Text(
                                      locationConfigured
                                          ? 'Location configured • '
                                            'Radius: '
                                            '${radius ?? 50} m'
                                          : 'Location not configured',
                                      style:
                                          TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize:
                                            12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --------------------------------------------
                    // MENU
                    // --------------------------------------------

                    trailing:
                        PopupMenuButton<String>(
                      onSelected:
                          (value) async {
                        // ----------------------------------------
                        // LOCATION
                        // ----------------------------------------

                        if (value ==
                            'location') {
                          await setLocation(
                            item,
                          );
                          return;
                        }

                        // ----------------------------------------
                        // DELETE
                        // ----------------------------------------

                        if (value ==
                            'delete') {
                          final id =
                              item['id'];

                          if (id == null) {
                            _msg(
                              'This timetable entry '
                              'has no ID.',
                            );
                            return;
                          }

                          try {
                            await AdminApi
                                .deleteTimetable(
                              widget.token,
                              int.parse(
                                id.toString(),
                              ),
                            );

                            reload();

                            _msg(
                              'Timetable entry removed.',
                            );
                          } catch (e) {
                            _msg(
                              e.toString()
                                  .replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        }
                      },

                      itemBuilder:
                          (context) {
                        return [
                          if (physical)
                            PopupMenuItem<String>(
                              value:
                                  'location',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .location_on,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Text(
                                    locationConfigured
                                        ? 'Edit Location'
                                        : 'Set Location',
                                  ),
                                ],
                              ),
                            ),

                          const PopupMenuItem<
                              String>(
                            value:
                                'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .delete_outline,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  'Remove entry',
                                ),
                              ],
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

