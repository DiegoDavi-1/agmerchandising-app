# iOS Release Checklist (Mesma Base do Android)

Objetivo: publicar no iOS o mesmo aplicativo Flutter usado no Android, sem fork de codigo.

## 1) Confirmar base unica Flutter

- O app deve manter apenas uma base em lib/.
- Evitar telas separadas para iOS e Android, exceto quando for obrigatorio por API nativa.
- Se houver condicoes por plataforma, elas devem apenas ajustar permissao/comportamento nativo, sem mudar regra de negocio.

## 2) Configuracao iOS

- Bundle ID do Runner: com.merchhub.app
- Bundle ID de testes: com.merchhub.app.RunnerTests
- iOS Deployment Target: 15.0 (Runner, Flutter e dependencias CocoaPods)
- Ciclo de vida UIKit: `UIApplicationSceneManifest` com `FlutterSceneDelegate`;
  plugins registrados em `didInitializeImplicitFlutterEngine`.
- Keychain Sharing: entitlements configurados para Debug/Profile e Release,
  exigidos pelo `flutter_secure_storage`.

Arquivos relevantes:

- ios/Runner.xcodeproj/project.pbxproj
- ios/Runner/Info.plist
- ios/Runner/AppDelegate.swift
- ios/Podfile

## 3) Permissoes obrigatorias no Info.plist

- Camera
- Biblioteca de fotos (leitura)
- Biblioteca de fotos (gravacao)
- Localizacao em uso
- Face ID (biometria)

## 4) Build no Mac (obrigatorio)

Usar Flutter 3.38.5 e manter o pubspec.lock.

Para validar no simulador, sem conta paga ou assinatura:

1. flutter pub get
2. cd ios && pod install
3. compilar e instalar o Runner.app em um simulador iPhone pelo Xcode ou simctl

No Xcode 27.1, o build generico de simulador com Flutter 3.38.5 pode falhar
na verificacao de arquiteturas mesmo com arm64 e x86_64 presentes.
O build direcionado a um simulador Apple Silicon foi validado:

```sh
xcrun simctl list devices available
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'id=UUID_DO_SIMULADOR' ONLY_ACTIVE_ARCH=YES build
```

O caminho de Runner.app aparece na saida do build. Instalar e iniciar:

```sh
xcrun simctl boot UUID_DO_SIMULADOR
xcrun simctl bootstatus UUID_DO_SIMULADOR -b
xcrun simctl install UUID_DO_SIMULADOR /caminho/Runner.app
xcrun simctl launch UUID_DO_SIMULADOR com.merchhub.app
```

Para validar a adocao de `UIScene`, abrir o app em iOS 27 e confirmar que ele
permanece em primeiro plano sem encerramento pelo sistema.

Para distribuir:

1. confirmar a inscricao Apple Developer ativa e criar o registro do app no App Store Connect com o bundle ID `com.merchhub.app`
2. conectar o repositorio ao Codemagic e selecionar a configuracao `codemagic.yaml`
3. configurar no Codemagic a integracao App Store Connect chamada `Merch Hub App Store Connect`
4. em Code signing identities, obter/criar certificado Apple Distribution e perfil App Store para `com.merchhub.app`
5. iniciar o workflow `iOS TestFlight`; ele gera um IPA assinado e o envia ao App Store Connect
6. apos o processamento, configurar os grupos e disponibilizar o build no TestFlight

O workflow usa Flutter 3.38.5 e incrementa o build a partir de 27 usando o
numero sequencial do Codemagic. Se algum build acima de 27 ja tiver sido
enviado manualmente ao App Store Connect, ajuste o valor-base em `codemagic.yaml`
antes da primeira execucao.

Como alternativa, o archive Release para dispositivo foi validado sem
assinatura; esse archive nao pode ser enviado sem gerar a assinatura/perfil de
distribuicao no Xcode.

Nao copiar chaves Android, certificados ou senhas para o Mac junto ao codigo.
Notificacoes locais possuem suporte iOS; push remoto ainda esta limitado ao
Android em PushService. Antes de ativar no iOS, registrar o app no Firebase,
configurar APNs e validar registro de tokens e capacidades de assinatura.

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
