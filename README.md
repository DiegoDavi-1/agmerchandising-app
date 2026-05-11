# agmerchandising-app

Promoter App  Promoter App is a mobile application designed to help managers and teams track, verify, and validate the work of promoters efficiently. It streamlines data collection, reporting, and performance analysis, ensuring high-quality operations across stores and campaigns.

## iOS

O projeto ja esta preparado para iOS com bundle id e permissoes nativas configuradas.

### Pre-requisitos

1. Mac com Xcode instalado (ultima versao estavel).
2. Conta Apple Developer com certificado e provisioning profile.
3. Flutter SDK instalado no Mac.

### Build local (dispositivo)

1. Executar `flutter pub get`.
2. Abrir `ios/Runner.xcworkspace` no Xcode.
3. Em Signing & Capabilities, selecionar seu Team.
4. Conectar iPhone e executar pelo esquema Runner.

### Build para TestFlight/App Store

1. Executar `flutter build ipa --release` no Mac.
2. Enviar pelo Xcode Organizer ou Transporter.
3. Publicar no App Store Connect.

### Observacao

Build de iOS nao pode ser gerado no Windows; o empacotamento final sempre precisa de macOS.
