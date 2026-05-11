# iOS Release Checklist (Mesma Base do Android)

Objetivo: publicar no iOS o mesmo aplicativo Flutter usado no Android, sem fork de codigo.

## 1) Confirmar base unica Flutter

- O app deve manter apenas uma base em lib/.
- Evitar telas separadas para iOS e Android, exceto quando for obrigatorio por API nativa.
- Se houver condicoes por plataforma, elas devem apenas ajustar permissao/comportamento nativo, sem mudar regra de negocio.

## 2) Configuracao iOS

- Bundle ID do Runner: com.agmerchandising.app
- Bundle ID de testes: com.agmerchandising.app.RunnerTests
- iOS Deployment Target: 13.0

Arquivos relevantes:

- ios/Runner.xcodeproj/project.pbxproj
- ios/Runner/Info.plist
- ios/Podfile

## 3) Permissoes obrigatorias no Info.plist

- Camera
- Biblioteca de fotos (leitura)
- Biblioteca de fotos (gravacao)
- Localizacao em uso
- Face ID (biometria)

## 4) Build no Mac (obrigatorio)

1. flutter clean
2. flutter pub get
3. cd ios
4. pod install
5. abrir Runner.xcworkspace no Xcode
6. selecionar Team em Signing & Capabilities
7. Product > Archive
8. enviar para TestFlight pelo Organizer

## 5) Testes de paridade (Android x iOS)

- Login e logout
- Selecao de marca
- Coleta com camera
- Upload de fotos
- GPS/localizacao na coleta
- Geracao de PDF
- Notificacoes locais
- Fluxo de biometria

## 6) Critrio de aceite

- Mesmo backend e mesmos endpoints
- Mesma regra de negocio
- Sem campos faltando no iOS
- Sem fluxo bloqueado por permissao ausente
