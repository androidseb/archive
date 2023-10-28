// ignore_for_file: deprecated_member_use_from_same_package, avoid_print

import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:archive/src/io/file_buffer.dart';
import 'package:archive/src/io/input_file_stream.dart';
import 'package:archive/src/io/output_file_stream.dart';
import 'package:archive/src/io/ram_file_handle.dart';
import 'package:archive/src/io/zip_file_encoder.dart';
import 'package:test/test.dart';

/// Showcasing a bug in the web environment when manipulating large (>4GB) zip64 files:
/// Running the test with this command works:
/// flutter test test/tests/large_zip64_test.dart
/// But fails with this command:
/// flutter run -d chrome --web-port 8001 test/tests/large_zip64_test.dart
void main() {
  test(
    'Can create a 5GB zip file and read it back',
    () async {
      const int filesCount = 1000;
      const int filesContentLength = 5 * 1024 * 1024 + 147;

      final Uint8List filesContent = Uint8List(filesContentLength);
      for (int i = 0; i < filesContent.length; i++) {
        filesContent[i] = i;
      }
      final RamFileData outputRamFileData = RamFileData.outputBuffer();
      final ZipFileEncoder zipEncoder = ZipFileEncoder()
        ..createWithBuffer(
          OutputFileStream.toRamFile(
            RamFileHandle.fromRamFileData(outputRamFileData),
          ),
          level: ZipFileEncoder.STORE,
        );
      for (int i = 0; i < filesCount; i++) {
        zipEncoder.addArchiveFile(ArchiveFile('$i', filesContentLength, filesContent));
        print('Encoded file ${i + 1}/$filesCount');
      }
      zipEncoder.close();
      print('Closed output zip archive');
      expect(
        outputRamFileData.length >= filesContentLength * filesCount,
        true,
        reason: 'The output archive is not large enough to contain all the files',
      );
      print('Reading archive from RAM...');
      final Archive readArchive = ZipDecoder().decodeBuffer(
        InputFileStream.withFileBuffer(
          FileBuffer(
            RamFileHandle.fromRamFileData(outputRamFileData),
          ),
        ),
      );
      print('Checking read archive files count');
      expect(
        readArchive.files.length,
        filesCount,
        reason: 'Output zip has the wrong file count when read back',
      );
    },
  );
}
