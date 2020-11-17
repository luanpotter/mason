// ignore_for_file: public_member_api_docs
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:checked_yaml/checked_yaml.dart';

import 'common.dart';
import 'manifest.dart';

/// {@template generator}
/// An abstract class which both defines a template generator and can generate a
/// user project based on this template.
/// {@endtemplate}
abstract class Generator implements Comparable<Generator> {
  /// {@macro generator}
  Generator(
    this.id,
    this.description,
  );

  final String id;
  final String description;

  final List<TemplateFile> files = [];

  /// Add a new template file.
  TemplateFile addTemplateFile(TemplateFile file) {
    files.add(file);
    return file;
  }

  Future generate(
    GeneratorTarget target, {
    Map<String, String> vars,
  }) {
    return Future.forEach(files, (TemplateFile file) {
      final resultFile = file.runSubstitution(vars ?? <String, String>{});
      final filePath = resultFile.path;
      return target.createFile(filePath, resultFile.content);
    });
  }

  @override
  int compareTo(Generator other) =>
      id.toLowerCase().compareTo(other.id.toLowerCase());

  @override
  String toString() => '[$id: $description]';
}

/// A target for a [Generator].
/// This class knows how to create files given a path and contents.
abstract class GeneratorTarget {
  /// Create a file at the given path with the given contents.
  Future createFile(String path, List<int> contents);
}

/// {@template template_file}
/// This class represents a file in a generator template.
/// The contents should be text and may contain mustache
/// variables that can be substituted (`__myVar__`).
/// {@endtemplate}
class TemplateFile {
  /// {@macro template_file}
  TemplateFile(this.path, this.content);

  /// The template file path.
  final String path;

  /// The template file content.
  final String content;

  FileContents runSubstitution(Map<String, String> parameters) {
    final newPath = path.render(parameters);
    final newContents = _createContent(parameters);

    return FileContents(newPath, newContents);
  }

  List<int> _createContent(Map<String, String> vars) {
    return utf8.encode(content.render(vars));
  }
}

/// {@template file_contents}
/// A representation of the contents for a specific file.
/// {@endtemplate}
class FileContents {
  /// {@macro file_contents}
  const FileContents(this.path, this.content);

  /// The file path.
  final String path;

  /// The contents of the file.
  final List<int> content;
}

/// A [MasonGenerator] which extends [Generator] and
/// exposes the ability to create a [Generator] from a
/// `yaml` file.
class MasonGenerator extends Generator {
  MasonGenerator._(
    String id,
    String description, {
    List<TemplateFile> files,
    this.vars = const <String>[],
  }) : super(id, description) {
    for (final file in files) {
      addTemplateFile(file);
    }
  }

  /// Factory which creates a [MasonGenerator] based on
  /// a configuration file:
  ///
  /// ```yaml
  /// name: greetings
  /// description: A Simple Greetings Template
  /// files:
  ///   - from: greetings.md
  ///     to: GREETINGS.md
  /// vars:
  ///   - name
  /// ```
  factory MasonGenerator.fromYaml(String path) {
    final file = File(path);
    final content = file.readAsStringSync();
    final manifest = checkedYamlDecode(
      content,
      (m) => Manifest.fromJson(m),
    );
    return MasonGenerator._(
      manifest.name,
      manifest.description,
      files: manifest.files.map((f) {
        return TemplateFile(
          f.to,
          File(p.join(file.parent.path, f.from)).readAsStringSync(),
        );
      }).toList(),
      vars: manifest.vars,
    );
  }

  /// Optional list of variables which will be used to populate
  /// the corresponding mustache variables within the template.
  final List<String> vars;
}
