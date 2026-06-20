import 'package:flutter/material.dart';
import '../../src/rust/api/debug.dart';

class DatabaseInspectorPage extends StatefulWidget {
  const DatabaseInspectorPage({super.key});

  @override
  State<DatabaseInspectorPage> createState() => _DatabaseInspectorPageState();
}

class _DatabaseInspectorPageState extends State<DatabaseInspectorPage> {
  List<String> _tables = [];
  String? _selectedTable;
  DbQueryResult? _queryResult;
  final TextEditingController _sqlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      final tables = await listTables();
      setState(() {
        _tables = tables;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _executeQuery(String sql) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await executeDebugSql(sql: sql);
      setState(() {
        _queryResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onTableSelected(String table) {
    setState(() {
      _selectedTable = table;
      _sqlController.text = 'SELECT * FROM $table LIMIT 100';
    });
    _executeQuery(_sqlController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库审查 (Debug)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTables,
          ),
        ],
      ),
      body: Column(
        children: [
          // 表列表
          if (_tables.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final table = _tables[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text(table),
                      selected: _selectedTable == table,
                      onSelected: (_) => _onTableSelected(table),
                    ),
                  );
                },
              ),
            ),

          // SQL 输入框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _sqlController,
                    decoration: const InputDecoration(
                      hintText: '输入 SQL 语句...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _executeQuery(_sqlController.text),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),

          if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '错误: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),

          if (!_isLoading && _queryResult != null)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: _queryResult!.columns
                        .map((c) => DataColumn(label: Text(c)))
                        .toList(),
                    rows: _queryResult!.rows
                        .map((r) => DataRow(
                              cells: r
                                  .map((cell) => DataCell(Text(cell)))
                                  .toList(),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
