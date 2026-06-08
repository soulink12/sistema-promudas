class AuthService {
  static String? token;
  static Map<String, dynamic>? usuario;

  static void salvarSessao(String novoToken, Map<String, dynamic> novoUsuario) {
    token = novoToken;
    usuario = novoUsuario;
  }

  static void logout() {
    token = null;
    usuario = null;
  }
}
