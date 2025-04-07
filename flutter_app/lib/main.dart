import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const CSVUploaderApp());
}

class CSVUploaderApp extends StatelessWidget {
  const CSVUploaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CSV Stats Analyzer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String message = '';
  int count = 0;
  double sum = 0;
  double avg = 0;
  bool isLoading = false;
  bool showChart = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> uploadCSV() async {
    setState(() {
      isLoading = true;
      showChart = false;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final uri = Uri.parse('http://192.168.115.179:8000/upload');

        final request = http.MultipartRequest('POST', uri);
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
        final response = await request.send();

        if (response.statusCode == 200) {
          setState(() {
            message = 'Fichier analysé avec succès';
          });
          await fetchStats();
        } else {
          setState(() {
            message = 'Erreur lors de l\'analyse du fichier';
          });
        }
      }
    } catch (e) {
      setState(() {
        message = 'Erreur: ${e.toString()}';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchStats() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.115.179:8000/stats'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          count = data['count'];
          sum = data['sum'];
          avg = data['avg'];
          showChart = true;
        });
        _animationController.forward(from: 0);
      } else {
        setState(() {
          message = 'Erreur lors de la récupération des statistiques';
        });
      }
    } catch (e) {
      setState(() {
        message = 'Erreur de connexion au serveur';
      });
    }
  }

  Widget _buildStatCard(String title, dynamic value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value is double ? value.toStringAsFixed(2) : value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedChart() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Statistiques',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (sum * 1.2).ceilToDouble(),
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Count'),
                                );
                              case 1:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Sum'),
                                );
                              case 2:
                                return const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('Avg'),
                                );
                              default:
                                return const Text('');
                            }
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (sum * 1.2 / 5).ceilToDouble(),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: count.toDouble(),
                            color: Colors.blue[400],
                            width: 30,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: sum,
                            color: Colors.green[400],
                            width: 30,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barsSpace: 4,
                        barRods: [
                          BarChartRodData(
                            toY: avg,
                            color: Colors.orange[400],
                            width: 30,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CSV Stats Analyzer"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: isLoading ? null : uploadCSV,
              icon:
                  isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                      : const Icon(Icons.upload_file),
              label: Text(
                isLoading ? 'Traitement...' : 'Choisir un fichier CSV',
              ),
            ),
            const SizedBox(height: 20),
            if (message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      message.contains('Erreur')
                          ? Colors.red[50]
                          : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color:
                        message.contains('Erreur')
                            ? Colors.red[800]
                            : Colors.green[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            if (count > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Count', count, Colors.blue[400]!),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Sum', sum, Colors.green[400]!),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard('Average', avg, Colors.orange[400]!),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (showChart) _buildAnimatedChart(),
            ],
          ],
        ),
      ),
    );
  }
}
