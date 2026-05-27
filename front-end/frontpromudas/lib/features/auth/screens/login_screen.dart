import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// Importe a tela de clientes. Ajuste o caminho conforme necessário.
import '../../clientes/screens/clientes_screen.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://api2.viveiropromudas.com.br/api'));
  bool _carregando = false;

  Future<void> _fazerLogin() async {
    setState(() => _carregando = true);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': _emailController.text,
        'senha': _passController.text,
      });

      final String token = response.data['token'];

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TelaListaClientes(token: token)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro no login: Verificar usuário/senha')),
      );
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              const SizedBox(height: 30),
              _carregando 
                ? const CircularProgressIndicator() 
                : ElevatedButton(onPressed: _fazerLogin, child: const Text('Entrar')),
            ],
          ),
        ),
      ),
    );
  }
}