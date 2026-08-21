import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:math';
import 'package:snow_fall_animation/snow_fall_animation.dart';
import 'package:local_auth/local_auth.dart'; // 👈 Adicione lá nos imports

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<bool> appUsaBiometria =
    ValueNotifier(false); // 👈 A CHAVE DA BIOMETRIA!
// MEMÓRIA CACHE DAS CATEGORIAS PARA DEIXAR O APP NA VELOCIDADE DA LUZ
Map<String, Map<String, dynamic>> cacheCategoriasGeral = {};

String obterNomeMes(int mes) {
  const meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro'
  ];
  return meses[mes - 1];
}

double parseMoeda(String valor) {
  if (valor.isEmpty) return 0.0;
  valor = valor.replaceAll('R\$', '').trim();
  if (valor.contains(',') && valor.contains('.')) {
    valor = valor.replaceAll('.', '').replaceAll(',', '.');
  } else if (valor.contains(',')) {
    valor = valor.replaceAll(',', '.');
  }
  return double.tryParse(valor) ?? 0.0;
}

DateTime obterMesContabil() {
  DateTime hj = DateTime.now();
  // Sem frescura de esperar dias! Virou o mês, virou o app.
  return DateTime(hj.year, hj.month, 1);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAfxkBTSVglkIyLwvYYFY_pvQ5w5MGrTqU",
      authDomain: "financascasal-32f8b.firebaseapp.com",
      projectId: "financascasal-32f8b",
      storageBucket: "financascasal-32f8b.firebasestorage.app",
      messagingSenderId: "97129553247",
      appId: "1:97129553247:web:81b296c33c718895bf2aea",
    ),
  );

  await _injetarConfiguracoesIniciaisBanco();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark') ?? true;
  appThemeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  appTextScale.value = prefs.getDouble('textScale') ?? 1.0;
  appUsaBiometria.value = prefs.getBool('usaBiometria') ?? false;

  runApp(const MyApp());
}

Future<void> _injetarConfiguracoesIniciaisBanco() async {
  try {
    var dbUsuarios = FirebaseFirestore.instance.collection('usuarios');
    var docEduardo = await dbUsuarios.doc('Eduardo').get();
    if (!docEduardo.exists) {
      await dbUsuarios
          .doc('Eduardo')
          .set({'senha': 'ADMIN123', 'codigo': '711@2709'});
    }
    var docNaiub = await dbUsuarios.doc('Naiub').get();
    if (!docNaiub.exists) {
      await dbUsuarios
          .doc('Naiub')
          .set({'senha': 'ADMIN123', 'codigo': '713@2105'});
    }

    var dbCats = FirebaseFirestore.instance.collection('categorias');
    var catsGet = await dbCats.limit(1).get();
    if (catsGet.docs.isEmpty) {
      await dbCats.add({
        'nome': 'Mercado',
        'icone': Icons.shopping_cart.codePoint,
        'cor': Colors.green.toARGB32(),
        'ativo': true
      });
      await dbCats.add({
        'nome': 'Combustível',
        'icone': Icons.local_gas_station.codePoint,
        'cor': Colors.orange.toARGB32(),
        'ativo': true
      });
      await dbCats.add({
        'nome': 'Lazer',
        'icone': Icons.movie.codePoint,
        'cor': Colors.purple.toARGB32(),
        'ativo': true
      });
      await dbCats.add({
        'nome': 'Contas Fixas',
        'icone': Icons.home.codePoint,
        'cor': Colors.blue.toARGB32(),
        'ativo': true
      });
    }
    // 👇 CARREGA AS CATEGORIAS PARA A MEMÓRIA RAM DO CELULAR
    var catsGetCache = await dbCats.get();
    for (var doc in catsGetCache.docs) {
      cacheCategoriasGeral[doc.id] = doc.data();
    }
  } catch (e) {
    debugPrint("Erro Init: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, themeMode, _) {
          return ValueListenableBuilder<double>(
              valueListenable: appTextScale,
              builder: (context, textScale, _) {
                return MaterialApp(
                  title: 'DOUB Finanças',
                  debugShowCheckedModeBanner: false,
                  themeMode: ThemeMode.dark,
                  scrollBehavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.trackpad
                    },
                  ),
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('pt', 'BR'),
                  ],

                  // 👇 TEMA ESCURO PREMIUM (Adeus pântano!)
                  darkTheme: ThemeData(
                    colorScheme: ColorScheme.fromSeed(
                        // Trocamos o verde padrão por um Verde Mint/Neon super chique!
                        seedColor: const Color(0xFF00E676),
                        brightness: Brightness.dark,
                        surface: const Color(0xFF121212)),
                    scaffoldBackgroundColor: const Color(0xFF121212),
                    appBarTheme: const AppBarTheme(
                        backgroundColor: Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        elevation: 0),
                    // 👇 O MATA-PÂNTANO: Força o fundo dos Cards a serem puros, sem mistura de verde!
                    cardTheme: const CardThemeData(
                      color: Color(0xFF1E1E1E),
                      surfaceTintColor: Colors.transparent, // A mágica tá aqui!
                    ),
                    bottomNavigationBarTheme:
                        const BottomNavigationBarThemeData(
                            backgroundColor: Color(0xFF1A1A1A),
                            selectedItemColor: Color(
                                0xFF00E676), // Fica verde neon selecionado
                            unselectedItemColor: Colors.white54),
                  ),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(textScale)),
                      child: child!,
                    );
                  },
                  home: const TelaLogin(),
                );
              });
        });
  }
}

void abrirConfiguracoes(BuildContext context) {
  showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.settings, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
                child: Text('Configurações', overflow: TextOverflow.ellipsis))
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              ValueListenableBuilder<double>(
                  valueListenable: appTextScale,
                  builder: (context, scale, _) {
                    return DropdownButtonFormField<double>(
                      initialValue: scale,
                      decoration: const InputDecoration(
                          labelText: 'Tamanho da Fonte',
                          prefixIcon: Icon(Icons.format_size)),
                      items: const [
                        DropdownMenuItem(value: 0.8, child: Text('Pequeno')),
                        DropdownMenuItem(value: 1.0, child: Text('Normal')),
                        DropdownMenuItem(value: 1.2, child: Text('Gigante'))
                      ],
                      onChanged: (double? valor) async {
                        appTextScale.value = valor!;
                        final prefs = await SharedPreferences.getInstance();
                        prefs.setDouble('textScale', valor);
                      },
                    );
                  }),
              const SizedBox(height: 10),
              const Divider(),
              ValueListenableBuilder<bool>(
                valueListenable: appUsaBiometria,
                builder: (context, usaBio, _) {
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar Biometria (Digital)',
                        style: TextStyle(fontSize: 14)),

                    value: usaBio,
                    activeThumbColor:
                        Colors.green, // 👈 Já com a correção do Linter!
                    secondary:
                        const Icon(Icons.fingerprint, color: Colors.green),
                    onChanged: (bool valor) async {
                      appUsaBiometria.value = valor;
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('usaBiometria', valor);
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'))
          ],
        );
      });
}

// =======================================================
// INÍCIO DA TELA DE LOGIN ANIMADA DEFINITIVA 🎬
// =======================================================

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  // 🎬 VARIÁVEIS DA ANIMAÇÃO DE CINEMA
  bool _mostrarDoub = false;
  bool _mostrarFinancas = false;
  bool _moverParaCima = false;
  bool _mostrarRestoDaTela = false;

  @override
  void initState() {
    super.initState();
    _iniciarAnimacaoCinema();
  }

  void _iniciarAnimacaoCinema() async {
    // Cena 1: O "OUB" começa a deslizar para formar o DOUB
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _mostrarDoub = true);

    // Cena 2: ESPERA o DOUB terminar de formar completamente, e SÓ ENTÃO o Finanças desce!
    await Future.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _mostrarFinancas = true);

    // Cena 3: ESPERA o Finanças terminar de descer, e SÓ ENTÃO tudo vai pro topo!
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) setState(() => _moverParaCima = true);

    // Cena 4: Revela os botões de quem está acessando
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _mostrarRestoDaTela = true);
  }

// 👇 A FUNÇÃO QUE DECIDE: DIGITAL OU SENHA?
  void _entrarComBiometriaOuSenha(BuildContext context, String usuario) async {
    // 1. O usuário ativou nas configurações?
    if (appUsaBiometria.value) {
      final LocalAuthentication auth = LocalAuthentication();

      try {
        // 2. O aparelho suporta biometria? (No PC isso dá falso e ele pula pra senha)
        bool hasSupport = await auth.isDeviceSupported();
        bool canCheck = await auth.canCheckBiometrics;

        if (hasSupport && canCheck) {
          // 3. Puxa a tela preta pedindo a digital!
          bool autenticado = await auth.authenticate(
            localizedReason: 'Use sua digital para entrar como $usuario',
            options: const AuthenticationOptions(
              stickyAuth: true,
              biometricOnly:
                  false, // Permite usar o PIN do celular se a digital falhar
            ),
          );

          if (autenticado) {
            if (!context.mounted) return;
            // 4. Passou na digital! Entra no app direto, sem pedir senha do sistema!
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        TelaNavegacao(usuarioLogado: usuario)));
            return; // 👈 Mata a função aqui pra ele não abrir o dialog de senha
          }
        }
      } catch (e) {
        debugPrint("Biometria ignorada ou falhou: $e");
      }
    }

    // 5. SE DEU TUDO ERRADO, ABRE NO PC, OU A PESSOA CANCELOU A DIGITAL: Abre a senha normal!
    if (!context.mounted) return;
    _abrirDialogSenha(context, usuario);
  }

  // --- SUAS FUNÇÕES DE SENHA CONTINUAM AQUI ---
  void _abrirDialogSenha(BuildContext context, String usuario) {
    final TextEditingController senhaController = TextEditingController();
    bool senhaIncorreta = false;
    bool mostrarSenha = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          void tentarLogin() async {
            var doc = await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(usuario)
                .get();
            // ignore: use_build_context_synchronously
            if (!context.mounted) {
              return;
            } // 👈 Cinto de segurança! (O Linter vai amar isso)
            if (doc.exists && doc.data()!['senha'] == senhaController.text) {
              Navigator.pop(context);
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          TelaNavegacao(usuarioLogado: usuario)));
            } else {
              setStateDialog(() {
                senhaIncorreta = true;
              });
            }
          }

          void abrirRecuperacao() {
            Navigator.pop(context);
            _abrirDialogRecuperacao(context, usuario);
          }

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Olá, $usuario!', textAlign: TextAlign.center),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Digite sua senha de acesso:',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              TextField(
                  controller: senhaController,
                  obscureText: !mostrarSenha,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (valor) => tentarLogin(),
                  decoration: InputDecoration(
                      labelText: 'Senha',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                            mostrarSenha
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey),
                        onPressed: () {
                          setStateDialog(() {
                            mostrarSenha = !mostrarSenha;
                          });
                        },
                      ),
                      errorText: senhaIncorreta ? 'Senha incorreta!' : null)),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: abrirRecuperacao,
                  child: const Text('Esqueci ou Mudar Senha',
                      style: TextStyle(fontSize: 12, color: Colors.blue)))
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: tentarLogin,
                  child: const Text('Entrar',
                      style: TextStyle(color: Colors.white)))
            ],
          );
        });
      },
    );
  }

  void _abrirDialogRecuperacao(BuildContext context, String usuario) {
    final TextEditingController codigoController = TextEditingController();
    final TextEditingController novaSenhaController = TextEditingController();
    bool codigoIncorreto = false;

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            void salvarNovaSenha() async {
              var doc = await FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(usuario)
                  .get();
              if (doc.exists &&
                  doc.data()!['codigo'] == codigoController.text &&
                  novaSenhaController.text.isNotEmpty) {
                await doc.reference.update({'senha': novaSenhaController.text});
                // ignore: use_build_context_synchronously
                if (!context.mounted) {
                  return;
                } // 👈 Cinto de segurança! (O Linter vai amar isso)
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Senha alterada com sucesso!'),
                    backgroundColor: Colors.green));
              } else {
                setStateDialog(() {
                  codigoIncorreto = true;
                });
              }
            }

            return AlertDialog(
              title: const Text('Mudar Senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Digite seu código de segurança:',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextField(
                      controller: codigoController,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Código Secreto',
                          errorText:
                              codigoIncorreto ? 'Código inválido!' : null)),
                  const SizedBox(height: 15),
                  TextField(
                      controller: novaSenhaController,
                      decoration:
                          const InputDecoration(labelText: 'Criar Nova Senha')),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: salvarNovaSenha,
                    child: const Text('Salvar',
                        style: TextStyle(color: Colors.white)))
              ],
            );
          });
        });
  }

  // --- O PALCO DA ANIMAÇÃO (INTERFACE) ---
  // --- O PALCO DA ANIMAÇÃO (INTERFACE) ---
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color corFundo = isDark ? const Color(0xFF121212) : Colors.green.shade50;

    return Scaffold(
      backgroundColor: corFundo,
      body: Stack(
        children: [
          // ❄️ 2. A MÁGICA DA NEVE! (Fica atrás de tudo)
          if (isNatal())
            const Positioned.fill(
              child: IgnorePointer(
                // 👈 Impede que a neve "roube" seus cliques na tela!
                child: SnowFallAnimation(), // 👈 O efeito da neve!
              ),
            ),

          // 📱 3. O SEU CÓDIGO ORIGINAL VEM AQUI, POR CIMA DA NEVE!
          SingleChildScrollView(
            // 👇 Trava a altura para ocupar a tela inteira (descontando o rodapé)
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 80,
              child: Column(
                children: [
                  // 1. O MOTOR DA SUBIDA (O espaço invisível que puxa tudo para cima)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeInOut,
                    height: _moverParaCima
                        ? 80
                        : MediaQuery.of(context).size.height * 0.35,
                  ),

                  // 2. A DANÇA DOS NOMES (A prova de balas com Transform!)
                  SizedBox(
                    height: 120, // Altura do palco
                    child: Stack(
                      alignment: Alignment
                          .center, // <- Centraliza os dois no eixo perfeito
                      clipBehavior: Clip.none,
                      children: [
                        // --- A CAMADA DE TRÁS (Finanças) ---
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutBack,
                          transform: Matrix4.translationValues(
                              0, _mostrarFinancas ? 35.0 : 0.0, 0),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 800),
                            opacity: _mostrarFinancas ? 1.0 : 0.0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 30,
                                    height: 1.5,
                                    color: const Color(0xffffffff)),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    'FINANÇAS',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xffffffff),
                                      fontWeight: FontWeight.normal,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                Container(
                                    width: 30,
                                    height: 1.5,
                                    color: const Color(0xffffffff)),
                              ],
                            ),
                          ),
                        ),

                        // --- A CAMADA DA FRENTE (DOUB - O Escudo) ---
                        // --- A CAMADA DA FRENTE (DOUB - O Escudo) ---
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          // 👇 1. O STACK AGORA ABRAÇA A ROW INTEIRA
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 2. A PALAVRA (Desenhada primeiro, fica no fundo)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('D',
                                      style: TextStyle(
                                          fontFamily: 'TabPearl',
                                          fontSize: 35,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 1500),
                                    curve: Curves.easeOutQuart,
                                    width: _mostrarDoub ? 105.0 : 0.0,
                                    child: const ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.centerLeft,
                                        maxWidth: 105.0,
                                        minWidth: 105.0,
                                        child: Text('OUB',
                                            style: TextStyle(
                                                fontFamily: 'TabPearl',
                                                fontSize: 35,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 2),
                                            maxLines: 1,
                                            softWrap: false),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 👇 3. O CHAPÉU (Desenhado por último, fica por cima de tudo)
                              if (isNatal())
                                Positioned(
                                  top: -20, // Puxa pra cima da cabeça do D
                                  left:
                                      -25, // Joga ele certinho em cima do D (Ajuste se precisar!)
                                  child: Image.asset(
                                    'assets/imagens/chapeu_natal.png',
                                    width: 55,
                                    height: 55,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 👇 2. A PRIMEIRA MOLA: Empurra os avatares pro centro
                  const Spacer(),

                  // 3. AVATARES QUE APARECEM NO FINAL
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: _mostrarRestoDaTela ? 1.0 : 0.0,
                    child: Column(
                      children: [
                        // Retirei o espaço fixo gigante que tinha aqui!
                        const Text('Quem está acessando?',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 30),

                        // --- BOTOES DE AVATAR ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // --- EDUARDO ---
                            GestureDetector(
                                onTap: () => _entrarComBiometriaOuSenha(
                                    context, 'Eduardo'),
                                child: Column(children: [
                                  Icon(Icons.person_outline,
                                      size: 70,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  const SizedBox(height: 10),
                                  Text('Eduardo',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black))
                                ])),

                            const SizedBox(width: 40),

                            // --- NAIUB ---
                            GestureDetector(
                                onTap: () => _entrarComBiometriaOuSenha(
                                    context, 'Naiub'),
                                child: Column(children: [
                                  Icon(Icons.person_outline,
                                      size: 70,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87),
                                  const SizedBox(height: 10),
                                  Text('Naiub',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black))
                                ])),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 👇 3. A SEGUNDA MOLA: Preenche o espaço vazio até o rodapé
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),

      // 4. RODAPÉ
      bottomNavigationBar: AnimatedOpacity(
        duration: const Duration(milliseconds: 800),
        opacity: _mostrarRestoDaTela ? 1.0 : 0.0,
        // 👇 TIRE QUALQUER 'const' QUE ESTIVER ANTES DO Padding OU DO Text!
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Text(
            'Versão 2.5\n© ${DateTime.now().year} DOUB. Todos os direitos reservados.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14.5,
                color: Color(0xffcdcaca),
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// FIM DA TELA DE LOGIN ANIMADA DEFINITIVA 🎬
// =======================================================

void sairDoUsuario(BuildContext context) async {
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => const TelaLogin()));
}

class MenuLateral extends StatelessWidget {
  final String usuarioLogado;
  const MenuLateral({super.key, required this.usuarioLogado});

  void _abrirNews(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DOUB News 📰'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('novidades')
                  .orderBy('data', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma novidade por enquanto.',
                        style: TextStyle(color: Color(0xffe5dbdb))),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String titulo = data['titulo'] ?? 'Atualização';
                    String descricao = data['descricao'] ?? '';
                    String versao = data['versao'] ?? '';

                    return NewsCardItem(
                      titulo: titulo,
                      descricao: descricao,
                      versao: versao,
                    );
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar',
                style: TextStyle(
                    color: Color(0xffdadeda), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ⚙️ O Motor do Excel (Agora filtrando apenas o mês escolhido!)
  void _exportarParaExcel(BuildContext context, DateTime mesExportacao) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Desenhando planilha do mês...',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green));

    try {
      DateTime inicio = DateTime(mesExportacao.year, mesExportacao.month, 1);
      DateTime fim = DateTime(mesExportacao.year, mesExportacao.month + 1, 1);

      var query = await FirebaseFirestore.instance
          .collection('lancamentos')
          .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
          .where('data', isLessThan: Timestamp.fromDate(fim))
          .orderBy('data', descending: true)
          .get();

      Map<String, dynamic> mData = {
        "mes": mesExportacao.month,
        "ano": mesExportacao.year,
        "rendas": [],
        "parcelas": [],
        "saidas": [],
        "totRenda": 0.0,
        "totSaida": 0.0,
        "totPoupanca": 0.0
      };

      for (var doc in query.docs) {
        var d = doc.data();
        double val = (d['valor'] ?? 0.0).toDouble();
        String desc = (d['descricao'] ?? 'Sem nome').toString();
        String resp = (d['responsavel'] ?? 'N/A').toString();

        DateTime dt = (d['data'] as Timestamp).toDate();
        String dataContabil =
            "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";

        desc = desc
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        resp = resp
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');

        if (d['isCartao'] == true || d['isDepositoDireto'] == true) {
          continue;
        } else if (d['isPoupanca'] == true) {
          double vAbs = val < 0 ? val * -1 : val;
          mData['totPoupanca'] += vAbs;
          mData['saidas'].add({
            'data': dataContabil,
            'desc': "$desc (Poupanca)",
            'val': vAbs,
            'resp': resp
          });
        } else if (d['isParcelamento'] == true) {
          int pAt = d['parcelaAtual'] ?? 1;
          int pTot = d['totalParcelas'] ?? 1;
          double vAbs = val < 0 ? val * -1 : val;
          mData['totSaida'] += vAbs;
          mData['parcelas']
              .add({'desc': desc, 'val': vAbs, 'parc': "$pAt/$pTot"});
        } else {
          if (val >= 0) {
            mData['totRenda'] += val;
            mData['rendas'].add(
                {'data': dataContabil, 'desc': desc, 'val': val, 'resp': resp});
          } else {
            double vAbs = val * -1;
            mData['totSaida'] += vAbs;
            mData['saidas'].add({
              'data': dataContabil,
              'desc': desc,
              'val': vAbs,
              'resp': resp
            });
          }
        }
      }

      StringBuffer xml = StringBuffer();
      xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      xml.writeln('<?mso-application progid="Excel.Sheet"?>');
      xml.writeln(
          '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">');

      // ⚙️ O SEGREDO DO VISUAL: Declarando os Estilos de Bordas, Negrito e Alinhamento
      xml.writeln(' <Styles>');
      xml.writeln('  <Style ss:ID="sTitulo">');
      xml.writeln(
          '   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>');
      xml.writeln('   <Font ss:Size="16" ss:Bold="1"/>');
      xml.writeln('  </Style>');
      xml.writeln('  <Style ss:ID="sCabecalhoMaster">');
      xml.writeln(
          '   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>');
      xml.writeln('   <Font ss:Bold="1"/>');
      xml.writeln('   <Borders>');
      xml.writeln(
          '    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="2"/>');
      xml.writeln(
          '    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="2"/>');
      xml.writeln(
          '    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="2"/>');
      xml.writeln(
          '    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="2"/>');
      xml.writeln('   </Borders>');
      xml.writeln('  </Style>');
      xml.writeln('  <Style ss:ID="sCabecalho">');
      xml.writeln(
          '   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>');
      xml.writeln('   <Borders>');
      xml.writeln(
          '    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="2"/>');
      xml.writeln('   </Borders>');
      xml.writeln('  </Style>');
      xml.writeln('  <Style ss:ID="sCelula">');
      xml.writeln('   <Borders>');
      xml.writeln(
          '    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln(
          '    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>');
      xml.writeln('   </Borders>');
      xml.writeln('  </Style>');
      xml.writeln(' </Styles>');

      String nomeMes = obterNomeMes(mData['mes']);
      String sheetName = "$nomeMes ${mData['ano']}";

      xml.writeln(' <Worksheet ss:Name="$sheetName">');

      // Expandindo um pouco as colunas para a tabela ficar bonita ao abrir
      xml.writeln('  <Table ss:DefaultColumnWidth="80">');
      xml.writeln('   <Column ss:Index="2" ss:Width="120"/>');
      xml.writeln('   <Column ss:Index="6" ss:Width="120"/>');
      xml.writeln('   <Column ss:Index="11" ss:Width="120"/>');

      // ⚙️ LINHA 1: Título Centralizado e Mesclado de ponta a ponta
      xml.writeln('   <Row ss:Height="25">');
      xml.writeln(
          '    <Cell ss:Index="1" ss:MergeAcross="15" ss:StyleID="sTitulo"><Data ss:Type="String">$nomeMes</Data></Cell>');
      xml.writeln('   </Row>');

      // ⚙️ LINHA 2: Títulos das Tabelas com Bordas Grossas (Mesclando células via MergeAcross)
      xml.writeln('   <Row>');
      // Renda mescla 3 extras (total 4)
      xml.writeln(
          '    <Cell ss:Index="1" ss:MergeAcross="3" ss:StyleID="sCabecalhoMaster"><Data ss:Type="String">Renda</Data></Cell>');
      // Parcelamentos mescla 2 extras (total 3)
      xml.writeln(
          '    <Cell ss:Index="6" ss:MergeAcross="2" ss:StyleID="sCabecalhoMaster"><Data ss:Type="String">Parcelamentos</Data></Cell>');
      // Saida mescla 3 extras (total 4)
      xml.writeln(
          '    <Cell ss:Index="10" ss:MergeAcross="3" ss:StyleID="sCabecalhoMaster"><Data ss:Type="String">Saida</Data></Cell>');
      // total mescla 1 extra (total 2)
      xml.writeln(
          '    <Cell ss:Index="15" ss:MergeAcross="1" ss:StyleID="sCabecalhoMaster"><Data ss:Type="String">total</Data></Cell>');
      xml.writeln('   </Row>');

      // ⚙️ LINHA 3: Nomes das Colunas
      xml.writeln('   <Row>');
      xml.writeln(
          '    <Cell ss:Index="1" ss:StyleID="sCabecalho"><Data ss:Type="String">Data Contabil</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Descricao</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Valor</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Responsavel</Data></Cell>');

      xml.writeln(
          '    <Cell ss:Index="6" ss:StyleID="sCabecalho"><Data ss:Type="String">Descricao</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Valor</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">parcelas</Data></Cell>');

      xml.writeln(
          '    <Cell ss:Index="10" ss:StyleID="sCabecalho"><Data ss:Type="String">Data Contabil</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Descricao</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Valor</Data></Cell>');
      xml.writeln(
          '    <Cell ss:StyleID="sCabecalho"><Data ss:Type="String">Responsavel</Data></Cell>');
      xml.writeln('   </Row>');

      List rendas = mData['rendas'];
      List parcelas = mData['parcelas'];
      List saidas = mData['saidas'];

      int maxRows = rendas.length;
      if (parcelas.length > maxRows) maxRows = parcelas.length;
      if (saidas.length > maxRows) maxRows = saidas.length;
      if (maxRows < 6) maxRows = 6;

      // ⚙️ LINHAS DE DADOS: O laço de repetição com preenchimento fantasma para desenhar as bordas!
      for (int i = 0; i < maxRows; i++) {
        xml.writeln('   <Row>');

        // Injetando dados ou células vazias (para as bordinhas ficarem alinhadas) para Rendas
        if (i < rendas.length) {
          xml.writeln(
              '    <Cell ss:Index="1" ss:StyleID="sCelula"><Data ss:Type="String">${rendas[i]['data']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String">${rendas[i]['desc']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${rendas[i]['val']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String">${rendas[i]['resp']}</Data></Cell>');
        } else {
          xml.writeln(
              '    <Cell ss:Index="1" ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
        }

        // Parcelamentos
        if (i < parcelas.length) {
          xml.writeln(
              '    <Cell ss:Index="6" ss:StyleID="sCelula"><Data ss:Type="String">${parcelas[i]['desc']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${parcelas[i]['val']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String">${parcelas[i]['parc']}</Data></Cell>');
        } else {
          xml.writeln(
              '    <Cell ss:Index="6" ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
        }

        // Saidas
        if (i < saidas.length) {
          xml.writeln(
              '    <Cell ss:Index="10" ss:StyleID="sCelula"><Data ss:Type="String">${saidas[i]['data']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String">${saidas[i]['desc']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${saidas[i]['val']}</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String">${saidas[i]['resp']}</Data></Cell>');
        } else {
          xml.writeln(
              '    <Cell ss:Index="10" ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="String"></Data></Cell>');
        }

        // Quadro de Totais da Direita
        if (i == 0) {
          xml.writeln(
              '    <Cell ss:Index="15" ss:StyleID="sCelula"><Data ss:Type="String">Renda total</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${mData['totRenda']}</Data></Cell>');
        } else if (i == 1) {
          xml.writeln(
              '    <Cell ss:Index="15" ss:StyleID="sCelula"><Data ss:Type="String">Despesas total</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${mData['totSaida']}</Data></Cell>');
        } else if (i == 2) {
          xml.writeln(
              '    <Cell ss:Index="15" ss:StyleID="sCelula"><Data ss:Type="String">Poupança</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCelula"><Data ss:Type="Number">${mData['totPoupanca']}</Data></Cell>');
        } else if (i == 4) {
          // Repare que pula a linha 3 (index 3) de propósito para dar o espaço igual na sua imagem!
          xml.writeln(
              '    <Cell ss:Index="15" ss:StyleID="sCabecalhoMaster"><Data ss:Type="String">Sobra do mês</Data></Cell>');
          xml.writeln(
              '    <Cell ss:StyleID="sCabecalhoMaster"><Data ss:Type="Number">${mData['totRenda'] - mData['totSaida'] - mData['totPoupanca']}</Data></Cell>');
        }

        xml.writeln('   </Row>');
      }

      xml.writeln('  </Table>');
      xml.writeln(' </Worksheet>');
      xml.writeln('</Workbook>');

      final bytes = utf8.encode(xml.toString());
      final blob = html.Blob([bytes], 'application/vnd.ms-excel');
      final url = html.Url.createObjectUrlFromBlob(blob);

      String nomeArquivo = "DOUB_${nomeMes}_${mData['ano']}.xls";

      html.AnchorElement(href: url)
        ..setAttribute("download", nomeArquivo)
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao exportar: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red));
    }
  }

  // ⚙️ A Nova Janela de Seleção do Mês
  void _abrirDialogMesExportacao(BuildContext context) {
    DateTime mesSelecionado = DateTime.now(); // Inicia sempre no mês atual

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title:
                  const Text('Exportar Planilha', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_chart, size: 50, color: Colors.green),
                  const SizedBox(height: 10),
                  const Text('Escolha qual mês deseja baixar:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            size: 18, color: Colors.green),
                        onPressed: () => setStateDialog(() {
                          mesSelecionado = DateTime(
                              mesSelecionado.year, mesSelecionado.month - 1, 1);
                        }),
                      ),
                      Text(
                        '${obterNomeMes(mesSelecionado.month).toUpperCase()} ${mesSelecionado.year}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios,
                            size: 18, color: Colors.green),
                        onPressed: () => setStateDialog(() {
                          mesSelecionado = DateTime(
                              mesSelecionado.year, mesSelecionado.month + 1, 1);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar',
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(ctx); // Fecha a janelinha
                    _exportarParaExcel(
                        context, mesSelecionado); // Inicia o download
                  },
                  icon:
                      const Icon(Icons.download, color: Colors.white, size: 18),
                  label: const Text('Baixar Excel',
                      style: TextStyle(color: Colors.white)),
                )
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
              accountName: Text(usuarioLogado,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              accountEmail: const Text('Gestor Financeiro DOUB'),
              decoration: const BoxDecoration(color: Color(0xff3d3d3d))),
          ListTile(
              leading: const Icon(Icons.newspaper, color: Colors.blue),
              title: const Text('DOUB News'),
              onTap: () {
                Navigator.pop(context);
                _abrirNews(context);
              }),
          // ⚙️ O botão agora abre a nova janelinha!
          ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Exportar para Excel'),
              onTap: () {
                Navigator.pop(context);
                _abrirDialogMesExportacao(context);
              }),
          const Spacer(),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configurações'),
              onTap: () {
                Navigator.pop(context);
                abrirConfiguracoes(context);
              }),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                sairDoUsuario(context);
              }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// =======================================================
// SELETOR INTELIGENTE (Muda de Mês para Ano automaticamente) ⏳
// =======================================================
class SeletorMes extends StatelessWidget {
  final DateTime dataAtual;
  final Function(int) aoMudar;
  final bool travarFuturo;
  final bool isAnual; // 👈 NOVA CHAVE MÁGICA PARA A ABA ANUAL!

  const SeletorMes({
    super.key,
    required this.dataAtual,
    required this.aoMudar,
    this.travarFuturo = true,
    this.isAnual = false, // Por padrão é falso (Mostra o Mês normal)
  });

  @override
  Widget build(BuildContext context) {
    bool podeAvancar = true;

    if (travarFuturo) {
      DateTime hoje = DateTime.now();
      if (isAnual) {
        // Na aba Anual, a trava não deixa ir pro Ano que vem!
        podeAvancar = dataAtual.year < hoje.year;
      } else {
        // 👇 Na aba Mensal, a regra agora é exata: não passa do mês atual!
        DateTime mesMaximo = DateTime(hoje.year, hoje.month);

        podeAvancar = dataAtual.year < mesMaximo.year ||
            (dataAtual.year == mesMaximo.year &&
                dataAtual.month < mesMaximo.month);
      }
    }

    List<String> meses = [
      'JANEIRO',
      'FEVEREIRO',
      'MARÇO',
      'ABRIL',
      'MAIO',
      'JUNHO',
      'JULHO',
      'AGOSTO',
      'SETEMBRO',
      'OUTUBRO',
      'NOVEMBRO',
      'DEZEMBRO'
    ];

    // 👇 Se a aba for anual, mostra SÓ O ANO. Se não, mostra "MÊS ANO"
    String texto = isAnual
        ? "${dataAtual.year}"
        : "${meses[dataAtual.month - 1]} ${dataAtual.year}";

    // 👇 Se for Anual, a seta pula 12 meses de uma vez. Se for mensal, pula 1 mês.
    int pulo = isAnual ? 12 : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left,
                color: Color(0xFF00E676), size: 28),
            onPressed: () => aoMudar(-pulo),
          ),
          const SizedBox(width: 15),
          Text(texto,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                  letterSpacing: 1.2)),
          const SizedBox(width: 15),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color:
                    podeAvancar ? const Color(0xFF00E676) : Colors.transparent,
                size: 28),
            onPressed: podeAvancar ? () => aoMudar(pulo) : null,
          ),
        ],
      ),
    );
  }
}

void _gerenciarCategorias(BuildContext context) {
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Scaffold(
            appBar: AppBar(title: const Text('Categorias'), actions: [
              IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _novaCategoria(ctx))
            ]),
            body: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('categorias')
                    .where('ativo', isEqualTo: true)
                    .snapshots(),
                builder: (c, s) {
                  if (!s.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                      children: s.data!.docs.map((doc) {
                    var d = doc.data() as Map<String, dynamic>;
                    return ListTile(
                        leading: Icon(
                            IconData(d['icone'], fontFamily: 'MaterialIcons'),
                            color: Color(d['cor'])),
                        title: Text(d['nome']),
                        trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                doc.reference.update({'ativo': false})));
                  }).toList());
                }));
      });
}

void _novaCategoria(BuildContext context) {
  TextEditingController nomeCtrl = TextEditingController();
  Color corSel = Colors.blue;
  IconData iconeSel = Icons.category;
  List<IconData> iconesOp = [
    Icons.shopping_cart,
    Icons.fastfood,
    Icons.local_gas_station,
    Icons.pets,
    Icons.flight,
    Icons.home,
    Icons.movie,
    Icons.directions_car,
    Icons.health_and_safety
  ];
  List<Color> coresOp = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.brown
  ];
  showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setS) {
          return AlertDialog(
              title: const Text('Nova Categoria'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 5,
                    children: coresOp
                        .map((c) => GestureDetector(
                            onTap: () => setS(() => corSel = c),
                            child: CircleAvatar(
                                backgroundColor: c,
                                radius: 15,
                                child: corSel == c
                                    ? const Icon(Icons.check,
                                        size: 15, color: Colors.white)
                                    : null)))
                        .toList()),
                const SizedBox(height: 10),
                Wrap(
                    spacing: 5,
                    children: iconesOp
                        .map((i) => GestureDetector(
                            onTap: () => setS(() => iconeSel = i),
                            child: Icon(i,
                                color: iconeSel == i ? corSel : Colors.grey,
                                size: 30)))
                        .toList())
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () {
                      if (nomeCtrl.text.isNotEmpty) {
                        FirebaseFirestore.instance
                            .collection('categorias')
                            .add({
                          'nome': nomeCtrl.text,
                          'icone': iconeSel.codePoint,
                          'cor': corSel.toARGB32(),
                          'ativo': true
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Salvar'))
              ]);
        });
      });
}

class CategoriaSelector extends StatelessWidget {
  final List<String> selecionadas;
  final Function(List<String>) onChanged;
  const CategoriaSelector(
      {super.key, required this.selecionadas, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categorias')
            .where('ativo', isEqualTo: true)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox();
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: snap.data!.docs.map((doc) {
                var d = doc.data() as Map<String, dynamic>;
                bool isSel = selecionadas.contains(doc.id);
                return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                        label: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              IconData(d['icone'], fontFamily: 'MaterialIcons'),
                              size: 16,
                              color: isSel ? Colors.white : Color(d['cor'])),
                          const SizedBox(width: 5),
                          Text(d['nome'],
                              style: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : Colors.black)))
                        ]),
                        selected: isSel,
                        selectedColor: Color(d['cor']),
                        checkmarkColor: Colors.white,
                        onSelected: (b) {
                          List<String> l = List.from(selecionadas);
                          if (b) {
                            l.add(doc.id);
                          } else {
                            l.remove(doc.id);
                          }
                          onChanged(l);
                        }));
              }).toList(),
            ),
          );
        });
  }
}

class TelaNavegacao extends StatefulWidget {
  final String usuarioLogado;
  const TelaNavegacao({super.key, required this.usuarioLogado});
  @override
  State<TelaNavegacao> createState() => _TelaNavegacaoState();
}

class _TelaNavegacaoState extends State<TelaNavegacao> {
  int _indiceAtual = 0;
  DateTime _dataSelecionada = obterMesContabil();

  @override
  void initState() {
    super.initState();
    _realizarManutencaoMensal();

    // ⚙️ Diz para o app: "Assim que a tela carregar, verifique as novidades!"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarNovidades();
    });
  }

  // ⚙️ O MOTOR DO POP-UP DE NOTIFICAÇÃO
  void _verificarNovidades() async {
    try {
      // 1. Puxa APENAS a última novidade lançada no banco
      var query = await FirebaseFirestore.instance
          .collection('novidades')
          .orderBy('data', descending: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        var doc = query.docs.first;
        String idNovidade = doc.id;
        String versao = doc.data()['versao'] ?? '';

        // 2. Consulta a memória do celular para ver qual foi a última que ele leu
        final prefs = await SharedPreferences.getInstance();
        String ultimaVista = prefs.getString('ultimaNovidade') ?? '';

        // 3. Se o ID da novidade for diferente do que ele tem na memória, é coisa nova!
        if (ultimaVista != idNovidade) {
          if (mounted) {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Row(
                        children: [
                          Icon(Icons.notifications_active,
                              color: Colors.orange),
                          SizedBox(width: 10),
                          Text('Atualização!',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      content: Text(
                        'A versão $versao acabou de sair!\n\nPara saber todos os detalhes e o que mudou, entre no DOUB News.',
                        style: const TextStyle(fontSize: 15),
                      ),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          onPressed: () {
                            Navigator.pop(ctx);
                          },
                          child: const Text('Entendi!',
                              style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ));
          }
          // 4. Grava na memória para não mostrar esse mesmo aviso no próximo login
          await prefs.setString('ultimaNovidade', idNovidade);
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar novidades: $e');
    }
  }

  void _realizarManutencaoMensal() async {
    DateTime agora = DateTime.now();
    DateTime limitePassado = DateTime(agora.year - 1, agora.month, 1);
    DateTime limiteFuturo = DateTime(agora.year + 1, agora.month, 1);
    try {
      var batch = FirebaseFirestore.instance.batch();
      var antigos = await FirebaseFirestore.instance
          .collection('lancamentos')
          .where('data', isLessThan: Timestamp.fromDate(limitePassado))
          .get();
      for (var doc in antigos.docs) {
        var dados = doc.data();
        if (dados['isPoupanca'] != true) {
          batch.delete(doc.reference);
        }
      }
      var fixas = await FirebaseFirestore.instance
          .collection('lancamentos')
          .where('isContaFixa', isEqualTo: true)
          .get();
      Map<String, DocumentSnapshot> ultimaDeCadaGrupo = {};
      for (var doc in fixas.docs) {
        var dados = doc.data();
        String gId = dados['grupoId'] ?? '';
        if (gId.isNotEmpty) {
          if (!ultimaDeCadaGrupo.containsKey(gId)) {
            ultimaDeCadaGrupo[gId] = doc;
          } else {
            DateTime dtAtual = (dados['data'] as Timestamp).toDate();
            DateTime dtSalva =
                (ultimaDeCadaGrupo[gId]!.data() as Map)['data'].toDate();
            if (dtAtual.isAfter(dtSalva)) {
              ultimaDeCadaGrupo[gId] = doc;
            }
          }
        }
      }
      for (var doc in ultimaDeCadaGrupo.values) {
        var dados = doc.data() as Map<String, dynamic>;
        DateTime ultimaData = (dados['data'] as Timestamp).toDate();
        if (ultimaData.isBefore(limiteFuturo)) {
          int mesesFaltantes = limiteFuturo.month -
              ultimaData.month +
              12 * (limiteFuturo.year - ultimaData.year);
          for (int i = 1; i <= mesesFaltantes; i++) {
            var novaData = DateTime(ultimaData.year, ultimaData.month + i,
                ultimaData.day, ultimaData.hour, ultimaData.minute);
            var ref =
                FirebaseFirestore.instance.collection('lancamentos').doc();
            batch.set(ref, {
              'descricao': dados['descricao'],
              'valor': dados['valor'],
              'responsavel': dados['responsavel'],
              'data': Timestamp.fromDate(novaData),
              'isParcelamento': dados['isParcelamento'] ?? false,
              'isCartao': dados['isCartao'] ?? false,
              'isPoupanca': dados['isPoupanca'] ?? false,
              'poupancaConfirmada': false,
              'isContaFixa': true,
              'grupoId': dados['grupoId'],
              'categorias': dados['categorias'] ?? []
            });
          }
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Erro na manutenção: $e");
    }
  }

  void _mudarMes(int incremento) {
    setState(() {
      _dataSelecionada = DateTime(
          _dataSelecionada.year, _dataSelecionada.month + incremento, 1);
    });
  }

  void _mudarParaMesEspecifico(DateTime data) {
    setState(() {
      _dataSelecionada = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime hj = DateTime.now();
    String diaTopo =
        "${hj.day.toString().padLeft(2, '0')}/${hj.month.toString().padLeft(2, '0')}";

    // 👇 1. ATUALIZAMOS A LISTA DE TELAS
    final List<Widget> telas = [
      TelaVisaoGeralTripla(
          mesAno: _dataSelecionada,
          aoMudarMes: _mudarMes,
          aoMudarMesEspecifico: _mudarParaMesEspecifico),
      // A nova tela que agrupa o cartão:
      TelaCartao(
          mesAno: _dataSelecionada,
          aoMudarMes: _mudarMes,
          usuarioLogado: widget.usuarioLogado),
      // A nova tela da Pizza:
      const TelaEstatisticas(),
      TelaPoupanca(
          mesAno: _dataSelecionada,
          aoMudarMes: _mudarMes,
          usuarioLogado: widget.usuarioLogado),
    ];

    return Scaffold(
      drawer: MenuLateral(usuarioLogado: widget.usuarioLogado),
      appBar: AppBar(
        // 👇 2. ATUALIZAMOS OS TÍTULOS DO TOPO
        title: Text(['', '', '', ''][_indiceAtual]),
        centerTitle: true,
        leadingWidth: 80,
        leading: Builder(
            builder: (ctx) => InkWell(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: const Center(
                    child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('DOUB',
                      style: TextStyle(
                          fontFamily: 'TabPearl',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white)),
                )))),
        actions: [
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(diaTopo,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70))))
        ],
      ),
      body: telas[_indiceAtual],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false, // 👈 ADICIONE ISSO: Esconde o texto verde
        showUnselectedLabels:
            false, // 👈 ADICIONE ISSO: Esconde os textos cinzas
        currentIndex: _indiceAtual,
        onTap: (indice) {
          setState(() {
            _indiceAtual = indice;

            // 👇 O CINTO DE SEGURANÇA TEMPORAL!
            if (indice != 1) {
              DateTime hoje = DateTime.now();
              // Agora a trava é cravada no mês e ano exatos de hoje
              DateTime mesMaximo = DateTime(hoje.year, hoje.month);

              if (_dataSelecionada.year > mesMaximo.year ||
                  (_dataSelecionada.year == mesMaximo.year &&
                      _dataSelecionada.month > mesMaximo.month)) {
                _dataSelecionada = mesMaximo;
              }
            }
          });
        },
        // 👇 3. ATUALIZAMOS OS BOTÕES E ÍCONES DE BAIXO
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Resumo'),
          BottomNavigationBarItem(
              icon: Icon(Icons.credit_card), label: 'Cartão'),
          BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart), label: 'Estatísticas'),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Poupança')
        ],
      ),
    );
  }
}

// =======================================================
// TELA RESUMO (AGORA LIMPA, SÓ COM OS CARDS DO MÊS)
// =======================================================
class TelaVisaoGeralTripla extends StatelessWidget {
  final DateTime mesAno;
  final Function(int) aoMudarMes;
  final Function(DateTime) aoMudarMesEspecifico;

  const TelaVisaoGeralTripla({
    super.key,
    required this.mesAno,
    required this.aoMudarMes,
    required this.aoMudarMesEspecifico,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SeletorMes(dataAtual: mesAno, aoMudar: aoMudarMes),
        Expanded(
            child: _TabMensal(
                mesAno: mesAno)), // Mostra o resumo direto, sem abas!
      ],
    );
  }
}

class _TabMensal extends StatelessWidget {
  final DateTime mesAno;
  const _TabMensal({required this.mesAno});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime inicio = DateTime(mesAno.year, mesAno.month, 1);
    DateTime fim = DateTime(mesAno.year, mesAno.month + 1, 1);

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lancamentos')
            .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('data', isLessThan: Timestamp.fromDate(fim))
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          double renda = 0, despesa = 0, poup = 0;

          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>;
            double v = (d['valor'] ?? 0.0).toDouble();

            if (d['isDepositoDireto'] == true) continue;

            if (v >= 0 &&
                d['isCartao'] != true &&
                d['isParcelamento'] != true &&
                d['isPoupanca'] != true) {
              renda += v;
            } else {
              double abs = v < 0 ? v * -1 : v;
              if (d['isPoupanca'] == true) {
                poup += abs;
              } else {
                despesa += abs;
              }
            }
          }

          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Renda Total',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            Text(
                                'R\$ ${renda.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))
                          ]),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Despesas Totais',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            Text(
                                'R\$ ${despesa.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))
                          ]),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Destinado à Poupança',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            Text(
                                'R\$ ${poup.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))
                          ]),
                      const Divider(height: 25, thickness: 1.5),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Sobra do Mês',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade900
                                        : Colors.lightBlue,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                    'R\$ ${(renda - despesa - poup).toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)))
                          ])
                    ]))),
            const SizedBox(height: 20),
            // 👇 BOTÃO ESTILO NUBANK (Fundo escuro com bordinha sutil)
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF1A1A1A), // Fundo escuro e limpo
                  foregroundColor:
                      const Color(0xffcbc4c4), // Letra e ícone brancos
                  elevation: 0, // Tira a sombra pra ficar moderno
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(
                      color: Colors.white12), // Bordinha cinza luxuosa
                ),
                icon: const Icon(Icons.settings_applications, size: 20),
                label: const Text('Gerenciar Categorias',
                    style: TextStyle(fontWeight: FontWeight.normal)),
                onPressed: () => _gerenciarCategorias(context))
          ]);
        });
  }
}

// =======================================================
// TELA ANUAL (BOMBA ATÔMICA: GRADIENTE SÓLIDO PERFEITO) 📊📅
// =======================================================
// =======================================================
// TELA ANUAL (MACRO-VISÃO: 3 CORES COM DETALHES CLICÁVEIS) 📊📅
// =======================================================
class _TabAnual extends StatelessWidget {
  final int ano;

  const _TabAnual({super.key, required this.ano});

  // 👇 A janelinha que sobe quando aperta em "Outros Gastos"
  void _mostrarDetalhesFatia(BuildContext ctx, Map<String, dynamic> fatia) {
    Map<String, double> detalhes = fatia['detalhes'] ?? {};
    List<MapEntry<String, double>> listaDetalhes = detalhes.entries.toList();
    listaDetalhes.sort((a, b) =>
        b.value.compareTo(a.value)); // Ordena do maior gasto pro menor

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          color: fatia['cor'], shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Flexible(
                      child: Text('Resumo de ${fatia['nome']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(height: 25),
              if (listaDetalhes.isEmpty)
                const Text('Nenhum detalhe encontrado.',
                    style: TextStyle(color: Colors.grey))
              else
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: listaDetalhes.length,
                      itemBuilder: (c, i) {
                        var item = listaDetalhes[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(item.key,
                              style: const TextStyle(fontSize: 15)),
                          trailing: Text(
                              'R\$ ${item.value.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                  color: fatia['cor'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        );
                      }),
                )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime inicioAno = DateTime(ano, 1, 1);
    DateTime fimAno = DateTime(ano + 1, 1, 1);

    // 👇 RETORNA O STREAMBUILDER DIRETO (É isso que estava causando o erro de Null!)
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lancamentos')
            .where('data',
                isGreaterThanOrEqualTo: Timestamp.fromDate(inicioAno))
            .where('data', isLessThan: Timestamp.fromDate(fimAno))
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          DateTime hoje = DateTime.now();
          int mesLimite = 12;

          if (ano == hoje.year) {
            mesLimite = hoje.day >= 5 ? hoje.month : hoje.month - 1;
          } else if (ano > hoje.year) {
            mesLimite = 0;
          }

          Map<String, Map<String, dynamic>> totaisCategorias = {};
          Map<int, Map<String, double>> mesesGrafico = {};

          for (int i = 1; i <= 12; i++) {
            mesesGrafico[i] = {};
          }

          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>;
            DateTime dataLanc = (d['data'] as Timestamp).toDate();
            int mes = dataLanc.month;

            if (mes > mesLimite) continue;

            double v = (d['valor'] ?? 0.0).toDouble();

            if (d['isDepositoDireto'] == true) continue;
            if (v >= 0 &&
                d['isCartao'] != true &&
                d['isParcelamento'] != true &&
                d['isPoupanca'] != true) continue;

            double abs = v < 0 ? v * -1 : v;

            String nomeMacro = '';
            Color corMacro = Colors.grey;
            String nomeDetalhe = '';

            if (d['isPoupanca'] == true) {
              nomeMacro = 'Poupança';
              corMacro = Colors.blue;
              nomeDetalhe = 'Depósitos na Poupança';
            } else if (d['isParcelamento'] == true || d['isCartao'] == true) {
              nomeMacro = 'Parcelamentos';
              corMacro = Colors.purple;
              nomeDetalhe = 'Faturas e Cotas';
            } else {
              nomeMacro = 'Outros Gastos';
              corMacro = const Color(0xFFFF9800);
              var cats = d['categorias'] ?? [];
              String idCat = cats.isNotEmpty ? cats[0].toString() : '';

              // 👇 Usando a memória RAM (cacheCategoriasGeral) ao invés do Firebase!
              var catInfo = cacheCategoriasGeral[idCat];
              nomeDetalhe =
                  catInfo != null ? (catInfo['nome'] ?? 'Outros') : 'Outros';
            }

            var catData = totaisCategorias[nomeMacro] ??
                {
                  'valor': 0.0,
                  'cor': corMacro,
                  'nome': nomeMacro,
                  'detalhes': <String, double>{}
                };

            catData['valor'] += abs;
            Map<String, double> detalhes = catData['detalhes'];
            detalhes[nomeDetalhe] = (detalhes[nomeDetalhe] ?? 0.0) + abs;

            totaisCategorias[nomeMacro] = catData;
            mesesGrafico[mes]![nomeMacro] =
                (mesesGrafico[mes]![nomeMacro] ?? 0.0) + abs;
          }

          List<Map<String, dynamic>> listaCategorias =
              totaisCategorias.values.toList();
          listaCategorias.sort((a, b) => b['valor'].compareTo(a['valor']));

          double maxMesTotal = 0;
          for (int i = 1; i <= 12; i++) {
            double t = mesesGrafico[i]!.values.fold(0.0, (a, b) => a + b);
            if (t > maxMesTotal) maxMesTotal = t;
          }

          List<String> mesesAbrev = [
            'Jan',
            'Fev',
            'Mar',
            'Abr',
            'Mai',
            'Jun',
            'Jul',
            'Ago',
            'Set',
            'Out',
            'Nov',
            'Dez'
          ];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            children: [
              const SizedBox(height: 30),
              SizedBox(
                height: 240,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(12, (index) {
                    int mes = index + 1;
                    double totalMes =
                        mesesGrafico[mes]!.values.fold(0.0, (a, b) => a + b);
                    double maxBarHeight = 180.0;

                    Widget barraFinal;

                    if (totalMes == 0 || maxMesTotal == 0) {
                      barraFinal = Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                              color: Colors.white12, shape: BoxShape.circle));
                    } else {
                      double alturaBarra =
                          maxBarHeight * (totalMes / maxMesTotal);

                      var catsNoMes = mesesGrafico[mes]!.keys.toList();
                      catsNoMes.sort((a, b) => mesesGrafico[mes]![b]!
                          .compareTo(mesesGrafico[mes]![a]!));

                      List<Color> coresGradiente = [];
                      List<double> paradasGradiente = [];
                      double alturaAcumulada = 0;

                      for (var c in catsNoMes) {
                        double valor = mesesGrafico[mes]![c]!;
                        if (valor <= 0) continue;

                        double inicio =
                            (alturaAcumulada / totalMes).clamp(0.0, 1.0);
                        alturaAcumulada += valor;
                        double fim =
                            (alturaAcumulada / totalMes).clamp(0.0, 1.0);

                        Color corCat = totaisCategorias[c]!['cor'];

                        coresGradiente.add(corCat);
                        paradasGradiente.add(inicio);
                        coresGradiente.add(corCat);
                        paradasGradiente.add(fim);
                      }

                      barraFinal = Container(
                        width: 16,
                        height: maxBarHeight,
                        alignment: Alignment.bottomCenter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 16,
                            height: alturaBarra,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: coresGradiente,
                                stops: paradasGradiente,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        barraFinal,
                        const SizedBox(height: 12),
                        Text(mesesAbrev[index],
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 35),
              const SizedBox(height: 5),
              const Divider(color: Colors.white10),
              const SizedBox(height: 5),
              ...listaCategorias.map((f) {
                return InkWell(
                  onTap: () => _mostrarDetalhesFatia(context, f),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                                color: f['cor'],
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 16),
                        Text(f['nome'],
                            style: const TextStyle(
                                fontSize: 15, color: Colors.white70)),
                        const Spacer(),
                        Text(
                            'R\$ ${f['valor'].toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        });
  }
}

class TelaLancamentos extends StatelessWidget {
  final DateTime mesAno;
  final Function(int) aoMudarMes;
  final String usuarioLogado;

  const TelaLancamentos(
      {super.key,
      required this.mesAno,
      required this.aoMudarMes,
      required this.usuarioLogado});

  void _abrirFormulario(BuildContext context) {
    final TextEditingController descricaoController = TextEditingController();
    final TextEditingController valorController = TextEditingController();
    final TextEditingController dataRealController = TextEditingController(
        text:
            "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}");
    bool isDespesa = true, isRecorrente = false, isPoupanca = false;
    List<String> catsSel = [];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateBottomSheet) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person,
                          color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 5),
                      Text('Lançando como: $usuarioLogado',
                          style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold))
                    ]),
                    const SizedBox(height: 10),
                    Text('Conta de ${obterNomeMes(mesAno.month)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ChoiceChip(
                          label: const Text('Despesa (-)'),
                          selectedColor: Colors.red,
                          labelStyle: TextStyle(
                              color: isDespesa
                                  ? Colors.white
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.black)),
                          selected: isDespesa,
                          onSelected: (val) {
                            setStateBottomSheet(() {
                              isDespesa = true;
                            });
                          }),
                      const SizedBox(width: 10),
                      ChoiceChip(
                          label: const Text('Renda (+)'),
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                              color: !isDespesa
                                  ? Colors.white
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white70
                                      : Colors.black)),
                          selected: !isDespesa,
                          onSelected: (val) {
                            setStateBottomSheet(() {
                              isDespesa = false;
                              isPoupanca = false;
                              descricaoController.clear();
                            });
                          })
                    ]),
                    const SizedBox(height: 15),
                    TextField(
                        controller: descricaoController,
                        enabled: !isPoupanca,
                        decoration: const InputDecoration(
                            labelText: 'Descrição',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit))),
                    const SizedBox(height: 15),
                    TextField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money))),
                    const SizedBox(height: 15),
                    TextField(
                        controller: dataRealController,
                        readOnly: true,
                        onTap: () async {
                          DateTime dataInicial = DateTime.now();
                          try {
                            if (dataRealController.text.isNotEmpty) {
                              List<String> parts =
                                  dataRealController.text.split('/');
                              dataInicial = DateTime(int.parse(parts[2]),
                                  int.parse(parts[1]), int.parse(parts[0]));
                            }
                          } catch (e) {
                            debugPrint("Erro: $e");
                          }

                          DateTime? dataSelecionada = await showDatePicker(
                            context: context,
                            initialDate: dataInicial,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );

                          if (dataSelecionada != null) {
                            setStateBottomSheet(() {
                              dataRealController.text =
                                  "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}/${dataSelecionada.year}";
                            });
                          }
                        },
                        decoration: const InputDecoration(
                            labelText: 'Data Real do Acontecimento',
                            helperText: 'Toque para escolher a data.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today,
                                color: Colors.green))),
                    if (isDespesa)
                      CategoriaSelector(
                          selecionadas: catsSel,
                          onChanged: (l) =>
                              setStateBottomSheet(() => catsSel = l)),
                    if (isDespesa)
                      SwitchListTile(
                          title: const Text('Destinar à Poupança?',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold)),
                          subtitle:
                              const Text('Isso aparecerá na Aba do Cofrinho'),
                          value: isPoupanca,
                          activeThumbColor: Colors.blue,
                          secondary:
                              const Icon(Icons.savings, color: Colors.blue),
                          onChanged: (bool valor) {
                            setStateBottomSheet(() {
                              isPoupanca = valor;
                              if (isPoupanca) {
                                descricaoController.text = 'Poupança';
                              } else {
                                descricaoController.clear();
                              }
                            });
                          }),
                    SwitchListTile(
                        title: const Text('Conta Fixa?'),
                        subtitle: const Text('Repete automaticamente'),
                        value: isRecorrente,
                        activeThumbColor: Colors.green,
                        onChanged: (bool valor) {
                          setStateBottomSheet(() {
                            isRecorrente = valor;
                          });
                        }),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: isPoupanca
                                    ? Colors.blue
                                    : (isDespesa ? Colors.red : Colors.green)),
                            onPressed: () {
                              if (descricaoController.text.isNotEmpty &&
                                  valorController.text.isNotEmpty) {
                                double vDigitado =
                                    parseMoeda(valorController.text);
                                if (isDespesa && vDigitado > 0) {
                                  vDigitado = vDigitado * -1;
                                } else if (!isDespesa && vDigitado < 0) {
                                  vDigitado = vDigitado * -1;
                                }
                                DateTime agora = DateTime.now();
                                int vezes = isRecorrente ? 12 : 1;
                                String? gId = isRecorrente
                                    ? agora.millisecondsSinceEpoch.toString()
                                    : null;
                                for (int i = 0; i < vezes; i++) {
                                  FirebaseFirestore.instance
                                      .collection('lancamentos')
                                      .add({
                                        'descricao': descricaoController.text,
                                        'valor': vDigitado,
                                        'responsavel': usuarioLogado,
                                        'dataRealString':
                                            dataRealController.text,
                                        'data': Timestamp.fromDate(DateTime(
                                            mesAno.year,
                                            mesAno.month + i,
                                            agora.day,
                                            agora.hour,
                                            agora.minute,
                                            agora.second,
                                            agora.millisecond)),
                                        'isCartao': false,
                                        'isParcelamento': false,
                                        'isPoupanca': isPoupanca,
                                        'poupancaConfirmada': false,
                                        'isContaFixa': isRecorrente,
                                        'categorias': catsSel
                                      }..addAll(
                                          gId != null ? {'grupoId': gId} : {}));
                                }
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Preencha a descrição e o valor!',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.red));
                              }
                            },
                            child: Text(
                                isPoupanca
                                    ? 'Salvar na Poupança'
                                    : 'Salvar Conta',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white)))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          });
        });
  }

  void _abrirFormularioEdicao(BuildContext context, DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;
    final double valorAtual = (dados['valor'] ?? 0.0).toDouble();
    final temGrupo = dados['grupoId'] != null;

    final TextEditingController descricaoController =
        TextEditingController(text: dados['descricao']);
    final TextEditingController valorController = TextEditingController(
        text: (valorAtual < 0 ? valorAtual * -1 : valorAtual)
            .toStringAsFixed(2)
            .replaceAll('.', ','));
    final TextEditingController dataRealController = TextEditingController(
        text: dados['dataRealString'] ??
            "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}");
    bool isDespesa = valorAtual < 0;
    bool isPoupanca = dados['isPoupanca'] ?? false;
    String responsavelOriginal = dados['responsavel'] ?? usuarioLogado;
    String descricaoAntiga = descricaoController.text;
    List<String> catsSel = List<String>.from(dados['categorias'] ?? []);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setStateBottomSheet) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Editar Conta',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ChoiceChip(
                          label: const Text('Despesa (-)'),
                          selectedColor: Colors.red,
                          labelStyle: TextStyle(
                              color: isDespesa ? Colors.white : Colors.black),
                          selected: isDespesa,
                          onSelected: (val) {
                            setStateBottomSheet(() {
                              isDespesa = true;
                            });
                          }),
                      const SizedBox(width: 10),
                      ChoiceChip(
                          label: const Text('Renda (+)'),
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                              color: !isDespesa ? Colors.white : Colors.black),
                          selected: !isDespesa,
                          onSelected: (val) {
                            setStateBottomSheet(() {
                              isDespesa = false;
                              isPoupanca = false;
                            });
                          })
                    ]),
                    const SizedBox(height: 15),
                    TextField(
                        controller:
                            TextEditingController(text: responsavelOriginal),
                        enabled: false,
                        decoration: const InputDecoration(
                            labelText: 'Dono da Conta',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person))),
                    const SizedBox(height: 15),
                    TextField(
                        controller: descricaoController,
                        enabled: !isPoupanca,
                        decoration: const InputDecoration(
                            labelText: 'Descrição',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.edit))),
                    const SizedBox(height: 15),
                    TextField(
                        controller: valorController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Valor (R\$)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money))),
                    const SizedBox(height: 15),
                    TextField(
                        controller: dataRealController,
                        readOnly: true,
                        onTap: () async {
                          DateTime dataInicial = DateTime.now();
                          try {
                            if (dataRealController.text.isNotEmpty) {
                              List<String> parts =
                                  dataRealController.text.split('/');
                              dataInicial = DateTime(int.parse(parts[2]),
                                  int.parse(parts[1]), int.parse(parts[0]));
                            }
                          } catch (e) {
                            debugPrint("Erro: $e");
                          }

                          DateTime? dataSelecionada = await showDatePicker(
                            context: context,
                            initialDate: dataInicial,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );

                          if (dataSelecionada != null) {
                            setStateBottomSheet(() {
                              dataRealController.text =
                                  "${dataSelecionada.day.toString().padLeft(2, '0')}/${dataSelecionada.month.toString().padLeft(2, '0')}/${dataSelecionada.year}";
                            });
                          }
                        },
                        decoration: const InputDecoration(
                            labelText: 'Data Real do Acontecimento',
                            helperText: 'Toque para escolher a data.',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today,
                                color: Colors.green))),
                    if (isDespesa)
                      CategoriaSelector(
                          selecionadas: catsSel,
                          onChanged: (l) =>
                              setStateBottomSheet(() => catsSel = l)),
                    if (isDespesa)
                      SwitchListTile(
                          title: const Text('Destinar à Poupança?',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold)),
                          value: isPoupanca,
                          activeThumbColor: Colors.blue,
                          secondary:
                              const Icon(Icons.savings, color: Colors.blue),
                          onChanged: (bool valor) {
                            setStateBottomSheet(() {
                              isPoupanca = valor;
                              if (isPoupanca) {
                                descricaoAntiga = descricaoController.text;
                                descricaoController.text = 'Poupança';
                              } else {
                                descricaoController.text = descricaoAntiga;
                              }
                            });
                          }),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: isPoupanca
                                    ? Colors.blue
                                    : (isDespesa ? Colors.red : Colors.green)),
                            onPressed: () async {
                              if (descricaoController.text.isNotEmpty &&
                                  valorController.text.isNotEmpty) {
                                double valorDigitado =
                                    parseMoeda(valorController.text);
                                if (isDespesa && valorDigitado > 0) {
                                  valorDigitado = valorDigitado * -1;
                                } else if (!isDespesa && valorDigitado < 0) {
                                  valorDigitado = valorDigitado * -1;
                                }

                                if (!temGrupo) {
                                  await doc.reference.update({
                                    'descricao': descricaoController.text,
                                    'valor': valorDigitado,
                                    'dataRealString': dataRealController.text,
                                    'isPoupanca': isPoupanca,
                                    'categorias': catsSel
                                  });
                                  // ignore: use_build_context_synchronously
                                  Navigator.pop(context);
                                } else {
                                  showDialog(
                                      context: context,
                                      builder: (BuildContext dialogContext) {
                                        return AlertDialog(
                                            title:
                                                const Text('Editar Conta Fixa'),
                                            content: const Text(
                                                'Deseja atualizar apenas este mês ou este e todos os meses futuros?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext,
                                                          'cancelar'),
                                                  child:
                                                      const Text('Cancelar')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext,
                                                          'este'),
                                                  child: const Text('Só este')),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext,
                                                          'futuros'),
                                                  child: const Text(
                                                      'Deste em diante',
                                                      style: TextStyle(
                                                          color: Colors.blue,
                                                          fontWeight:
                                                              FontWeight.bold)))
                                            ]);
                                      }).then((acao) async {
                                    if (acao == 'este') {
                                      await doc.reference.update({
                                        'descricao': descricaoController.text,
                                        'valor': valorDigitado,
                                        'dataRealString':
                                            dataRealController.text,
                                        'isPoupanca': isPoupanca,
                                        'categorias': catsSel
                                      });
                                      // ignore: use_build_context_synchronously
                                      Navigator.pop(context);
                                    } else if (acao == 'futuros') {
                                      DateTime dataDeCorte =
                                          (dados['data'] as Timestamp).toDate();
                                      var query = await FirebaseFirestore
                                          .instance
                                          .collection('lancamentos')
                                          .where('grupoId',
                                              isEqualTo: dados['grupoId'])
                                          .get();
                                      var batch =
                                          FirebaseFirestore.instance.batch();
                                      for (var d in query.docs) {
                                        var docData =
                                            (d.data()['data'] as Timestamp)
                                                .toDate();
                                        if (docData.year > dataDeCorte.year ||
                                            (docData.year == dataDeCorte.year &&
                                                docData.month >=
                                                    dataDeCorte.month)) {
                                          batch.update(d.reference, {
                                            'descricao':
                                                descricaoController.text,
                                            'valor': valorDigitado,
                                            'dataRealString':
                                                dataRealController.text,
                                            'isPoupanca': isPoupanca,
                                            'categorias': catsSel
                                          });
                                        }
                                      }
                                      await batch.commit();
                                      // ignore: use_build_context_synchronously
                                      Navigator.pop(context);
                                    }
                                  });
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Preencha a descrição e o valor!',
                                            style:
                                                TextStyle(color: Colors.white)),
                                        backgroundColor: Colors.red));
                              }
                            },
                            child: const Text('Atualizar',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white)))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SeletorMes(
            dataAtual: mesAno,
            aoMudar: aoMudarMes,
            travarFuturo: false,
          ),
          Expanded(
              child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lancamentos')
                .orderBy('data', descending: true)
                .snapshots(),
            builder: (context, snapshotLanc) {
              if (snapshotLanc.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }

              List<DocumentSnapshot> rendas = [];
              List<DocumentSnapshot> despesas = [];

              if (snapshotLanc.hasData) {
                for (var doc in snapshotLanc.data!.docs) {
                  final dados = doc.data() as Map<String, dynamic>;
                  if (dados['data'] == null) continue;
                  final dataDoBanco = (dados['data'] as Timestamp).toDate();
                  if (dataDoBanco.month == mesAno.month &&
                      dataDoBanco.year == mesAno.year) {
                    if (dados['isCartao'] == true ||
                        dados['isParcelamento'] == true) {
                      continue;
                    } else {
                      if (dados['isDepositoDireto'] == true) continue;
                      double val = (dados['valor'] ?? 0.0).toDouble();
                      if (val >= 0) {
                        rendas.add(doc);
                      } else {
                        despesas.add(doc);
                      }
                    }
                  }
                }
              }

              List<Widget> listaFinal = [];

              if (rendas.isNotEmpty) {
                listaFinal.add(const Padding(
                    padding: EdgeInsets.only(top: 10, left: 16, bottom: 8),
                    child: Text('Rendas',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16))));
                for (var docAtivo in rendas) {
                  final dados = docAtivo.data() as Map<String, dynamic>;
                  final descricao = dados['descricao'] ?? 'Sem descrição';
                  final valor = (dados['valor'] ?? 0.0).toDouble();
                  final responsavel = dados['responsavel'] ?? 'N/A';
                  final temGrupo = dados['grupoId'] != null;
                  listaFinal.add(Dismissible(
                    key: Key(docAtivo.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 30)),
                    confirmDismiss: (direction) async {
                      if (!temGrupo) {
                        bool? cf = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                    title: const Text('Apagar?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Não')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Sim',
                                              style:
                                                  TextStyle(color: Colors.red)))
                                    ]));
                        if (cf == true) {
                          await FirebaseFirestore.instance
                              .collection('lancamentos')
                              .doc(docAtivo.id)
                              .delete();
                          return true;
                        }
                        return false;
                      }
                      final acao = await showDialog<String>(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                                title: const Text('Excluir Renda Fixa'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'cancelar'),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'este'),
                                      child: const Text('Só este')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'futuros'),
                                      child: const Text('Deste em diante',
                                          style: TextStyle(color: Colors.red)))
                                ]);
                          });
                      if (acao == null || acao == 'cancelar') return false;
                      if (acao == 'este') {
                        await FirebaseFirestore.instance
                            .collection('lancamentos')
                            .doc(docAtivo.id)
                            .delete();
                      } else if (acao == 'futuros') {
                        DateTime dtCorte =
                            (dados['data'] as Timestamp).toDate();
                        var query = await FirebaseFirestore.instance
                            .collection('lancamentos')
                            .where('grupoId', isEqualTo: dados['grupoId'])
                            .get();
                        var batch = FirebaseFirestore.instance.batch();
                        for (var d in query.docs) {
                          var docData =
                              (d.data()['data'] as Timestamp).toDate();
                          if (docData.year > dtCorte.year ||
                              (docData.year == dtCorte.year &&
                                  docData.month >= dtCorte.month)) {
                            batch.delete(d.reference);
                          } else {
                            batch.update(d.reference, {'isContaFixa': false});
                          }
                        }
                        await batch.commit();
                      }
                      return true;
                    },
                    child: Column(children: [
                      ListTile(
                          onTap: () =>
                              _abrirFormularioEdicao(context, docAtivo),
                          leading: const Icon(Icons.arrow_circle_up,
                              color: Colors.green, size: 40),
                          title: Text(descricao,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(responsavel),
                                  if (temGrupo) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.repeat,
                                        size: 14, color: Colors.grey)
                                  ]
                                ]),
                                if (dados['dataRealString'] != null &&
                                    dados['dataRealString']
                                        .toString()
                                        .isNotEmpty)
                                  Text('Data real: ${dados['dataRealString']}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey))
                              ]),
                          trailing: Text(
                              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16))),
                      const Divider()
                    ]),
                  ));
                }
              }

              if (despesas.isNotEmpty) {
                listaFinal.add(const Padding(
                    padding: EdgeInsets.only(top: 20, left: 16, bottom: 8),
                    child: Text('Despesas e Poupança',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16))));
                for (var docAtivo in despesas) {
                  final dados = docAtivo.data() as Map<String, dynamic>;
                  final descricao = dados['descricao'] ?? 'Sem descrição';
                  final valor = (dados['valor'] ?? 0.0).toDouble();
                  final responsavel = dados['responsavel'] ?? 'N/A';
                  final temGrupo = dados['grupoId'] != null;
                  final isPoupanca = dados['isPoupanca'] ?? false;
                  final cor = isPoupanca ? Colors.blue : Colors.red;
                  final icone =
                      isPoupanca ? Icons.savings : Icons.arrow_circle_down;
                  listaFinal.add(Dismissible(
                    key: Key(docAtivo.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete,
                            color: Colors.white, size: 30)),
                    confirmDismiss: (direction) async {
                      if (!temGrupo) {
                        bool? cf = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                    title: const Text('Apagar?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Não')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Sim',
                                              style:
                                                  TextStyle(color: Colors.red)))
                                    ]));
                        if (cf == true) {
                          await FirebaseFirestore.instance
                              .collection('lancamentos')
                              .doc(docAtivo.id)
                              .delete();
                          return true;
                        }
                        return false;
                      }
                      final acao = await showDialog<String>(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                                title: const Text('Excluir Conta Fixa'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'cancelar'),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'este'),
                                      child: const Text('Só este')),
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, 'futuros'),
                                      child: const Text('Deste em diante',
                                          style: TextStyle(color: Colors.red)))
                                ]);
                          });
                      if (acao == null || acao == 'cancelar') return false;
                      if (acao == 'este') {
                        await FirebaseFirestore.instance
                            .collection('lancamentos')
                            .doc(docAtivo.id)
                            .delete();
                      } else if (acao == 'futuros') {
                        DateTime dtCorte =
                            (dados['data'] as Timestamp).toDate();
                        var query = await FirebaseFirestore.instance
                            .collection('lancamentos')
                            .where('grupoId', isEqualTo: dados['grupoId'])
                            .get();
                        var batch = FirebaseFirestore.instance.batch();
                        for (var d in query.docs) {
                          var docData =
                              (d.data()['data'] as Timestamp).toDate();
                          if (docData.year > dtCorte.year ||
                              (docData.year == dtCorte.year &&
                                  docData.month >= dtCorte.month)) {
                            batch.delete(d.reference);
                          } else {
                            batch.update(d.reference, {'isContaFixa': false});
                          }
                        }
                        await batch.commit();
                      }
                      return true;
                    },
                    child: Column(children: [
                      ListTile(
                          onTap: () =>
                              _abrirFormularioEdicao(context, docAtivo),
                          leading: Icon(icone, color: cor, size: 40),
                          title: Text(descricao,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(responsavel),
                                  if (temGrupo) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.repeat,
                                        size: 14, color: Colors.grey)
                                  ],
                                  if (isPoupanca)
                                    const Text(' (Poupança)',
                                        style: TextStyle(
                                            color: Colors.blue, fontSize: 12))
                                ]),
                                if (dados['dataRealString'] != null &&
                                    dados['dataRealString']
                                        .toString()
                                        .isNotEmpty)
                                  Text('Data real: ${dados['dataRealString']}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey))
                              ]),
                          trailing: Text(
                              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                  color: cor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16))),
                      const Divider()
                    ]),
                  ));
                }
              }

              if (listaFinal.isEmpty) {
                return const Center(
                    child: Text('Nenhuma conta ou fatura neste mês.',
                        style: TextStyle(fontSize: 16)));
              }
              return ListView(
                padding: const EdgeInsets.only(
                    bottom: 100), // 👈 Mola invisível de 100 pixels no final!
                children: listaFinal,
              );
            },
          )),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.green,
          onPressed: () => _abrirFormulario(context),
          child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

class TelaParcelamentos extends StatelessWidget {
  final DateTime mesAno;
  final Function(int) aoMudarMes;
  final String usuarioLogado;

  const TelaParcelamentos(
      {super.key,
      required this.mesAno,
      required this.aoMudarMes,
      required this.usuarioLogado});

  void _abrirFormularioParcelamento(BuildContext context) {
    final TextEditingController desc = TextEditingController();
    final TextEditingController val = TextEditingController();
    final TextEditingController totParcCtrl = TextEditingController(text: '2');
    final TextEditingController parcAtualCtrl =
        TextEditingController(text: '1');
    List<String> catsSel = [];
    // ⚙️ NOVIDADE: Variável que controla se o valor é total ou já parcelado
    bool isValorParcela = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(builder: (c, setS) {
            int totalParc = int.tryParse(totParcCtrl.text) ?? 1;

            return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.shopping_bag,
                      color: Colors.purple, size: 40),
                  const SizedBox(height: 10),
                  const Text('Nova Compra Parcelada',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                      controller: desc,
                      decoration: const InputDecoration(
                          labelText: 'O que comprou?',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit))),
                  const SizedBox(height: 15),
                  TextField(
                      controller: val,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          // ⚙️ O texto muda sozinho dependendo do interruptor!
                          labelText: isValorParcela
                              ? 'Valor de CADA Parcela (R\$)'
                              : 'Valor TOTAL da Compra (R\$)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money))),
                  // ⚙️ NOVIDADE: A caixinha (Switch) para mudar o tipo de cálculo
                  SwitchListTile(
                      title: const Text('O valor já é o da parcela?'),
                      value: isValorParcela,
                      activeThumbColor: Colors.purple,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (bool valor) {
                        setS(() {
                          isValorParcela = valor;
                        });
                      }),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: totParcCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Qtd de Parcelas',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.layers)),
                            onChanged: (v) => setS(() {}))),
                    if (totalParc > 1) ...[
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: parcAtualCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Parcela Atual',
                                  border: OutlineInputBorder())))
                    ]
                  ]),
                  const SizedBox(height: 15),
                  CategoriaSelector(
                      selecionadas: catsSel,
                      onChanged: (l) => setS(() => catsSel = l)),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple),
                          onPressed: () {
                            if (desc.text.isNotEmpty && val.text.isNotEmpty) {
                              int totP = int.tryParse(totParcCtrl.text) ?? 1;
                              int pAt = int.tryParse(parcAtualCtrl.text) ?? 1;
                              if (totP < 1) totP = 1;
                              if (pAt > totP) pAt = totP;
                              if (pAt < 1) pAt = 1;

                              double vDigitado = parseMoeda(val.text);
                              if (vDigitado > 0) vDigitado *= -1;

                              // ⚙️ A MÁGICA MATEMÁTICA AQUI!
                              double vParc = isValorParcela
                                  ? vDigitado
                                  : (vDigitado / totP);

                              DateTime agora = DateTime.now();
                              String? gId = totP > 1
                                  ? agora.millisecondsSinceEpoch.toString()
                                  : null;

                              int vezes = totP - pAt + 1;
                              for (int i = 0; i < vezes; i++) {
                                int numP = pAt + i;
                                FirebaseFirestore.instance
                                    .collection('lancamentos')
                                    .add({
                                      'descricao': desc.text,
                                      'valor': vParc,
                                      'responsavel': usuarioLogado,
                                      'data': Timestamp.fromDate(DateTime(
                                          mesAno.year,
                                          mesAno.month + i,
                                          agora.day,
                                          agora.hour,
                                          agora.minute,
                                          agora.second,
                                          agora.millisecond)),
                                      'isParcelamento': true,
                                      'isCartao': false,
                                      'parcelaAtual': numP,
                                      'totalParcelas': totP,
                                      'categorias': catsSel
                                    }..addAll(
                                        gId != null ? {'grupoId': gId} : {}));
                              }
                              Navigator.pop(ctx);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Preencha o que comprou e o valor!',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      backgroundColor: Colors.red));
                            }
                          },
                          child: const Text('Lançar Compra',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white)))),
                  const SizedBox(height: 20),
                ])));
          });
        });
  }

  void _abrirFormularioEdicao(BuildContext context, DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;
    final double valorAtual = (dados['valor'] ?? 0.0).toDouble();
    final temGrupo = dados['grupoId'] != null;

    final TextEditingController descController =
        TextEditingController(text: dados['descricao']);
    final TextEditingController valController = TextEditingController(
        text: (valorAtual < 0 ? valorAtual * -1 : valorAtual)
            .toStringAsFixed(2)
            .replaceAll('.', ','));
    List<String> catsSel = List<String>.from(dados['categorias'] ?? []);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext ctx) {
          return StatefulBuilder(builder: (c, setS) {
            return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    left: 20,
                    right: 20,
                    top: 20),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Editar Parcela',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                          labelText: 'Descrição da Compra',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit))),
                  const SizedBox(height: 15),
                  TextField(
                      controller: valController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Valor da Parcela (R\$)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money))),
                  const SizedBox(height: 15),
                  CategoriaSelector(
                      selecionadas: catsSel,
                      onChanged: (l) => setS(() => catsSel = l)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple),
                      onPressed: () async {
                        if (descController.text.isNotEmpty &&
                            valController.text.isNotEmpty) {
                          double valorDigitado = parseMoeda(valController.text);
                          if (valorDigitado > 0) valorDigitado *= -1;

                          if (!temGrupo) {
                            await doc.reference.update({
                              'descricao': descController.text,
                              'valor': valorDigitado,
                              'categorias': catsSel
                            });
                            // ignore: use_build_context_synchronously
                            Navigator.pop(ctx);
                          } else {
                            showDialog(
                                context: context,
                                builder: (BuildContext dCtx) {
                                  return AlertDialog(
                                      title:
                                          const Text('Editar Compra Parcelada'),
                                      content: const Text(
                                          'Atualizar apenas este mês ou este e os futuros?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, 'cancelar'),
                                            child: const Text('Cancelar')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, 'este'),
                                            child: const Text('Só este')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dCtx, 'futuros'),
                                            child: const Text('Deste em diante',
                                                style: TextStyle(
                                                    color: Colors.purple,
                                                    fontWeight:
                                                        FontWeight.bold)))
                                      ]);
                                }).then((acao) async {
                              if (acao == 'este') {
                                await doc.reference.update({
                                  'descricao': descController.text,
                                  'valor': valorDigitado,
                                  'categorias': catsSel
                                });
                                // ignore: use_build_context_synchronously
                                Navigator.pop(ctx);
                              } else if (acao == 'futuros') {
                                DateTime dtCorte =
                                    (dados['data'] as Timestamp).toDate();
                                var query = await FirebaseFirestore.instance
                                    .collection('lancamentos')
                                    .where('grupoId',
                                        isEqualTo: dados['grupoId'])
                                    .get();
                                var batch = FirebaseFirestore.instance.batch();
                                for (var d in query.docs) {
                                  var docData =
                                      (d.data()['data'] as Timestamp).toDate();
                                  if (docData.year > dtCorte.year ||
                                      (docData.year == dtCorte.year &&
                                          docData.month >= dtCorte.month)) {
                                    batch.update(d.reference, {
                                      'valor': valorDigitado,
                                      'descricao': descController.text,
                                      'categorias': catsSel
                                    });
                                  }
                                }
                                await batch.commit();
                                // ignore: use_build_context_synchronously
                                Navigator.pop(ctx);
                              }
                            });
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Preencha a descrição e o valor!',
                                      style: TextStyle(color: Colors.white)),
                                  backgroundColor: Colors.red));
                        }
                      },
                      child: const Text('Atualizar',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ])));
          });
        });
  }

  void _opcoesParcelamento(BuildContext context, DocumentSnapshot doc) {
    final dados = doc.data() as Map<String, dynamic>;
    final temGrupo = dados['grupoId'] != null;

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Opções da Parcela',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text('Editar'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _abrirFormularioEdicao(context, doc);
                    }),
                const Divider(),
                // ⚙️ NOVIDADE 3: O Botão de Adiantamento super inteligente!
                ListTile(
                    leading:
                        const Icon(Icons.fast_forward, color: Colors.purple),
                    title: Text(
                        'Adiantar para Hoje (${obterNomeMes(DateTime.now().month)})'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      DateTime hj = DateTime.now();

                      if (temGrupo) {
                        var query = await FirebaseFirestore.instance
                            .collection('lancamentos')
                            .where('grupoId', isEqualTo: dados['grupoId'])
                            .get();
                        var batch = FirebaseFirestore.instance.batch();

                        for (var d in query.docs) {
                          int totalAtual = d.data()['totalParcelas'] ?? 1;
                          // Reduz o total global das parcelas em 1
                          int novoTotal = totalAtual - 1;
                          if (novoTotal < 1) novoTotal = 1;

                          if (d.id == doc.id) {
                            // Se for a parcela adiantada, muda a data pra hoje
                            batch.update(d.reference, {
                              'data': Timestamp.fromDate(
                                  DateTime(hj.year, hj.month, hj.day, hj.hour)),
                              'totalParcelas': novoTotal
                            });
                          } else {
                            // Se forem as outras, só atualiza o total no badge
                            batch.update(
                                d.reference, {'totalParcelas': novoTotal});
                          }
                        }
                        await batch.commit();
                      } else {
                        doc.reference.update({
                          'data': Timestamp.fromDate(
                              DateTime(hj.year, hj.month, hj.day, hj.hour))
                        });
                      }
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Parcela adiantada! Total de parcelas ajustado.')));
                    }),
                const Divider(),
                ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Apagar Compra',
                        style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (!temGrupo) {
                        bool? cf = await showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                                    title: const Text('Apagar?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, false),
                                          child: const Text('Não')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dCtx, true),
                                          child: const Text('Sim',
                                              style:
                                                  TextStyle(color: Colors.red)))
                                    ]));
                        if (cf == true) {
                          await doc.reference.delete();
                        }
                      } else {
                        final acao = await showDialog<String>(
                            context: context,
                            builder: (BuildContext dCtx) {
                              return AlertDialog(
                                  title: const Text('Excluir Parcelamento'),
                                  content: const Text(
                                      'Apagar apenas este mês ou este e todos os meses futuros?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, 'cancelar'),
                                        child: const Text('Cancelar')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, 'este'),
                                        child: const Text('Só este')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dCtx, 'futuros'),
                                        child: const Text('Deste em diante',
                                            style:
                                                TextStyle(color: Colors.red)))
                                  ]);
                            });
                        if (acao == 'este') {
                          await doc.reference.delete();
                        } else if (acao == 'futuros') {
                          DateTime dtCorte =
                              (dados['data'] as Timestamp).toDate();
                          var query = await FirebaseFirestore.instance
                              .collection('lancamentos')
                              .where('grupoId', isEqualTo: dados['grupoId'])
                              .get();
                          var batch = FirebaseFirestore.instance.batch();
                          for (var d in query.docs) {
                            var docData =
                                (d.data()['data'] as Timestamp).toDate();
                            if (docData.year > dtCorte.year ||
                                (docData.year == dtCorte.year &&
                                    docData.month >= dtCorte.month)) {
                              batch.delete(d.reference);
                            }
                          }
                          await batch.commit();
                        }
                      }
                    }),
              ]));
        });
  }

  Widget _buildBadge(Map<String, dynamic> dados) {
    if (dados['totalParcelas'] != null && dados['totalParcelas'] > 1) {
      int pAt = dados['parcelaAtual'] ?? 1;
      int pTot = dados['totalParcelas'] ?? 1;

      // ⚙️ Essa trava visual faz com que a parcela que você adiantou não mostre (10/9),
      // ela trava em (9/9) enquanto as de trás diminuem normal!
      if (pAt > pTot) pTot = pAt;

      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          '$pAt/$pTot',
          style: TextStyle(
            fontSize: 10,
            color: Colors.blue.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    DateTime inicio = DateTime(mesAno.year, mesAno.month, 1);
    DateTime fim = DateTime(mesAno.year, mesAno.month + 1, 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SeletorMes(
            dataAtual: mesAno,
            aoMudar: aoMudarMes,
            travarFuturo: false,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('lancamentos')
                  .where('data',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                  .where('data', isLessThan: Timestamp.fromDate(fim))
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.purple));
                }

                List<DocumentSnapshot> parcelamentos = [];
                double totalMes = 0.0;

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final dados = doc.data() as Map<String, dynamic>;
                    if (dados['isCartao'] == true ||
                        dados['isParcelamento'] == true) {
                      parcelamentos.add(doc);
                      double valor = (dados['valor'] ?? 0.0).toDouble();
                      totalMes += valor < 0 ? valor * -1 : valor;
                    }
                  }
                }

                return Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Total de Parcelas: R\$ ${totalMes.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple))),
                    Expanded(
                        child: parcelamentos.isEmpty
                            ? const Center(
                                child: Text('Nenhuma parcela neste mês.',
                                    style: TextStyle(fontSize: 16)))
                            : ListView.builder(
                                padding: const EdgeInsets.only(
                                    bottom:
                                        100), // 👈 Adiciona essa linha aqui!
                                itemCount: parcelamentos.length,
                                itemBuilder: (c, index) {
                                  final doc = parcelamentos[index];
                                  final d = doc.data() as Map<String, dynamic>;
                                  return InkWell(
                                      onTap: () =>
                                          _opcoesParcelamento(context, doc),
                                      child: ListTile(
                                          leading: const Icon(
                                              Icons.shopping_bag,
                                              color: Colors.purple),
                                          title: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                    d['descricao'] ??
                                                        'Sem descrição',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                              _buildBadge(d),
                                            ],
                                          ),
                                          subtitle: Text(
                                              'Comprador: ${d['responsavel'] ?? 'N/A'}'),
                                          trailing: Text(
                                              'R\$ ${(d['valor'] * -1).toStringAsFixed(2).replaceAll('.', ',')}',
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight:
                                                      FontWeight.bold))));
                                }))
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.purple,
          onPressed: () => _abrirFormularioParcelamento(context),
          child: const Icon(Icons.add, color: Colors.white)),
    );
  }
}

class TelaPoupanca extends StatelessWidget {
  final DateTime mesAno;
  final Function(int) aoMudarMes;
  final String usuarioLogado;

  const TelaPoupanca(
      {super.key,
      required this.mesAno,
      required this.aoMudarMes,
      required this.usuarioLogado});

  void _abrirFormularioDepositoDireto(BuildContext context) {
    final TextEditingController descCtrl =
        TextEditingController(text: 'Saldo Inicial / Extra');
    final TextEditingController valCtrl = TextEditingController();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                  left: 20,
                  right: 20,
                  top: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance, color: Colors.blue, size: 40),
                const SizedBox(height: 10),
                const Text('Depósito Direto',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                    'Esse valor vai direto para o cofre sem afetar as despesas da aba Resumo.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 15),
                TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit))),
                const SizedBox(height: 15),
                TextField(
                    controller: valCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Valor (R\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money))),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue),
                        onPressed: () {
                          if (valCtrl.text.isNotEmpty &&
                              descCtrl.text.isNotEmpty) {
                            double val = parseMoeda(valCtrl.text);
                            DateTime agora = DateTime.now();
                            FirebaseFirestore.instance
                                .collection('lancamentos')
                                .add({
                              'descricao': descCtrl.text,
                              'valor': val * -1,
                              'responsavel': usuarioLogado,
                              'data': Timestamp.fromDate(DateTime(
                                  mesAno.year,
                                  mesAno.month,
                                  agora.day,
                                  agora.hour,
                                  agora.minute)),
                              'isCartao': false,
                              'isPoupanca': true,
                              'poupancaConfirmada': true,
                              'isDepositoDireto': true
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Adicionar ao Cofre',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)))),
                const SizedBox(height: 20),
              ]));
        });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            SeletorMes(
              dataAtual: mesAno,
              aoMudar: aoMudarMes,
              travarFuturo: false,
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('lancamentos')
                      .where('isPoupanca', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.blue));
                    }
                    double totalConfirmadoSempre = 0.0;
                    List<DocumentSnapshot> poupancasDoMes = [];
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        final dados = doc.data() as Map<String, dynamic>;
                        double valor = (dados['valor'] ?? 0.0).toDouble();
                        if (valor < 0) valor = valor * -1;
                        bool confirmada = dados['poupancaConfirmada'] ?? false;
                        if (confirmada) {
                          totalConfirmadoSempre += valor;
                        }
                        if (dados['data'] != null) {
                          final dataDoBanco =
                              (dados['data'] as Timestamp).toDate();
                          if (dataDoBanco.month == mesAno.month &&
                              dataDoBanco.year == mesAno.year) {
                            poupancasDoMes.add(doc);
                          }
                        }
                      }
                    }
                    return Column(
                      children: [
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff383636),
                                    Color(0xff6d6d56)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              const Icon(Icons.savings,
                                  color: Colors.white, size: 50),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Total Acumulado Confirmado',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 16)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        _abrirFormularioDepositoDireto(context),
                                    child: const Icon(Icons.add_circle,
                                        color: Colors.white, size: 22),
                                  )
                                ],
                              ),
                              Text(
                                  'R\$ ${totalConfirmadoSempre.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold))
                            ])),
                        const Divider(height: 30),
                        const Text('Depósitos do Mês',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Expanded(
                          child: poupancasDoMes.isEmpty
                              ? const Center(
                                  child: Text(
                                      'Nenhum depósito planejado para este mês.',
                                      style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: poupancasDoMes.length,
                                  itemBuilder: (context, index) {
                                    final doc = poupancasDoMes[index];
                                    final dados =
                                        doc.data() as Map<String, dynamic>;
                                    final descricao =
                                        dados['descricao'] ?? 'Poupança';
                                    final valor =
                                        ((dados['valor'] ?? 0.0).toDouble()) *
                                            -1;
                                    final confirmada =
                                        dados['poupancaConfirmada'] ?? false;
                                    final temGrupo = dados['grupoId'] != null;
                                    return Dismissible(
                                      key: Key(doc.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                          color: Colors.red,
                                          alignment: Alignment.centerRight,
                                          padding:
                                              const EdgeInsets.only(right: 20),
                                          child: const Icon(Icons.delete,
                                              color: Colors.white, size: 30)),
                                      confirmDismiss: (direction) async {
                                        if (!temGrupo) {
                                          bool? conf = await showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                      title:
                                                          const Text('Apagar?'),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx, false),
                                                            child: const Text(
                                                                'Cancelar')),
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx, true),
                                                            child: const Text(
                                                                'Apagar',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red)))
                                                      ]));
                                          if (conf == true) {
                                            await doc.reference.delete();
                                            return true;
                                          }
                                          return false;
                                        }
                                        final acao = await showDialog<String>(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                  title: const Text(
                                                      'Excluir Poupança Fixa'),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx,
                                                                'cancelar'),
                                                        child: const Text(
                                                            'Cancelar')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, 'este'),
                                                        child: const Text(
                                                            'Só este')),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, 'futuros'),
                                                        child: const Text(
                                                            'Deste em diante',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .red)))
                                                  ]);
                                            });
                                        if (acao == null ||
                                            acao == 'cancelar') {
                                          return false;
                                        }
                                        if (acao == 'este') {
                                          await doc.reference.delete();
                                        } else if (acao == 'futuros') {
                                          DateTime dtCorte =
                                              (dados['data'] as Timestamp)
                                                  .toDate();
                                          var query = await FirebaseFirestore
                                              .instance
                                              .collection('lancamentos')
                                              .where('grupoId',
                                                  isEqualTo: dados['grupoId'])
                                              .get();
                                          var batch = FirebaseFirestore.instance
                                              .batch();
                                          for (var d in query.docs) {
                                            var docData =
                                                (d.data()['data'] as Timestamp)
                                                    .toDate();
                                            if (docData.year > dtCorte.year ||
                                                (docData.year == dtCorte.year &&
                                                    docData.month >=
                                                        dtCorte.month)) {
                                              batch.delete(d.reference);
                                            } else {
                                              batch.update(d.reference,
                                                  {'isContaFixa': false});
                                            }
                                          }
                                          await batch.commit();
                                        }
                                        return true;
                                      },
                                      child: Card(
                                        color: isDark
                                            ? const Color(0xFF1E1E1E)
                                            : Colors.white,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                              backgroundColor: confirmada
                                                  ? Colors.green.shade100
                                                  : Colors.orange.shade100,
                                              child: Icon(
                                                  confirmada
                                                      ? Icons.check
                                                      : Icons.access_time,
                                                  color: confirmada
                                                      ? Colors.green
                                                      : Colors.orange)),
                                          title: Text(descricao,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              confirmada
                                                  ? 'Aplicado com sucesso'
                                                  : 'Aguardando depósito',
                                              style: TextStyle(
                                                  color: confirmada
                                                      ? Colors.green
                                                      : Colors.orange,
                                                  fontSize: 12)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                  child: Text(
                                                      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                      overflow: TextOverflow
                                                          .ellipsis)),
                                              const SizedBox(width: 5),
                                              if (!confirmada)
                                                ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.blue,
                                                            padding:
                                                                const EdgeInsets
                                                                        .symmetric(
                                                                    horizontal:
                                                                        5)),
                                                    onPressed: () {
                                                      doc.reference.update({
                                                        'poupancaConfirmada':
                                                            true
                                                      });
                                                    },
                                                    child: const Text('OK',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 12)))
                                              else
                                                IconButton(
                                                    icon: const Icon(Icons.undo,
                                                        color: Colors.grey,
                                                        size: 20),
                                                    onPressed: () {
                                                      doc.reference.update({
                                                        'poupancaConfirmada':
                                                            false
                                                      });
                                                    })
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        )
                      ],
                    );
                  }),
            )
          ],
        ));
  }
}

class NewsCardItem extends StatefulWidget {
  final String titulo;
  final String descricao;
  final String versao;

  const NewsCardItem(
      {super.key,
      required this.titulo,
      required this.descricao,
      required this.versao});

  @override
  State<NewsCardItem> createState() => _NewsCardItemState();
}

class _NewsCardItemState extends State<NewsCardItem> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _expandido = !_expandido;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green),
                    ),
                  ),
                  if (widget.versao.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'v${widget.versao}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.descricao,
                style: const TextStyle(fontSize: 13),
                maxLines: _expandido ? null : 2,
                overflow: _expandido ? null : TextOverflow.ellipsis,
              ),
              if (!_expandido)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    'Ver mais...',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// NOVO COMPONENTE: PIZZA INTERATIVA COM LISTA DE GASTOS 🚀
// =======================================================
class PainelPizzaInterativa extends StatefulWidget {
  final List<Map<String, dynamic>> fatias;
  final double total;

  const PainelPizzaInterativa(
      {super.key, required this.fatias, required this.total});

  @override
  State<PainelPizzaInterativa> createState() => _PainelPizzaInterativaState();
}

class _PainelPizzaInterativaState extends State<PainelPizzaInterativa> {
  int? _fatiaSelecionada;
  List<Map<String, dynamic>> _fatiasProntas = [];

  @override
  void initState() {
    super.initState();
    _prepararFatias();
  }

  @override
  void didUpdateWidget(covariant PainelPizzaInterativa oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepararFatias();
  }

  void _prepararFatias() {
    _fatiasProntas = [];
    for (int i = 0; i < widget.fatias.length; i++) {
      var f = Map<String, dynamic>.from(widget.fatias[i]);
      f['indexOriginal'] = i;
      f['pct'] = (f['valor'] / widget.total) * 100;
      _fatiasProntas.add(f);
    }
    // 👇 A MAGICA: Agora nós ordenamos tudo ANTES do mouse e do pincel lerem!
    _fatiasProntas.sort((a, b) => b['valor'].compareTo(a['valor']));
  }

  void _mudarSelecao(int? novoIndex) {
    if (_fatiaSelecionada != novoIndex) {
      setState(() {
        _fatiaSelecionada = novoIndex;
      });
    }
  }

  void _verificarInteracao(Offset localPosition, Size size) {
    double cx = size.width / 2;
    double cy = size.height / 2;
    double dx = localPosition.dx - cx;
    double dy = localPosition.dy - cy;

    double raioBase = min(cx, cy) * 0.65;
    double r = sqrt(dx * dx + dy * dy);

    if (r > raioBase * 1.3 || r < raioBase * 0.7) return;

    double touchAngle = atan2(dy, dx);
    double angleFromTop = touchAngle - (-pi / 2);
    if (angleFromTop < 0) angleFromTop += 2 * pi;

    double currentAngle = 0;
    // 👇 O SENSOR CONSERTADO: Lendo a mesma ordem que o desenho!
    for (int i = 0; i < _fatiasProntas.length; i++) {
      double sweep = (_fatiasProntas[i]['valor'] / widget.total) * 2 * pi;
      if (angleFromTop >= currentAngle &&
          angleFromTop <= currentAngle + sweep) {
        _mudarSelecao(_fatiasProntas[i]['indexOriginal']);
        return;
      }
      currentAngle += sweep;
    }
  }

  void _mostrarDetalhesFatia(BuildContext context, Map<String, dynamic> fatia) {
    List itens = fatia['itens'] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                          color: fatia['cor'], shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Flexible(
                      child: Text('Gastos com ${fatia['nome']}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(height: 25),
              if (itens.isEmpty)
                const Text('Nenhum detalhe encontrado.',
                    style: TextStyle(color: Colors.grey))
              else
                Expanded(
                  child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: itens.length,
                      itemBuilder: (c, i) {
                        var item = itens[i];
                        double v = (item['valor'] ?? 0.0).toDouble();
                        if (v < 0) v *= -1;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(item['descricao'] ?? 'Sem nome',
                              style: const TextStyle(fontSize: 15)),
                          trailing: Text(
                              'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                  color: fatia['cor'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        );
                      }),
                )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          width: double.infinity,
          child: LayoutBuilder(builder: (context, constraints) {
            Size size = Size(constraints.maxWidth, constraints.maxHeight);
            return MouseRegion(
              onHover: (e) => _verificarInteracao(e.localPosition, size),
              child: GestureDetector(
                onTapDown: (d) => _verificarInteracao(d.localPosition, size),
                onPanUpdate: (d) => _verificarInteracao(d.localPosition, size),
                child: CustomPaint(
                  size: size,
                  painter: GraficoPizza(
                      _fatiasProntas, widget.total, _fatiaSelecionada),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Column(
          children: _fatiasProntas.map((f) {
            bool isHovered = _fatiaSelecionada == f['indexOriginal'];
            return InkWell(
              onTap: () => _mostrarDetalhesFatia(context, f),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                    color: isHovered
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.transparent,
                    border: const Border(
                        bottom: BorderSide(color: Colors.white10))),
                child: Row(
                  children: [
                    Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                            color: f['cor'],
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 16),
                    Text(f['nome'],
                        style: TextStyle(
                            fontSize: 15,
                            color: isHovered ? Colors.white : Colors.white70,
                            fontWeight: isHovered
                                ? FontWeight.bold
                                : FontWeight.normal)),
                    const Spacer(),
                    Text(
                        'R\$ ${f['valor'].toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                isHovered ? FontWeight.bold : FontWeight.normal,
                            color: isHovered ? f['cor'] : Colors.white))
                  ],
                ),
              ),
            );
          }).toList(),
        )
      ],
    );
  }
}

// =======================================================
// O PINTOR DA ROSCA (CÍRCULO PERFEITO E ESTÁTICO) 🍩✨
// =======================================================
class GraficoPizza extends CustomPainter {
  final List<Map<String, dynamic>> fatias;
  final double total;
  final int? hoveredIndex;

  GraficoPizza(this.fatias, this.total, this.hoveredIndex);

  @override
  void paint(Canvas canvas, Size size) {
    double startAngle = -pi / 2;
    double cx = size.width / 2;
    double cy = size.height / 2;

    double raioBase = min(cx, cy) * 0.65;
    double espessuraLinha = 12.0; // Espessura fixa para não pular

    for (int i = 0; i < fatias.length; i++) {
      final sweepAngle = (fatias[i]['valor'] / total) * 2 * pi;

      // Cria o "vão" transparente entre as fatias
      double gap = sweepAngle > 0.08 ? 0.04 : 0.0;
      double actualSweep = sweepAngle - gap;
      if (actualSweep < 0) actualSweep = sweepAngle;

      double midAngle = startAngle + sweepAngle / 2;

      // 👇 REMOVIDA A ELEVAÇÃO! O centro agora é sempre o centro exato.
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: raioBase);

      final paint = Paint()
        ..color = fatias[i]['cor']
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            espessuraLinha; // Sem alterar a grossura ao passar o mouse

      canvas.drawArc(rect, startAngle + gap / 2, actualSweep, false, paint);

      // Desenha a porcentagem externa
      if (fatias[i]['pct'] >= 2.0) {
        double textRadius = raioBase + espessuraLinha + 18;
        Offset textOffset = Offset(
            cx + cos(midAngle) * textRadius, cy + sin(midAngle) * textRadius);

        TextSpan span = TextSpan(
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            text: '${fatias[i]['pct'].round()}%');
        TextPainter tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(
            canvas,
            Offset(
                textOffset.dx - tp.width / 2, textOffset.dy - tp.height / 2));
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant GraficoPizza oldDelegate) {
    // Como a pizza não muda mais fisicamente, ela só redesenha se as fatias mudarem!
    return oldDelegate.fatias != fatias;
  }
}

// h
// NOVA TELA: CARTÃO (AGRUPA CONTAS E PARCELAS EM ABAS) 💳
// =======================================================
class TelaCartao extends StatelessWidget {
  final DateTime mesAno;
  final Function(int) aoMudarMes;
  final String usuarioLogado;

  const TelaCartao(
      {super.key,
      required this.mesAno,
      required this.aoMudarMes,
      required this.usuarioLogado});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Duas abas superiores
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.purple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.purple,
            tabs: [
              Tab(text: 'Contas do Mês', icon: Icon(Icons.receipt_long)),
              Tab(text: 'Parcelamentos', icon: Icon(Icons.shopping_bag)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Reaproveitamos as telas EXATAMENTE como você já programou elas!
                TelaLancamentos(
                    mesAno: mesAno,
                    aoMudarMes: aoMudarMes,
                    usuarioLogado: usuarioLogado),
                TelaParcelamentos(
                    mesAno: mesAno,
                    aoMudarMes: aoMudarMes,
                    usuarioLogado: usuarioLogado),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// TELA ESTATÍSTICAS (AGORA COM PIZZA E BALANÇO ANUAL) 📊
// =======================================================
// =======================================================
// TELA DE ESTATÍSTICAS (Com Estado 100% Independente) 📊
// =======================================================
class TelaEstatisticas extends StatefulWidget {
  const TelaEstatisticas({super.key});

  @override
  State<TelaEstatisticas> createState() => _TelaEstatisticasState();
}

class _TelaEstatisticasState extends State<TelaEstatisticas>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 🛡️ MEMÓRIAS INDEPENDENTES: Nenhuma mexe na outra e nem afetam o Resumo/Cartão!
  DateTime _dataMensal = DateTime(DateTime.now().year, DateTime.now().month);
  int _anoAnual = DateTime.now().year;
  int _abaAnterior = 0; // Crie essa variável solta lá em cima

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 👇 Só redesenha a tela se ele de fato mudou de aba (0 para 1 ou 1 para 0)
      if (_tabController.index != _abaAnterior) {
        setState(() {
          _abaAnterior = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAnual = _tabController.index == 1;

    return Column(
      children: [
        // 1. O SELETOR INTELIGENTE (Muda de comportamento conforme a aba)
        SeletorMes(
          dataAtual: isAnual ? DateTime(_anoAnual, 1, 1) : _dataMensal,
          aoMudar: (delta) {
            setState(() {
              if (isAnual) {
                _anoAnual += (delta > 0 ? 1 : -1);
              } else {
                // Pula de mês com segurança no Flutter
                _dataMensal =
                    DateTime(_dataMensal.year, _dataMensal.month + delta, 1);
              }
            });
          },
          isAnual: isAnual,
        ),

        // 2. ABAS (Mensal / Balanço Anual)
        Container(
          color: Colors.transparent,
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00E676),
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Mensal (Pizza)'),
              Tab(text: 'Balanço Anual'),
            ],
          ),
        ),

        // 3. CONTEÚDO DAS ABAS COM OS DADOS ISOLADOS
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EstatisticasMensal(mesAno: _dataMensal),
              _TabAnual(ano: _anoAnual),
            ],
          ),
        ),
      ],
    );
  }
}

// O miolo da Estatística (Para o código não virar uma bagunça)
class _EstatisticasMensal extends StatelessWidget {
  final DateTime mesAno;
  const _EstatisticasMensal({required this.mesAno});

  @override
  Widget build(BuildContext context) {
    DateTime inicio = DateTime(mesAno.year, mesAno.month, 1);
    DateTime fim = DateTime(mesAno.year, mesAno.month + 1, 1);

    // 👇 TAMBÉM RETORNA O STREAMBUILDER DIRETO!
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('lancamentos')
            .where('data', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
            .where('data', isLessThan: Timestamp.fromDate(fim))
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          double totalSaidas = 0;
          double renda = 0;
          Map<String, Map<String, dynamic>> fatiasPizza = {};

          for (var doc in snapshot.data!.docs) {
            var d = doc.data() as Map<String, dynamic>;
            double v = (d['valor'] ?? 0.0).toDouble();

            if (d['isDepositoDireto'] == true) continue;

            if (v >= 0 &&
                d['isCartao'] != true &&
                d['isParcelamento'] != true &&
                d['isPoupanca'] != true) {
              renda += v;
            } else {
              double abs = v < 0 ? v * -1 : v;

              if (d['isPoupanca'] == true) {
                var f = fatiasPizza['Poupança'] ??
                    {
                      'valor': 0.0,
                      'cor': Colors.blue,
                      'nome': 'Poupança',
                      'itens': []
                    };
                f['valor'] += abs;
                f['itens'].add(d);
                fatiasPizza['Poupança'] = f;
                totalSaidas += abs;
              } else if (d['isParcelamento'] == true || d['isCartao'] == true) {
                var f = fatiasPizza['Parcelamentos'] ??
                    {
                      'valor': 0.0,
                      'cor': Colors.purple,
                      'nome': 'Parcelamentos',
                      'itens': []
                    };
                f['valor'] += abs;
                f['itens'].add(d);
                fatiasPizza['Parcelamentos'] = f;
                totalSaidas += abs;
              } else {
                var cats = d['categorias'] ?? [];
                String idCat = cats.isNotEmpty ? cats[0].toString() : '';

                // 👇 Lendo da nossa variável Global super rápida!
                var catInfo = cacheCategoriasGeral[idCat];
                String nomeCat =
                    catInfo != null ? (catInfo['nome'] ?? 'Outros') : 'Outros';
                Color corCat = catInfo != null
                    ? Color(catInfo['cor'] ?? Colors.grey.toARGB32())
                    : Colors.grey;

                var f = fatiasPizza[nomeCat] ??
                    {'valor': 0.0, 'cor': corCat, 'nome': nomeCat, 'itens': []};
                f['valor'] += abs;
                f['itens'].add(d);
                fatiasPizza[nomeCat] = f;
                totalSaidas += abs;
              }
            }
          }

          double sobra = renda - totalSaidas;
          if (sobra > 0) {
            fatiasPizza['Sobra do Mês'] = {
              'valor': sobra,
              'cor': const Color(0xFF00E676),
              'nome': 'Sobra do Mês',
              'itens': [
                {'descricao': 'Dinheiro livre não gasto', 'valor': sobra}
              ]
            };
          }

          List<Map<String, dynamic>> listaFatias = fatiasPizza.values.toList();
          double totalPizza = sobra > 0 ? renda : totalSaidas;

          if (totalPizza == 0) {
            return const Center(
                child: Text('Nenhum dado neste mês para gerar estatísticas.',
                    style: TextStyle(color: Colors.grey)));
          }

          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Gastos e Sobra do mês',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal)),
            const SizedBox(height: 15),
            PainelPizzaInterativa(fatias: listaFatias, total: totalPizza),
          ]);
        });
  }
}

// Coloque isso solto no código ou dentro da sua classe de Login
bool isNatal() {
  DateTime hoje = DateTime.now();
  // Se o mês for 12 (Dezembro), retorna true e liga o Natal! 🎄
  return hoje.month == 8;
}
