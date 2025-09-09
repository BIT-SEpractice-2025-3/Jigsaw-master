// lib/pages/match_history_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match_history.dart';
import '../services/friend_service.dart';

class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  final FriendService _friendService = FriendService();
  late Future<List<MatchHistory>> _matchHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _matchHistoryFuture = _friendService.getMatchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对战记录'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: FutureBuilder<List<MatchHistory>>(
          future: _matchHistoryFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('加载失败: ${snapshot.error}'),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('你还没有任何对战记录'));
            }

            final history = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final match = history[index];
                final isWin = match.result == '胜利';
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isWin ? Colors.green.shade100 : Colors.red.shade100,
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWin ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isWin ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                        color: isWin ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    title: Text(
                      'vs ${match.opponentUsername}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '难度: ${match.difficulty} - ${DateFormat('yyyy-MM-dd HH:mm').format(match.completedAt)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      match.result,
                      style: TextStyle(
                        color: isWin ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}