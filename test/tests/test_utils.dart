library archive.test.test_utils;

import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:mirrors';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final String testDirPath = p.dirname(p.fromUri(currentMirrorSystem()
    .findLibrary(const Symbol('archive.test.test_utils'))
    .uri));

void compareBytes(List<int> a, List<int> b) {
  expect(a.length, equals(b.length));
  final len = a.length;
  for (var i = 0; i < len; ++i) {
    expect(a[i], equals(b[i]));
  }
}

const aTxt = '''this is a test
of the
zip archive
format.
this is a test
of the
zip archive
format.
this is a test
of the
zip archive
format.
''';

void listDir(List<io.File> files, io.Directory dir) {
  var fileOrDirs = dir.listSync(recursive: true);
  for (var f in fileOrDirs) {
    if (f is io.File) {
      // Ignore paxHeader files, which 7zip write out since it doesn't properly
      // handle POSIX tar files.
      if (f.path.contains('PaxHeader')) {
        continue;
      }
      files.add(f);
    }
  }
}

Uint8List _generateBaseBytes(int targetSize) {
  final math.Random seededRandom = math.Random(0);
  final Uint8List res = Uint8List(targetSize);
  for (int i = 0; i < targetSize; i++) {
    res[i] = seededRandom.nextInt(256);
  }
  return res;
}

Uint8List _getFileByte(Uint8List baseBytes, int fileIndex, int fileLength) {
  return baseBytes.sublist(fileIndex, fileIndex + fileLength);
}

Future<void> generateAndTestZipFile({
  required String outputZipFileRelativePath,
  required int zipEntryRawLength,
  required int zipEntriesCount,
  required int expectedZipFileMinimumSize,
}) async {
  final Uint8List baseBytes = _generateBaseBytes(zipEntryRawLength + zipEntriesCount);
  final outputZipFile = io.File(p.join(testDirPath, outputZipFileRelativePath));
  final ZipFileEncoder zipFileEncoder = ZipFileEncoder()
    ..create(
      outputZipFile.absolute.path,
      level: Deflate.NO_COMPRESSION,
    );
  io.stdout.writeln('Generating archive...\r');
  for (int i = 0; i < zipEntriesCount; i++) {
    final entryName = 'files/binary_file_$i';
    final Uint8List entryContent = _getFileByte(baseBytes, i, zipEntryRawLength);
    io.stdout.write('Generating archive... $i / $zipEntriesCount\r');
    zipFileEncoder.addArchiveFile(ArchiveFile(entryName, entryContent.length, entryContent));
  }
  io.stdout.writeln('Archive generated     ');
  zipFileEncoder.close();
  final outputFileLength = outputZipFile.lengthSync();
  expect(
    outputFileLength >= expectedZipFileMinimumSize,
    true,
    reason: 'The generated zip file is too small $outputFileLength < $expectedZipFileMinimumSize',
  );
  final archive = ZipDecoder().decodeBuffer(InputFileStream(outputZipFile.absolute.path));
  final files = archive.files;
  expect(files.length, zipEntriesCount, reason: 'Unexpected zip entries count');
  io.stdout.writeln('Checking archive...\r');
  for (int i = 0; i < files.length; i++) {
    io.stdout.write('Checking archive... $i / ${files.length}\r');
    final file = files[i];
    final String filename = file.name;
    final int fileIndex = int.parse(filename.split('_').last);
    final Uint8List expectedFileData = _getFileByte(baseBytes, fileIndex, zipEntryRawLength);
    final Uint8List actualFileData = file.content as Uint8List;
    compareBytes(actualFileData, expectedFileData);
  }
  io.stdout.writeln('Archive checked     ');
}
