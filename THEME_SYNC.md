# Sincronização de Tema com API

## Visão Geral

A configuração de tema agora é sincronizada com a API, permitindo que:

1. O usuário mude de tema e a preferência seja salva no banco de dados
2. Em qualquer device, o usuário receba o tema correto ao fazer login
3. Cores personalizadas sejam armazenadas e recuperadas

## Arquitetura

### Backend (Node.js/Express)
- **Modelo**: Campo `theme` adicionado ao `User` schema
- **Rota de Configuração**: `/api/config/*` (prefixo dedicado)
- **Endpoints**:
  - `GET /api/config/preferences` - Obter preferências do usuário
  - `PUT /api/config/preferences/theme` - Atualizar tema
  - `PUT /api/config/preferences/colors` - Atualizar cores
  - `GET /api/config/themes` - Listar temas disponíveis

### Frontend (Flutter)

#### 1. `ApiService` (Comunicação com API)
Novos métodos adicionados:
```dart
Future<Map<String, dynamic>> getPreferences()
Future<Map<String, dynamic>> updateTheme(String theme)
Future<Map<String, dynamic>> updateColors({String? primaryColor, String? accentColor})
Future<Map<String, dynamic>> getAvailableThemes()
```

#### 2. `ThemeConfigService` (Gerenciamento Local)
Serviço Singleton que gerencia:
- Sincronização com API
- Cache local via SharedPreferences
- Notificação de mudanças
- Conversão de cores

**Métodos principais**:
```dart
Future<void> init() // Inicializar
Future<Map<String, dynamic>> syncPreferences() // Sincronizar com API
Future<void> setTheme(String theme) // Atualizar tema
Future<void> updateColors({String? primaryColor, String? accentColor}) // Atualizar cores
String getLocalTheme() // Obter tema do cache
Map<String, Color> getThemeColors(String theme) // Obter cores do tema
```

## Fluxo de Funcionamento

### 1. Login
```
User.login() → ApiService.login()
  ↓
API retorna token + config com tema
  ↓
App salva token e sincroniza tema
```

### 2. Mudança de Tema
```
User clica em "Escuro" / "Claro"
  ↓
ThemeConfigService.setTheme('dark')
  ↓
Envia PUT /api/config/preferences/theme
  ↓
API atualiza User.theme no BD
  ↓
App atualiza cache local + notifica listeners
  ↓
UI reconstrói com novas cores
```

### 3. Sincronização
```
App inicia
  ↓
ThemeConfigService.syncPreferences()
  ↓
Obtém preferências do API
  ↓
Salva no cache local
```

## Implementação no main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar serviços
  await ApiService.init();
  await ThemeConfigService().init();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    ThemeConfigService().addThemeChangeListener(_onThemeChange);
  }

  void _onThemeChange() {
    setState(() {});
  }

  @override
  void dispose() {
    ThemeConfigService().removeThemeChangeListener(_onThemeChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeConfigService().getLocalTheme();
    final themeService = ThemeService();
    
    return MaterialApp(
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: theme == 'dark' ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
    );
  }
}
```

## Implementação em Pages (Exemplo: Settings Page)

```dart
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _currentTheme;

  @override
  void initState() {
    super.initState();
    _currentTheme = ThemeConfigService().getLocalTheme();
  }

  void _changeTheme(String theme) async {
    try {
      setState(() => _currentTheme = theme);
      await ThemeConfigService().setTheme(theme);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tema alterado para $theme')),
      );
    } catch (e) {
      setState(() => _currentTheme = ThemeConfigService().getLocalTheme());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Tema Claro'),
            leading: Radio(
              value: 'light',
              groupValue: _currentTheme,
              onChanged: (value) => _changeTheme(value ?? 'light'),
            ),
          ),
          ListTile(
            title: const Text('Tema Escuro'),
            leading: Radio(
              value: 'dark',
              groupValue: _currentTheme,
              onChanged: (value) => _changeTheme(value ?? 'dark'),
            ),
          ),
        ],
      ),
    );
  }
}
```

## Cores Disponíveis

### Tema Claro
```
Primary: #1E88E5 (Azul)
AppBar Background: #1E88E5
Scaffold Background: #FFFFFF (Branco)
Card Background: #FFFFFF
Text Primary: #000000 (Preto)
Text Secondary: #666666 (Cinza)
Accent: #FF6B35 (Laranja)
```

### Tema Escuro
```
Primary: #1E88E5 (Azul - mantém o mesmo)
AppBar Background: #1A1F2E (Cinza escuro)
Scaffold Background: #0F1419 (Preto)
Card Background: #1A1F2E
Text Primary: #FFFFFF (Branco)
Text Secondary: #CCCCCC (Cinza claro)
Accent: #FF6B35 (Laranja - mantém o mesmo)
```

## Troubleshooting

### Tema não persiste após relogin
- Verificar se `syncPreferences()` está sendo chamado após login
- Verificar se o API está retornando o campo `theme` corretamente

### Cores não aplicam imediatamente
- Adicionar listener no widget: `ThemeConfigService().addThemeChangeListener()`
- Chamar `setState(() {})` quando tema mudar

### Erro 401 ao atualizar tema
- Token pode ter expirado
- ApiService automaticamente tenta fazer refresh
- Verificar se middleware de auth está correto na API

## Migração de Usuários Existentes

Usuários criados antes desta atualização não terão o campo `theme` definido. Para migração:

1. API retorna `theme: 'light'` por padrão para usuários antigos
2. Na primeira mudança de tema, o campo é atualizado no BD
3. Nenhuma ação manual necessária

## Próximos Passos

1. Implementar seletor de cores personalizadas (color picker)
2. Adicionar mais temas (ex: high contrast)
3. Integrar preferências de acessibilidade
4. Sincronizar outras preferências (linguagem, notificações)
