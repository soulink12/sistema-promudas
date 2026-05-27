import 'package:flutter/material.dart';
// Ajuste o caminho abaixo conforme a sua estrutura de pastas
import 'features/vendas/screens/venda_screen.dart'; 

void main() {
  runApp(const MeuViveiroApp());
}

class MeuViveiroApp extends StatelessWidget {
  const MeuViveiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Promudas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green), 
        useMaterial3: true
      ),
      home: const TelaVenda(), // Agora a TelaVenda é a principal
    );
  }
}