import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/utils/future.dart';
import 'package:notes/utils/prompts.dart';

const _secureStorage = FlutterSecureStorage();
const _githubUsernameField = "github_username";
const _githubRepoField = "github_repo";
const _githubTokenField = "github_token";


class GithubRepo {
  GithubRepo({required this.repo, required this.username, required this.token});
  final String repo;
  final String username;
  final String token;

  String get authLink => 'https://$username:$token@github.com/$username/$repo.git';

  void writeToStorage() {
    _secureStorage.write(key: _githubRepoField, value: repo);
    _secureStorage.write(key: _githubUsernameField, value: username);
    _secureStorage.write(key: _githubTokenField, value: token);
  }

  static Future<GithubRepo?> fromStorage() async {
    final storage = await _secureStorage.readAll();

    final link = storage[_githubRepoField];
    final username = storage[_githubUsernameField];
    final token = storage[_githubTokenField];

    return (link == null || username == null || token == null) ? null : (
      GithubRepo(repo: link, username: username, token: token)
    );
  }
}


class ConfigureRepoMenu extends StatelessWidget {
  const ConfigureRepoMenu({super.key, required this.existing, required this.onFinish});
  final GithubRepo? existing;
  final Function(GithubRepo?) onFinish;

  @override
  Widget build(BuildContext context) {
    final repoCtl = TextEditingController(text: existing?.repo);
    final unameCtl = TextEditingController(text: existing?.username);
    final tokenCtl = TextEditingController(text: existing?.token);
    return AlertDialog(
      title: const Text('Enter GitHub Credentials'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: unameCtl,
            decoration: const InputDecoration(hintText: 'GitHub Username'),
          ),
          TextField(
            controller: repoCtl,
            decoration: const InputDecoration(hintText: 'GitHub Repo'),
          ),
          TextField(
            controller: tokenCtl,
            decoration: const InputDecoration(hintText: 'GitHub Token'),
            // obscureText: true,  // Hide the token for security
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (repoCtl.text.isNotEmpty && unameCtl.text.isNotEmpty && tokenCtl.text.isNotEmpty) {
              onFinish(GithubRepo(repo: repoCtl.text, username: unameCtl.text, token: tokenCtl.text));
            } else {
              onFinish(null);
            }
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}


Future<void> showGitSyncMenu(BuildContext context, NoteHandler handler) async {
  final newRepo = await showDialog(
    context: context,
    builder: (context) => GitSyncMenu(repo: handler.git, root: handler.fs.filesystemRepoPath()),
  );

  if (newRepo == null) return;
  handler.git = newRepo;
}

class GitSyncMenu extends StatefulWidget {
  const GitSyncMenu({super.key, required this.repo, required this.root});
  final GithubRepo? repo;
  final Directory root;

  @override
  State<GitSyncMenu> createState() => _GitSyncMenuState();
}

class _GitSyncMenuState extends State<GitSyncMenu> {
  late Widget Function(BuildContext) current = initialWidget;
  void setWidget(Widget newWidget) => setState(() => current = (_) => newWidget);

  void close(BuildContext context, {dynamic value}) => Navigator.of(context).pop(value);
  Widget waitThenPop(Future<void> future) => FutureWaiter(future: future, onFinish: close);


  Future<ProcessResult> _gitRunOrErr(List<String> args) async {
    print('Git: $args');
    final repo = widget.repo;
    if (repo == null) throw 'Repo is not initialized';

    final result = await Process.run(
      'git', args,
      workingDirectory: widget.root.path,
      // environment: {
      //   'GIT_ASKPASS': 'echo',
      //   'GIT_USERNAME': repo.username,
      //   'GIT_PASSWORD': repo.token,
      // },
    );

    if (result.exitCode != 0) throw 'Git Error: $args\n${result.stdout}${result.stderr}';
    return result;
  }

  String _gitCommitFormat() {
    final now = DateTime.now();
    return [
      [(now.year, 4), (now.month, 2), (now.day, 2)],
      [(now.hour, 2), (now.minute, 2), (now.second, 2)],
    ].map((s) => s.map((n) => n.$1.toString().padLeft(n.$2, '0')).join('-')).join(' ');
  }

  Future<void> _gitCommitIfNeeded() async {
    await _gitRunOrErr(['add', '-A']);
    final checkChanges = await _gitRunOrErr(['status', '--porcelain']);
    if (checkChanges.stdout.toString().isNotEmpty) {
      await _gitRunOrErr(['commit', '-m', _gitCommitFormat()]);
    }
  }

  Future<(int, int)> _gitCommitThenCompare() async {
    await _gitCommitIfNeeded();
    await _gitRunOrErr(['fetch']);
    final result = await _gitRunOrErr(['rev-list', '--left-right', 'master...origin/master', '--count']);
    final parts = result.stdout.toString().trim().split(RegExp(r'\s+')).map(int.parse).toList();
    return (parts[0], parts[1]);
  }


  Widget configureGithubRepoWidget(BuildContext context) {
    return ConfigureRepoMenu(existing: widget.repo, onFinish: (newRepo) async {
        close(context, value: newRepo);

        if (newRepo == null) return;
        newRepo.writeToStorage();

        try {
          await _gitRunOrErr(['remote', 'add', 'origin', newRepo.authLink]);
        } catch (e) {
          await _gitRunOrErr(['remote', 'set-url', 'origin', newRepo.authLink]);
        }
    });
  }

  Widget initialWidget(BuildContext context) {
    final editBtn = ('Edit Remote', () => setState(() => current = configureGithubRepoWidget));
    final repo = widget.repo;

    if (repo == null) {
      return configureGithubRepoWidget(context);
    } else if (!Directory.fromUri(widget.root.uri.resolve('.git')).existsSync()) {
      return PromptOptions(content: 'No git repo', options: [
          ('Clone from ${repo.username}/${repo.repo}', () {
              final files = widget.root.listSync();
              if (files.isEmpty) {
                setWidget(waitThenPop(_gitRunOrErr(['clone', repo.authLink, '.'])));
                return;
              }
              setWidget(PromptOptions(
                  options: [
                    ('Delete existing files', () => setWidget(waitThenPop(
                          Future.wait(files.map((f) => f.delete(recursive: true)))
                          .then((_) => _gitRunOrErr(['clone', repo.authLink, '.']))
                    ))),
                    ('Clone into existing files', () => setWidget(waitThenPop(
                          _gitRunOrErr(['clone', repo.authLink, '.']),
                    ))),
                  ],
              ));
          }),
          editBtn,
      ]);
    } else {
      return FutureWaiter(
        future: _gitCommitThenCompare(),
        onFail: (context, error) {
          return PromptOptions(
            title: 'Unable to fetch from repo ${repo.username}/${repo.repo}',
            content: error.toString(),
            options: [editBtn],
          );
        },
        onSuccess: (context, comparison) {
          final (local, remote) = comparison;

          void gitAndClose(List<String> args) { _gitRunOrErr(args); close(context); }
          void forcePullAndClose() => gitAndClose(['reset', '--hard', 'origin/master']);
          void forcePushAndClose() => gitAndClose(['push', '--force', 'origin', 'HEAD:master']);
          void forcePushTempAndClose() => gitAndClose(['push', '--force', 'origin', 'HEAD:local']);

          if (local > 0 && remote > 0) {
            return PromptOptions(
              title: 'Local (+$local) and remote (+$remote) conflict.',
              options: [
                ('Push to Temp Branch (Safe)', forcePushTempAndClose),
                ('Use Remote (Force Pull)', forcePullAndClose),
                ('Use Local (Force Push)', forcePushAndClose),
                editBtn,
              ],
            );
          } else if (local > 0) {
            return PromptOptions(
              title: 'Local (+$local) is ahead of Remote. Push?',
              options: [editBtn, ('Push', forcePushAndClose)],
            );
          } else if (remote > 0) {
            return PromptOptions(
              title: 'Remote (+$remote) is ahead of Local. Pull?',
              options: [editBtn, ('Pull', forcePushAndClose)],
            );
          } else {
            return PromptOptions(
              title: 'Local and Remote are in sync',
              options: [editBtn],
            );
          }
        },
      );
    }
  }


  @override
  Widget build(BuildContext context) => current(context);
}
